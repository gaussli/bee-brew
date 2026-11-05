import Foundation
import Combine

// MARK: - Homebrew 服务层（全面 JSON 化重构）
/// 封装全部 brew CLI 调用（`--json=v2` + Decodable DTO），并管理长操作进度日志。
@MainActor
final class BrewService: ObservableObject {

    private let commandExecutor = CommandExecutor.shared

    // MARK: - 发布的状态
    @Published private(set) var isHomebrewInstalled: Bool = false
    @Published private(set) var homebrewVersion: String = ""
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var lastError: BrewError?
    @Published private(set) var operationLog: [OperationLogEntry] = []
    @Published private(set) var runningOperations: Set<String> = []

    private let maxLogEntries = 2000

    init() {}

    // MARK: - 环境检测（FR-001）
    func detectEnvironment() async -> BrewEnvironment {
        var environment = BrewEnvironment()

        do {
            environment.version = try await commandExecutor.brewVersion()
        } catch {
            lastError = normalize(error)
        }

        do {
            environment.prefix = try await commandExecutor.brewPrefix()
        } catch {
            // prefix 失败不阻断主流程
        }

        // brew config 解析 repository/cellar/cpu/os
        do {
            let result = try await commandExecutor.runBrew(arguments: ["config"])
            if result.isSuccess {
                for line in result.stdout.split(separator: "\n") {
                    let parts = line.split(separator: ":", maxSplits: 1)
                        .map { $0.trimmingCharacters(in: .whitespaces) }
                    guard parts.count == 2 else { continue }
                    switch parts[0] {
                    case "HOMEBREW_REPOSITORY": environment.repository = parts[1]
                    case "HOMEBREW_CELLAR": environment.cellar = parts[1]
                    case "CPU": environment.cpu = parts[1]
                    case "OS": environment.os = parts[1]
                    default: break
                    }
                }
            }
        } catch {
            // 忽略 config 解析失败
        }

        isHomebrewInstalled = !environment.version.isEmpty
        homebrewVersion = environment.version
        return environment
    }

    // MARK: - 列表（FR-002/003/010）
    /// brew info --installed --json=v2（返回结构与 BrewFormulaListJSON 一致，兼容 Homebrew 4.x/7.x）
    func listInstalledFormulae() async throws -> [BrewPackage] {
        let json: BrewFormulaListJSON = try await commandExecutor.runBrewJSON(
            BrewFormulaListJSON.self,
            arguments: ["info", "--installed", "--json=v2"]
        )
        return json.formulae.map { $0.toBrewPackage() }
    }

    /// brew info --cask --installed --json=v2（返回结构与 BrewCaskListJSON 一致）
    func listInstalledCasks() async throws -> [BrewPackage] {
        let json: BrewCaskListJSON = try await commandExecutor.runBrewJSON(
            BrewCaskListJSON.self,
            arguments: ["info", "--cask", "--installed", "--json=v2"]
        )
        return json.casks.map { $0.toBrewPackage() }
    }

    /// 并发合并 formula + cask（NFR-001 <500ms）
    func listInstalled() async throws -> [BrewPackage] {
        async let formulae = listInstalledFormulae()
        async let casks = listInstalledCasks()
        let (formulaPackages, caskPackages) = try await (formulae, casks)
        return (formulaPackages + caskPackages).sortedByName()
    }

    /// brew outdated --json=v2
    func listOutdated() async throws -> [BrewPackage] {
        let json: BrewOutdatedJSON = try await commandExecutor.runBrewJSON(
            BrewOutdatedJSON.self,
            arguments: ["outdated", "--json=v2"]
        )
        let formulae = (json.formulae ?? []).map { $0.toBrewPackage() }
        let casks = (json.casks ?? []).map { $0.toBrewPackage() }
        return (formulae + casks).sortedByName()
    }

    // MARK: - 搜索（FR-005）
    /// 首选 `brew search --json=v2`；若 Homebrew 版本不支持 JSON（7.x），回退文本搜索。
    func search(query: String) async throws -> [BrewPackage] {
        let sanitized = InputValidator.sanitizeQuery(query)
        guard !sanitized.isEmpty else { return [] }

        do {
            let items: [BrewSearchItem] = try await commandExecutor.runBrewJSON(
                [BrewSearchItem].self,
                arguments: ["search", "--json=v2", sanitized]
            )
            return items.map { $0.toBrewPackage() }
        } catch {
            // 回退：分别搜索 formula 与 cask（DDD Q1 既定方案）
            return try await textSearch(query: sanitized)
        }
    }

    // MARK: - 详情（FR-013）
    func getFormulaInfo(_ name: String) async throws -> BrewPackage {
        try InputValidator.validatePackageName(name)
        let json: BrewFormulaListJSON = try await commandExecutor.runBrewJSON(
            BrewFormulaListJSON.self,
            arguments: ["info", "--json=v2", name]
        )
        guard let formula = json.formulae.first else { throw BrewError.notInstalled }
        return formula.toBrewPackage()
    }

    func getCaskInfo(_ token: String) async throws -> BrewPackage {
        try InputValidator.validatePackageName(token)
        let json: BrewCaskListJSON = try await commandExecutor.runBrewJSON(
            BrewCaskListJSON.self,
            arguments: ["info", "--cask", "--json=v2", token]
        )
        guard let cask = json.casks.first else { throw BrewError.notInstalled }
        return cask.toBrewPackage()
    }

    func getPackageInfo(_ package: BrewPackage) async throws -> BrewPackage {
        if package.isFormula {
            return try await getFormulaInfo(package.name)
        } else {
            return try await getCaskInfo(package.name)
        }
    }

    // MARK: - 包操作（FR-006/007/008/009/011，流式）
    func install(_ package: BrewPackage) async throws {
        try InputValidator.validatePackageName(package.name)
        var arguments = ["install"]
        if !package.isFormula { arguments.append("--cask") }
        arguments.append(package.name)
        try await runStreamingOperation(id: package.id, arguments: arguments)
    }

    func uninstall(_ package: BrewPackage) async throws {
        try InputValidator.validatePackageName(package.name)
        var arguments = ["uninstall"]
        if !package.isFormula { arguments.append("--cask") }
        arguments.append(package.name)
        try await runStreamingOperation(id: package.id, arguments: arguments)
    }

    func upgrade(_ package: BrewPackage) async throws {
        try InputValidator.validatePackageName(package.name)
        var arguments = ["upgrade"]
        if !package.isFormula { arguments.append("--cask") }
        arguments.append(package.name)
        try await runStreamingOperation(id: package.id, arguments: arguments)
    }

    func upgradeAll() async throws {
        try await runStreamingOperation(id: "system:upgrade-all", arguments: ["upgrade"])
    }

    // MARK: - 系统维护（FR-015/016）
    func updateHomebrew() async throws {
        try await runStreamingOperation(id: "system:update", arguments: ["update"])
    }

    /// brew cleanup --dry-run → 文本解析待删除项
    func cleanupDryRun() async throws -> [CleanupItem] {
        let result = try await commandExecutor.runBrew(arguments: ["cleanup", "--dry-run"])
        guard result.isSuccess else {
            throw BrewError.commandFailed(cmd: "brew", code: result.exitCode, stderr: String(result.stderr.suffix(500)))
        }
        return parseCleanupOutput(result.stdout + result.stderr, isDryRun: true)
    }

    func cleanup() async throws {
        try await runStreamingOperation(id: "system:cleanup", arguments: ["cleanup"])
    }

    // MARK: - 取消（NFR-011）
    func cancelAll() {
        commandExecutor.cancelAll()
    }

    // MARK: - 私有实现
    private func runStreamingOperation(id: String, arguments: [String]) async throws {
        guard !runningOperations.contains(id) else { return }
        runningOperations.insert(id)
        defer { runningOperations.remove(id) }

        let stream = commandExecutor.runBrewStreaming(arguments: arguments)
        var lastExitCode: Int32 = 0
        var stderrBuffer = ""

        do {
            for try await event in stream {
                switch event {
                case .stdout(let text):
                    appendLog(.stdout, text)
                case .stderr(let text):
                    appendLog(.stderr, text)
                    stderrBuffer += text
                case .exit(let code):
                    lastExitCode = code
                }
            }
        } catch {
            throw BrewError.commandFailed(cmd: "brew", code: lastExitCode, stderr: String(stderrBuffer.suffix(500)))
        }

        if lastExitCode != 0 {
            throw BrewError.commandFailed(cmd: "brew", code: lastExitCode, stderr: String(stderrBuffer.suffix(500)))
        }
    }

    private func appendLog(_ stream: LogStream, _ text: String) {
        let entry = OperationLogEntry(stream: stream, text: text, timestamp: Date())
        operationLog.append(entry)
        if operationLog.count > maxLogEntries {
            operationLog.removeFirst(operationLog.count - maxLogEntries)
        }
    }

    private func textSearch(query: String) async throws -> [BrewPackage] {
        async let formulaResult = commandExecutor.runBrew(arguments: ["search", "--formula", query])
        async let caskResult = commandExecutor.runBrew(arguments: ["search", "--cask", query])
        let (formula, cask) = try await (formulaResult, caskResult)

        var packages: [BrewPackage] = []
        if formula.isSuccess {
            packages += parseSearchLines(formula.stdout, type: .formula)
        }
        if cask.isSuccess {
            packages += parseSearchLines(cask.stdout, type: .cask)
        }
        if !formula.isSuccess && !cask.isSuccess {
            throw BrewError.commandFailed(
                cmd: "brew search",
                code: formula.exitCode,
                stderr: String((formula.stderr + cask.stderr).suffix(500))
            )
        }
        return packages.sortedByName()
    }

    private func parseSearchLines(_ output: String, type: BrewPackage.PackageType) -> [BrewPackage] {
        output.split(separator: "\n").compactMap { line in
            let name = line.trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty,
                  !name.hasPrefix("==>"),
                  InputValidator.isValidPackageName(name) else { return nil }
            return BrewPackage(name: name, type: type, installed: false)
        }
    }

    private func parseCleanupOutput(_ output: String, isDryRun: Bool) -> [CleanupItem] {
        let prefix = "Would remove: "
        return output.split(separator: "\n").compactMap { rawLine in
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard line.hasPrefix(prefix) else { return nil }
            var path = String(line.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
            // 去掉末尾的尺寸信息，如 "(12.2MB)" 或 "(1,707 files, 34.6MB)"
            if let range = path.range(of: " (", options: .backwards) {
                path = String(path[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
            }
            guard !path.isEmpty else { return nil }
            return CleanupItem(path: path, isDryRun: isDryRun)
        }
    }

    private func normalize(_ error: Error) -> BrewError {
        (error as? BrewError) ?? .commandFailed(cmd: "brew", code: 1, stderr: error.localizedDescription)
    }
}

// MARK: - DTO → 领域模型映射（NFR-013：字段逐一映射，不臆造）
extension BrewFormulaJSON {
    func toBrewPackage() -> BrewPackage {
        let installedVersions = installed?.compactMap { $0.version } ?? []
        let firstInstalled = installed?.first
        // BUG-3 修复：`installed_as_dependency` 在 Homebrew 7.x 已移除，改由 `installed_on_request` 推导；
        // 仅在缺失时回退到旧字段兜底。
        let installedOnRequest = firstInstalled?.installedOnRequest ?? false
        let installedAsDependency: Bool
        if let onRequest = firstInstalled?.installedOnRequest {
            installedAsDependency = !onRequest
        } else {
            installedAsDependency = firstInstalled?.installedAsDependency ?? false
        }
        return BrewPackage(
            name: name,
            type: .formula,
            fullName: fullName,
            desc: desc,
            homepage: homepage,
            license: license,
            version: versions?.stable,
            installedVersions: installedVersions,
            currentVersion: nil,
            installed: installed?.isEmpty == false,
            outdated: outdated ?? false,
            pinned: pinned ?? false,
            kegOnly: kegOnly ?? false,
            autoUpdates: false,
            caveats: caveats,
            installedTime: firstInstalled?.time.map { Date(timeIntervalSince1970: TimeInterval($0)) },
            installedAsDependency: installedAsDependency,
            installedOnRequest: installedOnRequest,
            dependencies: dependencies ?? [],
            buildDependencies: buildDependencies ?? []
        )
    }
}

extension BrewCaskJSON {
    func toBrewPackage() -> BrewPackage {
        return BrewPackage(
            name: token,
            type: .cask,
            fullName: fullToken,
            desc: desc,
            homepage: homepage,
            license: nil,
            version: version,
            installedVersions: installed.map { [$0] } ?? [],
            currentVersion: nil,
            installed: installed != nil,
            outdated: outdated ?? false,
            pinned: false,
            kegOnly: false,
            autoUpdates: autoUpdates ?? false,
            caveats: caveats,
            installedTime: installedTime.map { Date(timeIntervalSince1970: TimeInterval($0)) },
            installedAsDependency: false,
            installedOnRequest: false,
            dependencies: [],
            buildDependencies: []
        )
    }
}

extension BrewOutdatedFormula {
    func toBrewPackage() -> BrewPackage {
        return BrewPackage(
            name: name,
            type: .formula,
            installedVersions: installedVersions ?? [],
            currentVersion: currentVersion,
            installed: true,
            outdated: true,
            pinned: pinned ?? false
        )
    }
}

extension BrewOutdatedCask {
    func toBrewPackage() -> BrewPackage {
        return BrewPackage(
            name: name,
            type: .cask,
            installedVersions: installedVersions ?? [],
            currentVersion: currentVersion,
            installed: true,
            outdated: true
        )
    }
}

extension BrewSearchItem {
    func toBrewPackage() -> BrewPackage {
        let type: BrewPackage.PackageType = isCask ? .cask : .formula
        return BrewPackage(
            name: identifier,
            type: type,
            fullName: fullToken ?? fullName,
            desc: desc,
            homepage: homepage,
            license: nil,
            version: version,
            installedVersions: [],
            currentVersion: nil,
            installed: false,
            outdated: false,
            pinned: false,
            kegOnly: false,
            autoUpdates: false,
            caveats: nil,
            installedTime: nil,
            installedAsDependency: false,
            installedOnRequest: false,
            dependencies: [],
            buildDependencies: []
        )
    }
}

// MARK: - 列表排序辅助
extension Array where Element == BrewPackage {
    func sortedByName() -> [BrewPackage] {
        sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}

import Foundation

// MARK: - 命令执行结果
struct ExecutionResult {
    let stdout: String
    let stderr: String
    let exitCode: Int32
    var isSuccess: Bool { exitCode == 0 }
}

// MARK: - 流式事件（FR-014）
enum StreamEvent: Equatable {
    case stdout(String)   // brew 标准输出片段
    case stderr(String)   // brew 错误 / 进度输出片段
    case exit(Int32)      // 结束事件（退出码）
}

// MARK: - 命令行执行器（改造后）
/// 核心改造：移除 `/bin/bash -c` 字符串拼接，改用 `Process.executableURL + arguments` 数组直接执行（NFR-008）。
/// brew 路径可配置（FR-017），由 SettingsViewModel 注入 `brewPath`。
final class CommandExecutor {

    static let shared = CommandExecutor()

    /// 当前 brew 可执行文件路径，默认自动检测，可被设置覆盖
    var brewPath: String

    private let processLock = NSLock()
    private var activeProcesses: [Process] = []

    init() {
        brewPath = CommandExecutor.detectBrewPath() ?? "/opt/homebrew/bin/brew"
    }

    // MARK: - 核心执行（无 shell）
    /// 以 executableURL + arguments 数组直接执行进程，绝不经过 shell（NFR-008）。
    func run(executableURL: URL, arguments: [String]) async throws -> ExecutionResult {
        guard FileManager.default.isExecutableFile(atPath: executableURL.path) else {
            throw BrewError.brewNotFound
        }
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                let outPipe = Pipe()
                let errPipe = Pipe()
                process.executableURL = executableURL
                process.arguments = arguments
                process.standardOutput = outPipe
                process.standardError = errPipe

                do {
                    try process.run()

                    // 并发读取 stdout/stderr，避免大输出写满管道缓冲区导致进程阻塞（死锁修复）
                    // 用锁保护跨线程写入，避免数据竞争（QA 建议）
                    var stdoutData = Data()
                    var stderrData = Data()
                    let group = DispatchGroup()
                    let dataLock = NSLock()

                    group.enter()
                    DispatchQueue.global(qos: .utility).async {
                        let data = outPipe.fileHandleForReading.readDataToEndOfFile()
                        dataLock.lock()
                        stdoutData = data
                        dataLock.unlock()
                        group.leave()
                    }
                    group.enter()
                    DispatchQueue.global(qos: .utility).async {
                        let data = errPipe.fileHandleForReading.readDataToEndOfFile()
                        dataLock.lock()
                        stderrData = data
                        dataLock.unlock()
                        group.leave()
                    }

                    process.waitUntilExit()
                    group.wait()

                    let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
                    let stderr = String(data: stderrData, encoding: .utf8) ?? ""
                    continuation.resume(returning: ExecutionResult(stdout: stdout, stderr: stderr, exitCode: process.terminationStatus))
                } catch {
                    continuation.resume(throwing: BrewError.commandFailed(cmd: executableURL.lastPathComponent, code: 1, stderr: error.localizedDescription))
                }
            }
        }
    }

    /// brew 专用执行：自动使用配置的 brewPath
    func runBrew(arguments: [String]) async throws -> ExecutionResult {
        try await run(executableURL: URL(fileURLWithPath: brewPath), arguments: arguments)
    }

    // MARK: - JSON 解码执行
    /// 执行 brew 子命令并解码 `--json=v2` 输出为 DTO。
    func runBrewJSON<T: Decodable>(_ type: T.Type, arguments: [String]) async throws -> T {
        let result = try await runBrew(arguments: arguments)
        guard result.isSuccess else {
            throw BrewError.commandFailed(cmd: "brew", code: result.exitCode, stderr: String(result.stderr.suffix(500)))
        }
        let decoder = JSONDecoder()
        // 统一约定：snake_case JSON → camelCase Swift（DDD §10）
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        do {
            return try decoder.decode(T.self, from: Data(result.stdout.utf8))
        } catch {
            throw BrewError.jsonDecode(error.localizedDescription)
        }
    }

    // MARK: - 流式执行（FR-014）
    /// 长耗时操作的流式输出，用于进度面板。`.stderr` 同样承载进度（brew 大量进度走 stderr）。
    func runBrewStreaming(arguments: [String]) -> AsyncThrowingStream<StreamEvent, Error> {
        AsyncThrowingStream { continuation in
            let process = Process()
            let outPipe = Pipe()
            let errPipe = Pipe()
            process.executableURL = URL(fileURLWithPath: self.brewPath)
            process.arguments = arguments
            process.standardOutput = outPipe
            process.standardError = errPipe

            self.register(process)

            outPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if !data.isEmpty, let text = String(data: data, encoding: .utf8) {
                    continuation.yield(.stdout(text))
                }
            }
            errPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if !data.isEmpty, let text = String(data: data, encoding: .utf8) {
                    continuation.yield(.stderr(text))
                }
            }
            process.terminationHandler = { [weak self] proc in
                outPipe.fileHandleForReading.readabilityHandler = nil
                errPipe.fileHandleForReading.readabilityHandler = nil
                self?.unregister(proc)
                continuation.yield(.exit(proc.terminationStatus))
                continuation.finish()
            }

            do {
                try process.run()
            } catch {
                self.unregister(process)
                continuation.finish(throwing: BrewError.commandFailed(cmd: "brew", code: 1, stderr: error.localizedDescription))
            }
        }
    }

    /// 取消所有进行中的流式操作（NFR-011 可取消）
    func cancelAll() {
        processLock.lock()
        let processes = activeProcesses
        processLock.unlock()
        for process in processes where process.isRunning {
            process.terminate()
        }
    }

    // MARK: - 环境检测（FR-001）
    /// 依次：`which brew`（无 shell）→ /opt/homebrew → /usr/local → linuxbrew
    static func detectBrewPath() -> String? {
        if let result = runSync(executableURL: URL(fileURLWithPath: "/usr/bin/which"), arguments: ["brew"]),
           result.exitCode == 0 {
            let path = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }

        let candidates = [
            "/opt/homebrew/bin/brew",
            "/usr/local/bin/brew",
            "/home/linuxbrew/.linuxbrew/bin/brew"
        ]
        for path in candidates where FileManager.default.isExecutableFile(atPath: path) {
            return path
        }
        return nil
    }

    /// brew --version
    func brewVersion() async throws -> String {
        let result = try await runBrew(arguments: ["--version"])
        guard result.isSuccess else {
            throw BrewError.commandFailed(cmd: "brew", code: result.exitCode, stderr: String(result.stderr.suffix(500)))
        }
        return result.stdout
            .split(separator: "\n")
            .first
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) } ?? ""
    }

    /// brew --prefix
    func brewPrefix() async throws -> String {
        let result = try await runBrew(arguments: ["--prefix"])
        guard result.isSuccess else {
            throw BrewError.commandFailed(cmd: "brew", code: result.exitCode, stderr: String(result.stderr.suffix(500)))
        }
        return result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - 私有工具
    private func register(_ process: Process) {
        processLock.lock()
        activeProcesses.append(process)
        processLock.unlock()
    }

    private func unregister(_ process: Process) {
        processLock.lock()
        activeProcesses.removeAll { $0 === process }
        processLock.unlock()
    }

    private static func runSync(executableURL: URL, arguments: [String]) -> (stdout: String, exitCode: Int32)? {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = executableURL
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return (String(data: data, encoding: .utf8) ?? "", process.terminationStatus)
        } catch {
            return nil
        }
    }
}

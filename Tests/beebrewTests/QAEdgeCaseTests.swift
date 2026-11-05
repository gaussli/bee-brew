import XCTest
import Foundation
@testable import beebrew

// MARK: - QA 独立边界 / 错误路径测试（严过关 / software-qa-engineer）
// 目的：不重复工程师已覆盖的 happy path，专门补边界、错误路径与 NFR-013 数据一致性兜底。
// 标注 [BUG-xxx] 的用例对应已发现并被验证的源码缺陷，待 Engineer 修复后应转为通过。

final class QAInputValidatorEdgeCaseTests: XCTestCase {

    // MARK: 合法名边界
    func testValidNamesBoundary() {
        XCTAssertTrue(InputValidator.isValidPackageName("a"))                       // 最短 1 字符
        XCTAssertTrue(InputValidator.isValidPackageName("node"))
        XCTAssertTrue(InputValidator.isValidPackageName("node@22"))
        XCTAssertTrue(InputValidator.isValidPackageName("openssl@3"))
        XCTAssertTrue(InputValidator.isValidPackageName("visual-studio-code"))
        XCTAssertTrue(InputValidator.isValidPackageName("python@3.12"))
        XCTAssertTrue(InputValidator.isValidPackageName("gcc+11"))
        XCTAssertTrue(InputValidator.isValidPackageName("a/b"))                     // 白名单允许 /（tap 限定名）
    }

    func testValidNameMaxLength() {
        // 首字符 + 255 个后续字符 = 256 字符，恰好合法
        let name = "a" + String(repeating: "b", count: 255)
        XCTAssertEqual(name.count, 256)
        XCTAssertTrue(InputValidator.isValidPackageName(name))
    }

    // MARK: 非法名边界
    func testRejectsEmptyAndOverlong() {
        XCTAssertFalse(InputValidator.isValidPackageName(""))
        let over = "a" + String(repeating: "b", count: 256)   // 257 字符
        XCTAssertFalse(InputValidator.isValidPackageName(over))
    }

    func testRejectsLeadingNonAlphanumeric() {
        XCTAssertFalse(InputValidator.isValidPackageName(".hidden"))
        XCTAssertFalse(InputValidator.isValidPackageName("-leading"))
        XCTAssertFalse(InputValidator.isValidPackageName("@foo"))
        XCTAssertFalse(InputValidator.isValidPackageName("/absolute"))
    }

    func testRejectsInjectionCharacters() {
        let payloads = [
            "node; rm -rf /",          // 分号
            "node|cat",                // 管道
            "node&&echo",              // 与
            "node$(whoami)",           // 命令替换
            "node`id`",                // 反引号
            "node>file",               // 重定向
            "node<file",
            "node(1)",                 // 括号
            "a b",                     // 空格
            "a\tb",                    // 制表符
            "node\\",                  // 反斜杠
            "node\"",                  // 双引号
            "node'",                   // 单引号
            "node$IFS",                // 环境变量
        ]
        for p in payloads {
            XCTAssertFalse(InputValidator.isValidPackageName(p), "应拒绝注入负载：\(p)")
        }
    }

    // MARK: [BUG-2] 末尾控制字符被 `$` 锚点绕过（NFR-008）
    // NSRegularExpression 的 `$` 会匹配到「末尾换行符之前」，导致末尾带换行/回车/行分隔符的
    // 包名被误判为合法。当前实现返回 true（错误），修复后应返回 false。
    func testRejectsTrailingLineTerminator_BUG() {
        XCTAssertFalse(InputValidator.isValidPackageName("node\n"), "[BUG-2] 末尾换行符应被拒绝")
        XCTAssertFalse(InputValidator.isValidPackageName("node\r"), "[BUG-2] 末尾回车符应被拒绝")
        XCTAssertFalse(InputValidator.isValidPackageName("node\u{2028}"), "[BUG-2] 末尾行分隔符应被拒绝")
        XCTAssertFalse(InputValidator.isValidPackageName("node\u{2029}"), "[BUG-2] 末尾段分隔符应被拒绝")
    }

    // MARK: 抛错版本
    func testValidatePackageNameThrows() {
        XCTAssertThrowsError(try InputValidator.validatePackageName("node; rm")) { error in
            guard case BrewError.invalidPackageName(let name) = error else {
                return XCTFail("应为 invalidPackageName，实际 \(error)")
            }
            XCTAssertEqual(name, "node; rm")
        }
        XCTAssertNoThrow(try InputValidator.validatePackageName("node@22"))
    }

    // MARK: sanitizeQuery
    func testSanitizeQueryRemovesControlAndTruncates() {
        XCTAssertEqual(InputValidator.sanitizeQuery("  node  "), "node")
        XCTAssertEqual(InputValidator.sanitizeQuery("node\nrm"), "noderm")   // 控制字符被移除（非末尾也移除）
        XCTAssertEqual(InputValidator.sanitizeQuery(""), "")
        let long = String(repeating: "x", count: 500)
        XCTAssertEqual(InputValidator.sanitizeQuery(long).count, 100)
    }
}

// MARK: - 包名正则的换行绕过：验证正则本身行为（BUG-2 已修复后应拒绝匹配）
final class QARegularExpressionBehaviourTests: XCTestCase {
    func testTrailingNewlineIsNotMatchedAfterFix() {
        let regex = try! NSRegularExpression(pattern: InputValidator.packageNamePattern)
        let name = "node\n"
        let range = NSRange(name.startIndex..<name.endIndex, in: name)
        // BUG-2 修复：`$` 改为 `\z` 后，末尾换行符不再被匹配，firstMatch 应返回 nil
        XCTAssertNil(regex.firstMatch(in: name, options: [], range: range))
    }
}

// MARK: - BrewPackage 稳定 id 与相等性
final class QABrewPackageStabilityTests: XCTestCase {

    func testIDStableAcrossVersions() {
        let v1 = BrewPackage(name: "node", type: .formula, version: "22.0.0")
        let v2 = BrewPackage(name: "node", type: .formula, version: "26.13.0")
        XCTAssertEqual(v1.id, "formula:node")
        XCTAssertEqual(v2.id, "formula:node")
        XCTAssertEqual(v1, v2)
        XCTAssertEqual(Set([v1, v2]).count, 1)
    }

    func testIDDistinguishesType() {
        let f = BrewPackage(name: "node", type: .formula)
        let c = BrewPackage(name: "node", type: .cask)
        XCTAssertNotEqual(f.id, c.id)
        XCTAssertNotEqual(f, c)
        XCTAssertEqual(Set([f, c]).count, 2)
    }

    func testCaskIDUsesToken() {
        let cask = BrewPackage(name: "google-chrome", type: .cask)
        XCTAssertEqual(cask.id, "cask:google-chrome")
    }
}

// MARK: - DTO 字段缺失 / null 兜底（NFR-013）
final class QADTOFallbackTests: XCTestCase {

    private func decodeFormula(_ jsonString: String) throws -> BrewFormulaListJSON {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(BrewFormulaListJSON.self, from: Data(jsonString.utf8))
    }

    func testFormulaMissingOptionalFieldsFallback() throws {
        // 仅含 name，其余字段全部缺失 → 不应解码崩溃，缺失字段为 nil / 默认值
        let json = #"{"formulae":[{"name":"minimal"}]}"#
        let formula = try decodeFormula(json).formulae[0]
        XCTAssertEqual(formula.name, "minimal")
        XCTAssertNil(formula.fullName)
        XCTAssertNil(formula.desc)
        XCTAssertNil(formula.homepage)
        XCTAssertNil(formula.license)
        XCTAssertNil(formula.versions)
        XCTAssertNil(formula.dependencies)
        XCTAssertNil(formula.installed)

        let pkg = formula.toBrewPackage()
        XCTAssertEqual(pkg.id, "formula:minimal")
        XCTAssertFalse(pkg.installed)
        XCTAssertFalse(pkg.outdated)
        XCTAssertFalse(pkg.pinned)
        XCTAssertEqual(pkg.dependencies, [])
        XCTAssertEqual(pkg.displayVersion, "未知版本")
    }

    func testFormulaNullFieldsDecodeAsNil() throws {
        // 显式 null 字段
        let json = #"{"formulae":[{"name":"x","desc":null,"homepage":null,"license":null,"versions":null,"installed":null,"dependencies":null,"outdated":null,"pinned":null,"keg_only":null}]}"#
        let formula = try decodeFormula(json).formulae[0]
        XCTAssertNil(formula.desc)
        XCTAssertNil(formula.installed)
        let pkg = formula.toBrewPackage()
        XCTAssertFalse(pkg.installed)
        XCTAssertFalse(pkg.outdated)
    }

    func testCaskNullInstalledFallback() throws {
        let json = #"{"casks":[{"token":"chrome","installed":null,"installed_time":null,"outdated":false,"auto_updates":true}]}"#
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let list = try decoder.decode(BrewCaskListJSON.self, from: Data(json.utf8))
        let pkg = list.casks[0].toBrewPackage()
        XCTAssertFalse(pkg.installed)
        XCTAssertNil(pkg.installedTime)
        XCTAssertTrue(pkg.autoUpdates)
        XCTAssertEqual(pkg.installedVersions, [])
    }

    func testInstalledTimeMapsEpochSeconds() throws {
        let json = #"{"formulae":[{"name":"wget","installed":[{"version":"1.25.0","time":1738751818}]}]}"#
        let formula = try decodeFormula(json).formulae[0]
        let pkg = formula.toBrewPackage()
        XCTAssertEqual(pkg.installedTime?.timeIntervalSince1970, 1738751818)
    }

    // MARK: [BUG-3] Homebrew 7.x 无 installed_as_dependency 字段，
    // 安装方式应根据 installed_on_request == false 推导，当前映射恒为 false。
    func testInstalledAsDependencyDerivedFromOnRequest_BUG() throws {
        let json = #"{"formulae":[{"name":"ca-certificates","installed":[{"version":"2026-03-19","time":1738751818,"installed_on_request":false}],"outdated":false}]}"#
        let formula = try decodeFormula(json).formulae[0]
        let pkg = formula.toBrewPackage()
        XCTAssertTrue(pkg.installed)
        XCTAssertFalse(pkg.installedOnRequest)
        // 作为依赖安装的包，installedAsDependency 应为 true（当前实现返回 false）
        XCTAssertTrue(pkg.installedAsDependency, "[BUG-3] installed_on_request=false 应推导 installedAsDependency=true")
    }
}

// MARK: - PackageFilter / 状态 / 错误 补充
final class QAMiscLogicTests: XCTestCase {

    func testFilterSortByVersion() {
        let packages = [
            BrewPackage(name: "a", type: .formula, version: "10.0.0", installedVersions: ["10.0.0"]),
            BrewPackage(name: "b", type: .formula, version: "2.0.0", installedVersions: ["2.0.0"]),
            BrewPackage(name: "c", type: .formula, version: "2.0.0", installedVersions: ["2.0.0"])
        ]
        var filter = PackageFilter()
        filter.sortBy = .version
        let sorted = filter.apply(to: packages).map { $0.displayVersion }
        // localizedStandardCompare 数值排序：2.0.0 < 10.0.0
        XCTAssertEqual(sorted, ["2.0.0", "2.0.0", "10.0.0"])
    }

    func testFilterEmptySearchReturnsAll() {
        let packages = [
            BrewPackage(name: "node", type: .formula),
            BrewPackage(name: "python", type: .formula)
        ]
        var filter = PackageFilter()
        filter.searchText = ""
        XCTAssertEqual(filter.apply(to: packages).count, 2)
    }

    func testFilterSearchIsCaseInsensitive() {
        let packages = [BrewPackage(name: "Python", type: .formula)]
        var filter = PackageFilter()
        filter.searchText = "pyt"
        XCTAssertEqual(filter.apply(to: packages).count, 1)
    }

    func testCleanupItemIDEqualsPath() {
        let item = CleanupItem(path: "/usr/local/Cellar/node/21", isDryRun: true)
        XCTAssertEqual(item.id, item.path)
    }

    func testBrewErrorAllDescriptionsNonEmpty() {
        let errors: [BrewError] = [
            .brewNotFound,
            .invalidPackageName("x;y"),
            .invalidPath("/bad"),
            .commandFailed(cmd: "brew", code: 1, stderr: "boom"),
            .commandFailed(cmd: "brew", code: 2, stderr: ""),
            .jsonDecode("bad json"),
            .notInstalled
        ]
        for e in errors {
            XCTAssertNotNil(e.errorDescription)
            XCTAssertFalse(e.errorDescription!.isEmpty)
        }
    }

    func testOperationStateEquatableAndProcessing() {
        XCTAssertEqual(PackageOperationState.failed("a"), PackageOperationState.failed("a"))
        XCTAssertNotEqual(PackageOperationState.failed("a"), PackageOperationState.failed("b"))
        XCTAssertFalse(PackageOperationState.failed("a").isProcessing)
        XCTAssertFalse(PackageOperationState.success.isProcessing)
    }
}

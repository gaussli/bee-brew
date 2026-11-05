import XCTest
import Foundation
@testable import beebrew

// MARK: - ViewModel / 领域模型状态机测试（纯逻辑，不依赖真实 brew）
final class PackageViewModelTests: XCTestCase {

    private func makePackage(name: String, type: BrewPackage.PackageType, installed: Bool = true, outdated: Bool = false, pinned: Bool = false, version: String? = nil) -> BrewPackage {
        BrewPackage(name: name, type: type, version: version, installedVersions: version.map { [$0] } ?? [], installed: installed, outdated: outdated, pinned: pinned)
    }

    // MARK: - 包过滤器（FR-019/020）
    func testFilterSortByName() {
        let packages = [
            makePackage(name: "zlib", type: .formula),
            makePackage(name: "apple", type: .formula),
            makePackage(name: "curl", type: .formula)
        ]
        var filter = PackageFilter()
        filter.sortBy = .name
        let sorted = filter.apply(to: packages).map { $0.name }
        XCTAssertEqual(sorted, ["apple", "curl", "zlib"])
    }

    func testFilterStatusOutdated() {
        let packages = [
            makePackage(name: "a", type: .formula, outdated: true),
            makePackage(name: "b", type: .formula, outdated: false),
            makePackage(name: "c", type: .cask, outdated: true)
        ]
        var filter = PackageFilter()
        filter.status = .outdated
        let result = filter.apply(to: packages)
        XCTAssertEqual(result.count, 2)
        XCTAssertTrue(result.allSatisfy { $0.outdated })
    }

    func testFilterSearchText() {
        let packages = [
            makePackage(name: "python", type: .formula),
            makePackage(name: "node", type: .formula)
        ]
        var filter = PackageFilter()
        filter.searchText = "pyt"
        let result = filter.apply(to: packages)
        XCTAssertEqual(result.map { $0.name }, ["python"])
    }

    // MARK: - 操作状态机（FR-014）
    func testPackageOperationStateIsProcessing() {
        XCTAssertTrue(PackageOperationState.installing.isProcessing)
        XCTAssertTrue(PackageOperationState.uninstalling.isProcessing)
        XCTAssertTrue(PackageOperationState.updating.isProcessing)
        XCTAssertFalse(PackageOperationState.idle.isProcessing)
        XCTAssertFalse(PackageOperationState.success.isProcessing)
        XCTAssertFalse(PackageOperationState.failed("x").isProcessing)
    }

    // MARK: - 输入校验（NFR-008）
    func testInputValidatorRejectsInjection() {
        XCTAssertFalse(InputValidator.isValidPackageName("node; rm -rf /"))
        XCTAssertFalse(InputValidator.isValidPackageName("a b"))
        XCTAssertFalse(InputValidator.isValidPackageName("$(whoami)"))
        XCTAssertFalse(InputValidator.isValidPackageName("node|cat"))
        XCTAssertFalse(InputValidator.isValidPackageName("node&&echo"))
    }

    func testInputValidatorAcceptsValidNames() {
        XCTAssertTrue(InputValidator.isValidPackageName("node"))
        XCTAssertTrue(InputValidator.isValidPackageName("node@22"))
        XCTAssertTrue(InputValidator.isValidPackageName("visual-studio-code"))
        XCTAssertTrue(InputValidator.isValidPackageName("openssl@3"))
    }

    // BUG-2 回归：末尾控制字符 / 换行不得被误判为合法
    func testInputValidatorRejectsTrailingControlCharacters() {
        XCTAssertFalse(InputValidator.isValidPackageName("node\n"))
        XCTAssertFalse(InputValidator.isValidPackageName("node\r\n"))
        XCTAssertFalse(InputValidator.isValidPackageName("node\t"))
        XCTAssertFalse(InputValidator.isValidPackageName("node\u{0}"))
        XCTAssertFalse(InputValidator.isValidPackageName("\nnode"))
    }

    func testSanitizeQuery() {
        XCTAssertEqual(InputValidator.sanitizeQuery("  node  "), "node")
        XCTAssertEqual(InputValidator.sanitizeQuery("node\n\r"), "node")
        let long = String(repeating: "a", count: 200)
        XCTAssertEqual(InputValidator.sanitizeQuery(long).count, 100)
    }

    // MARK: - BrewError 可读描述（NFR-012）
    func testBrewErrorLocalizedDescription() {
        let error = BrewError.commandFailed(cmd: "brew", code: 1, stderr: "boom")
        XCTAssertTrue(error.errorDescription?.contains("brew") == true)
        XCTAssertTrue(error.errorDescription?.contains("boom") == true)
    }
}

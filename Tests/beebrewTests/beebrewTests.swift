import XCTest
@testable import beebrew

// MARK: - 基础冒烟测试（保留，删除对旧 API 的依赖）
final class beebrewTests: XCTestCase {

    func testExample() {
        XCTAssertTrue(true)
    }

    func testPackageTypeCases() {
        XCTAssertEqual(BrewPackage.PackageType.allCases.count, 2)
        XCTAssertEqual(BrewPackage.PackageType.formula.rawValue, "formula")
        XCTAssertEqual(BrewPackage.PackageType.cask.rawValue, "cask")
    }

    func testPackageStatusComputation() {
        let outdated = BrewPackage(name: "a", type: .formula, installed: true, outdated: true)
        XCTAssertEqual(outdated.status, .outdated)

        let installed = BrewPackage(name: "b", type: .formula, installed: true)
        XCTAssertEqual(installed.status, .installed)

        let notInstalled = BrewPackage(name: "c", type: .cask)
        XCTAssertEqual(notInstalled.status, .notInstalled)
    }
}

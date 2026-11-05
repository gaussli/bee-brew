import XCTest
import Foundation
@testable import beebrew

// MARK: - JSON fixture 加载辅助
enum TestFixtures {
    static func load(_ name: String) -> Data {
        // 1) 优先从测试资源 Bundle 加载（.process 会将目录内容平铺到 Bundle 根）
        if let url = Bundle.module.url(forResource: name, withExtension: "json"),
           let data = try? Data(contentsOf: url) {
            return data
        }
        // 2) 兜底：从源码树加载（本地开发 / 部分 SPM 环境）
        let testDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let url = testDir.appendingPathComponent("TestFixtures/\(name).json")
        return try! Data(contentsOf: url)
    }

    static func decode<T: Decodable>(_ type: T.Type, _ name: String) throws -> T {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(T.self, from: load(name))
    }
}

// MARK: - 服务层 JSON 解析测试（NFR-013：DTO 与 brew --json=v2 一致）
final class BrewServiceJSONTests: XCTestCase {

    func testListFormulaeDecoding() throws {
        let json = try TestFixtures.decode(BrewFormulaListJSON.self, "list_formulae")
        XCTAssertEqual(json.formulae.count, 2)

        let node = json.formulae[0]
        XCTAssertEqual(node.name, "node")
        XCTAssertEqual(node.versions?.stable, "26.13.0")
        XCTAssertEqual(node.dependencies, ["openssl@3", "icu4c"])
        XCTAssertEqual(node.installed?.first?.version, "26.5.0")
        XCTAssertEqual(node.outdated, true)

        let git = json.formulae[1]
        XCTAssertEqual(git.name, "git")
        XCTAssertEqual(git.outdated, false)
        XCTAssertEqual(git.installed?.first?.installedAsDependency, false)
    }

    func testListCasksDecoding() throws {
        let json = try TestFixtures.decode(BrewCaskListJSON.self, "list_casks")
        XCTAssertEqual(json.casks.count, 2)

        let vscode = json.casks[0]
        XCTAssertEqual(vscode.token, "visual-studio-code")
        XCTAssertEqual(vscode.installed, "1.96.2")

        let chrome = json.casks[1]
        XCTAssertNil(chrome.installed)
    }

    func testOutdatedDecoding() throws {
        let json = try TestFixtures.decode(BrewOutdatedJSON.self, "outdated")
        XCTAssertEqual(json.formulae?.count, 2)
        XCTAssertEqual(json.casks?.count, 1)

        let node = json.formulae![0]
        XCTAssertEqual(node.name, "node")
        XCTAssertEqual(node.installedVersions, ["26.5.0"])
        XCTAssertEqual(node.currentVersion, "26.13.0")

        let python = json.formulae![1]
        XCTAssertEqual(python.pinned, true)

        let firefox = json.casks![0]
        XCTAssertEqual(firefox.name, "firefox")
        XCTAssertEqual(firefox.currentVersion, "129.0")
    }

    func testSearchDecoding() throws {
        let items = try TestFixtures.decode([BrewSearchItem].self, "search")
        XCTAssertEqual(items.count, 2)

        XCTAssertEqual(items[0].identifier, "node")
        XCTAssertFalse(items[0].isCask)

        XCTAssertEqual(items[1].identifier, "nodejs")
        XCTAssertTrue(items[1].isCask)
    }

    // MARK: - DTO → 领域模型映射
    func testFormulaMapping() throws {
        let json = try TestFixtures.decode(BrewFormulaListJSON.self, "list_formulae")
        let package = json.formulae[0].toBrewPackage()

        XCTAssertEqual(package.id, "formula:node")
        XCTAssertEqual(package.name, "node")
        XCTAssertEqual(package.type, .formula)
        XCTAssertEqual(package.version, "26.13.0")
        XCTAssertEqual(package.installedVersions, ["26.5.0"])
        XCTAssertEqual(package.installedVersion, "26.5.0")
        XCTAssertTrue(package.installed)
        XCTAssertTrue(package.outdated)
        XCTAssertEqual(package.dependencies, ["openssl@3", "icu4c"])
        XCTAssertEqual(package.homepage, "https://nodejs.org/")
    }

    func testCaskMapping() throws {
        let json = try TestFixtures.decode(BrewCaskListJSON.self, "list_casks")
        let vscode = json.casks[0].toBrewPackage()
        let chrome = json.casks[1].toBrewPackage()

        XCTAssertEqual(vscode.id, "cask:visual-studio-code")
        XCTAssertTrue(vscode.installed)
        XCTAssertEqual(vscode.installedVersion, "1.96.2")

        XCTAssertFalse(chrome.installed)
        XCTAssertEqual(chrome.type, .cask)
    }

    func testOutdatedMapping() throws {
        let json = try TestFixtures.decode(BrewOutdatedJSON.self, "outdated")
        let node = json.formulae![0].toBrewPackage()

        XCTAssertEqual(node.id, "formula:node")
        XCTAssertTrue(node.outdated)
        XCTAssertEqual(node.currentVersion, "26.13.0")
        XCTAssertEqual(node.installedVersion, "26.5.0")
    }

    func testBrewPackageStableIDAndEquality() {
        let a = BrewPackage(name: "node", type: .formula, version: "22.0.0")
        let b = BrewPackage(name: "node", type: .formula, version: "26.0.0")
        XCTAssertEqual(a.id, "formula:node")
        XCTAssertEqual(a, b, "相等性由 (name, type) 稳定 id 决定，与版本无关")
        XCTAssertEqual(Set([a, b]).count, 1)
    }

    // BUG-3 回归：installed_as_dependency 在 7.x 移除，应由 installed_on_request 推导
    func testInstalledAsDependencyDerivedFromInstalledOnRequest() throws {
        let dependencyJSON = """
        {"formulae":[{"name":"foo","installed":[{"version":"1.0","installed_on_request":false}]}]}
        """
        let requestedJSON = """
        {"formulae":[{"name":"bar","installed":[{"version":"1.0","installed_on_request":true}]}]}
        """
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let dependency = try decoder.decode(BrewFormulaListJSON.self, from: Data(dependencyJSON.utf8)).formulae[0].toBrewPackage()
        let requested = try decoder.decode(BrewFormulaListJSON.self, from: Data(requestedJSON.utf8)).formulae[0].toBrewPackage()

        XCTAssertTrue(dependency.installedAsDependency)
        XCTAssertFalse(dependency.installedOnRequest)
        XCTAssertFalse(requested.installedAsDependency)
        XCTAssertTrue(requested.installedOnRequest)
    }
}

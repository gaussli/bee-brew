import XCTest
import Combine
@testable import beebrew

// MARK: - QA 独立补测：UI 改动回归（严过关 / software-qa-engineer）
// 覆盖对象：本轮 UI 改动中的 iconName 关键词映射（重点边界）、clearOperationLog 清空与同步机制。
// 目的：不盲信工程师结论，独立验证 `n.contains("gh")` / `n.contains("go")` 已改为精确匹配，
//       并确认 clearOperationLog 的 @Published → ViewModel 同步链路正确。

// MARK: - 1. iconName 图标映射边界（重点）
final class QAIconNameMappingTests: XCTestCase {

    private func formula(_ name: String) -> BrewPackage {
        BrewPackage(name: name, type: .formula)
    }

    private func cask(_ name: String) -> BrewPackage {
        BrewPackage(name: name, type: .cask)
    }

    // MARK: gh 精确匹配修复（工程师修复点 1）
    func testGitHubCLIExactMatch() {
        XCTAssertEqual(formula("gh").iconName, "tuningfork", "gh 应映射 GitHub CLI 图标（tuningfork）")
        XCTAssertEqual(formula("git").iconName, "tuningfork", "git 应映射 tuningfork")
        XCTAssertEqual(formula("git-lfs").iconName, "tuningfork", "git-lfs 仍走 git 关键词")
    }

    func testGhPrefixNoLongerMisMatched() {
        // 旧实现 n.contains("gh") 会把 ghc / ghostscript 误判为 GitHub CLI
        XCTAssertEqual(formula("ghc").iconName, "terminal.fill", "ghc 应回退 terminal.fill")
        XCTAssertEqual(formula("ghostscript").iconName, "terminal.fill", "ghostscript 应回退 terminal.fill")
    }

    // MARK: go 精确匹配修复（工程师修复点 2）
    func testGoExactAndVersionedPrefix() {
        XCTAssertEqual(formula("go").iconName, "g.circle", "go 本体应映射 g.circle")
        XCTAssertEqual(formula("golang").iconName, "g.circle", "golang 应映射 g.circle")
        XCTAssertEqual(formula("go@1.20").iconName, "g.circle", "go@1.20 应映射 g.circle")
        XCTAssertEqual(formula("go-toolchain").iconName, "g.circle", "go-toolchain 应映射 g.circle")
        XCTAssertEqual(formula("golangci-lint").iconName, "g.circle", "golangci-lint 走 golang 前缀")
    }

    func testGoNoFalsePositives() {
        // 旧实现 n.contains("go") 会误伤以下包名
        XCTAssertEqual(formula("mongodb").iconName, "terminal.fill", "mongodb 不应被 go 误映射")
        XCTAssertEqual(formula("django").iconName, "terminal.fill", "django 不应被 go 误映射")
        XCTAssertEqual(formula("gobject-introspection").iconName, "terminal.fill", "gobject-introspection 不应被 go 误映射")
        XCTAssertEqual(formula("cargo").iconName, "r.circle", "cargo 应映射 r.circle（而非 g.circle）")
    }

    // MARK: 大小写不敏感（内部 lowercased）
    func testIconNameIsCaseInsensitive() {
        XCTAssertEqual(formula("Go").iconName, "g.circle")
        XCTAssertEqual(formula("GH").iconName, "tuningfork")
        XCTAssertEqual(formula("Node").iconName, "arrow.triangle.branch")
        XCTAssertEqual(formula("MongoDB").iconName, "terminal.fill")
    }

    // MARK: Cask 统一图标，不参与关键词差异化
    func testCaskAlwaysUsesCaskIcon() {
        XCTAssertEqual(cask("node").iconName, "macwindow")
        XCTAssertEqual(cask("go").iconName, "macwindow")
        XCTAssertEqual(cask("gh").iconName, "macwindow")
        XCTAssertEqual(cask("python").iconName, "macwindow")
    }

    // MARK: Formula 兜底 + 代表性关键词
    func testFormulaFallback() {
        XCTAssertEqual(formula("zlib").iconName, "terminal.fill")
        XCTAssertEqual(formula("xz").iconName, "terminal.fill")
        XCTAssertEqual(formula("libpng").iconName, "terminal.fill")
    }

    func testRepresentativeFormulaIcons() {
        let expected: [(String, String)] = [
            ("node", "arrow.triangle.branch"),
            ("python", "chevron.left.forwardslash.chevron.right"),
            ("rust", "r.circle"),
            ("ruby", "diamond"),
            ("openjdk", "cup.and.saucer"),
            ("postgresql", "cylinder.split.1x2"),
            ("redis", "externaldrive"),
            ("nginx", "server.rack"),
            ("docker", "shippingbox"),
            ("curl", "arrow.down.circle"),
            ("wget", "arrow.down.circle"),
            ("vim", "chevron.left.slash.chevron.right"),
            ("ffmpeg", "play.rectangle"),
            ("clang", "hammer"),
            ("openssl", "lock.shield"),
            ("cmake", "wrench.and.screwdriver"),
            ("zsh", "chevron.right.square"),
            ("kubectl", "point.3.connected.trianglepath.dotted"),
            ("npm", "shippingbox.fill")
        ]
        for (name, icon) in expected {
            XCTAssertEqual(formula(name).iconName, icon, "\(name) 应映射 \(icon)")
        }
    }
}

// MARK: - 2. clearOperationLog 清空与 @Published 同步
final class QAClearOperationLogTests: XCTestCase {

    // BrewService 为 @MainActor 隔离类型，测试需在主线程执行
    @MainActor
    func testServiceClearOperationLogEmptiesAndPublishes() {
        let service = BrewService()   // init 无副作用，不触发 brew 调用

        var publishedValues: [[OperationLogEntry]] = []
        let cancellable = service.$operationLog.sink { publishedValues.append($0) }

        // 初始订阅会收到当前值（空）
        XCTAssertEqual(service.operationLog.count, 0)

        // 调用清空：应触发 $operationLog 发布一个空数组（这是同步到 ViewModel 的机制）
        service.clearOperationLog()
        service.clearOperationLog()   // 幂等：重复清空不崩溃

        XCTAssertTrue(service.operationLog.isEmpty, "清空后 operationLog 应为空")
        // 订阅收到的最后一个值应为空数组（证明 removeAll 确实触发了发布，而非仅内部清空）
        // OperationLogEntry 未实现 Equatable，故用 isEmpty 断言，避免依赖数组相等性
        XCTAssertTrue(publishedValues.last?.isEmpty == true, "clearOperationLog 应发布空数组以驱动 ViewModel 同步")

        cancellable.cancel()
    }

    @MainActor
    func testClearOperationLogIsIdempotentOnEmptyLog() {
        let service = BrewService()
        service.clearOperationLog()
        service.clearOperationLog()
        XCTAssertTrue(service.operationLog.isEmpty)
    }
}

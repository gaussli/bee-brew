import Foundation

// MARK: - Homebrew 环境信息（FR-001）
/// 应用启动时通过 `brew --version` / `--prefix` / `config` 检测得到的环境快照
struct BrewEnvironment: Equatable {
    var version: String = ""        // brew --version
    var prefix: String = ""         // brew --prefix
    var repository: String = ""     // brew config: HOMEBREW_REPOSITORY
    var cellar: String = ""         // brew config: HOMEBREW_CELLAR
    var cpu: String = ""            // brew config: CPU
    var os: String = ""             // brew config: OS
}

// MARK: - 清理预览条目（FR-016）
/// `brew cleanup --dry-run` 解析出的待删除项
struct CleanupItem: Identifiable, Hashable {
    var id: String { path }
    let path: String
    let isDryRun: Bool
}

// MARK: - 操作日志流方向（FR-014）
enum LogStream: Equatable {
    case stdout
    case stderr
}

// MARK: - 操作日志条目（FR-014）
/// 长耗时操作的流式输出片段，用于进度面板渲染
struct OperationLogEntry: Identifiable {
    let id = UUID()
    let stream: LogStream
    let text: String
    let timestamp: Date
}

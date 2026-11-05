import Foundation

// MARK: - 统一错误类型（NFR-012）
enum BrewError: LocalizedError, Equatable {
    case brewNotFound
    case invalidPackageName(String)                       // NFR-008
    case invalidPath(String)                              // NFR-008
    case commandFailed(cmd: String, code: Int32, stderr: String)
    case jsonDecode(String)
    case notInstalled

    var errorDescription: String? {
        switch self {
        case .brewNotFound:
            return "未检测到 Homebrew，请先在设置中配置路径"
        case .invalidPackageName(let name):
            return "非法包名：\(name)"
        case .invalidPath(let path):
            return "非法路径：\(path)"
        case .commandFailed(let cmd, let code, let stderr):
            let detail = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            if detail.isEmpty {
                return "命令 \(cmd) 执行失败（退出码 \(code)）"
            }
            return "命令 \(cmd) 执行失败（退出码 \(code)）：\(detail)"
        case .jsonDecode(let message):
            return "JSON 解析失败：\(message)"
        case .notInstalled:
            return "该包未安装"
        }
    }
}

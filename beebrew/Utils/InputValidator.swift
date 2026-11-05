import Foundation

// MARK: - 输入校验器（NFR-008 命令注入防护）
/// 包名 / 查询词 / 路径白名单校验，确保拼接进 brew 参数数组的值不含 shell 元字符。
enum InputValidator {

    /// 包名白名单：首字符字母或数字，后续允许字母、数字及 `@ . _ + / -`，总长 1~256
    /// 天然排除 `; | & $ \` > < ( )` 空格等 shell 元字符。
    /// 注意：结尾用 `\z`（绝对串尾）而非 `$`，避免末尾换行符被误判为合法（BUG-2 修复）。
    static let packageNamePattern = #"^[A-Za-z0-9][A-Za-z0-9@._+/-]{0,255}\z"#

    /// 校验包名，非法时抛错（Service 层使用）
    static func validatePackageName(_ name: String) throws {
        guard isValidPackageName(name) else {
            throw BrewError.invalidPackageName(name)
        }
    }

    /// 校验包名是否合法（非抛错版本）
    static func isValidPackageName(_ name: String) -> Bool {
        guard !name.isEmpty, name.count <= 256 else { return false }
        guard let regex = try? NSRegularExpression(pattern: packageNamePattern) else { return false }
        let range = NSRange(name.startIndex..<name.endIndex, in: name)
        // .anchored 保证整串匹配（配合 ^...\z 全锚定）
        return regex.firstMatch(in: name, options: [.anchored], range: range) != nil
    }

    /// 清洗搜索查询词：去首尾空白、移除控制字符、截断到 100 字符
    static func sanitizeQuery(_ query: String) -> String {
        var cleaned = query.trimmingCharacters(in: .whitespacesAndNewlines)
        cleaned = cleaned.unicodeScalars
            .filter { !CharacterSet.controlCharacters.contains($0) }
            .map(String.init)
            .joined()
        return String(cleaned.prefix(100))
    }

    /// 校验 brew 路径：绝对路径、文件存在且为可执行文件（NFR-009）
    static func validateBrewPath(_ path: String) -> Bool {
        let path = (path as NSString).standardizingPath
        guard (path as NSString).isAbsolutePath else { return false }
        return FileManager.default.isExecutableFile(atPath: path)
    }
}

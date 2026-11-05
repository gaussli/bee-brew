import Foundation

// MARK: - brew --json=v2 的 Decodable DTO（NFR-013：与真实 JSON 字段一一映射，不臆造字段）

/// `brew info --installed --json=v2` / `brew info --json=v2 <name>` 的根结构
struct BrewFormulaListJSON: Decodable {
    let formulae: [BrewFormulaJSON]
}

/// Formula 条目
struct BrewFormulaJSON: Decodable {
    let name: String
    let fullName: String?
    let tap: String?
    let desc: String?
    let homepage: String?
    let license: String?
    let versions: BrewVersions?
    let dependencies: [String]?
    let buildDependencies: [String]?
    let installed: [BrewInstalledEntry]?
    let outdated: Bool?
    let pinned: Bool?
    let kegOnly: Bool?
    let caveats: String?
}

/// Formula 版本信息
struct BrewVersions: Decodable {
    let stable: String?
    let head: String?
    let bottle: Bool?
}

/// Formula 已安装条目（installed[]）
struct BrewInstalledEntry: Decodable {
    let version: String?
    let time: Int64?                       // epoch 秒（NFR-013 映射为 Date）
    let installedAsDependency: Bool?       // 旧版 Homebrew 4.x 字段，7.x 已移除，故可选兜底
    let installedOnRequest: Bool?
}

/// `brew info --cask --installed --json=v2` / `brew info --cask --json=v2 <token>` 的根结构
struct BrewCaskListJSON: Decodable {
    let casks: [BrewCaskJSON]
}

/// Cask 条目
struct BrewCaskJSON: Decodable {
    let token: String
    let fullToken: String?
    let name: [String]?
    let desc: String?
    let homepage: String?
    let version: String?
    let installed: String?                 // 已安装版本字符串；未安装为 null
    let installedTime: Int64?              // epoch 秒
    let outdated: Bool?
    let autoUpdates: Bool?
    let caveats: String?
}

/// `brew outdated --json=v2` 的根结构
struct BrewOutdatedJSON: Decodable {
    let formulae: [BrewOutdatedFormula]?
    let casks: [BrewOutdatedCask]?
}

/// 可更新的 Formula
struct BrewOutdatedFormula: Decodable {
    let name: String
    let installedVersions: [String]?
    let currentVersion: String?
    let pinned: Bool?
    let pinnedVersion: String?
}

/// 可更新的 Cask
struct BrewOutdatedCask: Decodable {
    let name: String
    let installedVersions: [String]?
    let currentVersion: String?
}

/// `brew search --json=v2 <query>` 的条目（防御式：formula 用 name，cask 用 token）
struct BrewSearchItem: Decodable {
    let name: String?
    let token: String?
    let fullName: String?
    let fullToken: String?
    let tap: String?
    let desc: String?
    let homepage: String?
    let version: String?

    /// 稳定标识（cask 优先取 token，formula 取 name）
    var identifier: String { token ?? name ?? "" }

    /// 是否为 cask（有 token 字段视为 cask）
    var isCask: Bool { token != nil }
}

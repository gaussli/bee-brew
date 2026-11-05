import Foundation
import SwiftUI

// MARK: - Homebrew 包领域模型（改造后）
/// 代表一个 Homebrew 包（Formula 或 Cask）。
/// 关键改造：`id` 由 UUID 改为稳定字符串 `"type:name"`，如 `"formula:node"` / `"cask:google-chrome"`。
struct BrewPackage: Identifiable, Codable, Hashable {

    /// 稳定标识（G1 改造，波及选中集 / 操作状态字典的键）
    var id: String { "\(type.rawValue):\(name)" }

    let name: String
    let type: PackageType
    let fullName: String?
    let desc: String?
    let homepage: String?
    let license: String?
    let version: String?                // formula: versions.stable；cask: version
    let installedVersions: [String]
    var currentVersion: String?         // outdated 时的目标版本
    var installed: Bool
    var outdated: Bool
    let pinned: Bool
    let kegOnly: Bool
    let autoUpdates: Bool
    let caveats: String?
    let installedTime: Date?
    let installedAsDependency: Bool
    let installedOnRequest: Bool
    let dependencies: [String]
    let buildDependencies: [String]

    // MARK: - 包类型
    enum PackageType: String, Codable, CaseIterable, Hashable {
        case formula = "formula"
        case cask = "cask"

        var displayName: String {
            switch self {
            case .formula: return "Formula"
            case .cask: return "Cask"
            }
        }

        var iconName: String {
            switch self {
            case .formula: return "terminal.fill"
            case .cask: return "macwindow"
            }
        }

        var color: Color {
            switch self {
            case .formula: return AppColors.primary
            case .cask: return AppColors.secondary
            }
        }
    }

    // MARK: - 包状态（UI 展示用）
    enum PackageStatus: Equatable {
        case notInstalled
        case installed
        case outdated

        var displayName: String {
            switch self {
            case .notInstalled: return "未安装"
            case .installed: return "已安装"
            case .outdated: return "可更新"
            }
        }

        var iconName: String {
            switch self {
            case .notInstalled: return "circle"
            case .installed: return "checkmark.circle.fill"
            case .outdated: return "arrow.up.circle"
            }
        }

        var color: Color {
            switch self {
            case .notInstalled: return AppColors.textTertiary
            case .installed: return AppColors.success
            case .outdated: return AppColors.warning
            }
        }
    }

    // MARK: - 计算属性
    var status: PackageStatus {
        if outdated { return .outdated }
        if installed { return .installed }
        return .notInstalled
    }

    var installedVersion: String? { installedVersions.first }

    var displayVersion: String {
        installedVersion ?? version ?? "未知版本"
    }

    var displayDescription: String {
        guard let desc = desc, !desc.isEmpty else { return "暂无描述" }
        return desc
    }

    var isFormula: Bool { type == .formula }

    // MARK: - 初始化
    init(
        name: String,
        type: PackageType,
        fullName: String? = nil,
        desc: String? = nil,
        homepage: String? = nil,
        license: String? = nil,
        version: String? = nil,
        installedVersions: [String] = [],
        currentVersion: String? = nil,
        installed: Bool = false,
        outdated: Bool = false,
        pinned: Bool = false,
        kegOnly: Bool = false,
        autoUpdates: Bool = false,
        caveats: String? = nil,
        installedTime: Date? = nil,
        installedAsDependency: Bool = false,
        installedOnRequest: Bool = false,
        dependencies: [String] = [],
        buildDependencies: [String] = []
    ) {
        self.name = name
        self.type = type
        self.fullName = fullName
        self.desc = desc
        self.homepage = homepage
        self.license = license
        self.version = version
        self.installedVersions = installedVersions
        self.currentVersion = currentVersion
        self.installed = installed
        self.outdated = outdated
        self.pinned = pinned
        self.kegOnly = kegOnly
        self.autoUpdates = autoUpdates
        self.caveats = caveats
        self.installedTime = installedTime
        self.installedAsDependency = installedAsDependency
        self.installedOnRequest = installedOnRequest
        self.dependencies = dependencies
        self.buildDependencies = buildDependencies
    }

    /// 生成一个标记了安装状态的副本（搜索标记已安装，FR-005）
    func withInstalled(_ value: Bool) -> BrewPackage {
        var copy = self
        copy.installed = value
        return copy
    }

    // MARK: - Equatable / Hashable（由稳定 id 决定，DDD §5.1）
    static func == (lhs: BrewPackage, rhs: BrewPackage) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    // MARK: - 仅供 SwiftUI Preview 使用（生产路径不加载样例数据）
    static var preview: [BrewPackage] {
        [
            BrewPackage(
                name: "python",
                type: .formula,
                fullName: "python",
                desc: "Python 编程语言",
                homepage: "https://www.python.org/",
                license: "PSF-2.0",
                version: "3.11.5",
                installedVersions: ["3.11.5"],
                installed: true,
                installedTime: Date(),
                dependencies: ["openssl@3", "sqlite"]
            ),
            BrewPackage(
                name: "node",
                type: .formula,
                fullName: "node",
                desc: "Open-source, cross-platform JavaScript runtime environment",
                homepage: "https://nodejs.org/",
                license: "MIT",
                version: "22.0.0",
                installedVersions: ["21.0.0"],
                currentVersion: "22.0.0",
                installed: true,
                outdated: true,
                dependencies: ["openssl@3", "icu4c"]
            ),
            BrewPackage(
                name: "visual-studio-code",
                type: .cask,
                fullName: "visual-studio-code",
                desc: "Code editing. Redefined.",
                homepage: "https://code.visualstudio.com/",
                version: "1.96.2",
                installed: false
            )
        ]
    }
}

// MARK: - 包操作状态（FR-012/014）
enum PackageOperationState: Equatable {
    case idle
    case installing
    case uninstalling
    case updating
    case success
    case failed(String)

    var isProcessing: Bool {
        switch self {
        case .installing, .uninstalling, .updating:
            return true
        default:
            return false
        }
    }
}

// MARK: - 包过滤器（FR-019/020 P1 预留，数据模型层支持）
struct PackageFilter: Equatable {
    var searchText: String = ""
    var status: StatusFilter = .all
    var sortBy: SortOption = .name

    enum StatusFilter: String, CaseIterable {
        case all = "全部"
        case outdated = "可更新"
        case pinned = "已锁定"
    }

    enum SortOption: String, CaseIterable {
        case name = "按名称"
        case version = "按版本"
    }

    func apply(to packages: [BrewPackage]) -> [BrewPackage] {
        let filtered = packages.filter { package in
            // 搜索过滤（名称 + 描述）
            if !searchText.isEmpty {
                let needle = searchText.lowercased()
                let matchesName = package.name.lowercased().contains(needle)
                let matchesDesc = package.displayDescription.lowercased().contains(needle)
                if !matchesName && !matchesDesc { return false }
            }

            // 状态过滤
            switch status {
            case .all:
                break
            case .outdated:
                if !package.outdated { return false }
            case .pinned:
                if !package.pinned { return false }
            }

            return true
        }

        return filtered.sorted { lhs, rhs in
            switch sortBy {
            case .name:
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            case .version:
                return (lhs.displayVersion).localizedStandardCompare(rhs.displayVersion) == .orderedAscending
            }
        }
    }
}

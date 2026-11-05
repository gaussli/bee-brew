import Foundation
import SwiftUI
import Combine

// MARK: - 设置视图模型（改造后）
/// 管理 Homebrew 路径配置（FR-017）与主题（FR-018），并将有效路径注入 CommandExecutor。
@MainActor
final class SettingsViewModel: ObservableObject {

    private let userDefaults = UserDefaults.standard

    // MARK: - 发布的状态
    @Published var theme: AppTheme = .dark
    @Published var useSystemAppearance: Bool = true

    @Published var brewPath: String = ""
    @Published var customBrewPath: String = ""
    @Published var useCustomPath: Bool = false

    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    // MARK: - 初始化
    init() {
        loadSettings()
        applyBrewPath()
    }

    // MARK: - Homebrew 路径（FR-017）
    /// 有效 brew 路径：自定义 > 自动检测 > 默认
    var effectiveBrewPath: String {
        if useCustomPath && !customBrewPath.isEmpty {
            return customBrewPath
        }
        if !brewPath.isEmpty {
            return brewPath
        }
        return CommandExecutor.detectBrewPath() ?? "/opt/homebrew/bin/brew"
    }

    /// 将有效路径注入 CommandExecutor，供后续所有命令使用
    func applyBrewPath() {
        let path = effectiveBrewPath
        if InputValidator.validateBrewPath(path) {
            CommandExecutor.shared.brewPath = path
        }
    }

    /// 自动检测 brew 路径（无 shell）
    func detectBrewPath() {
        isLoading = true
        errorMessage = nil
        successMessage = nil

        Task {
            if let path = CommandExecutor.detectBrewPath() {
                brewPath = path
                applyBrewPath()
                successMessage = "已检测到 Homebrew：\(path)"
            } else {
                errorMessage = "未检测到 Homebrew 安装"
            }
            isLoading = false
            persistSettings()
        }
    }

    /// 校验路径（默认校验当前有效路径）
    func validateBrewPath(_ path: String? = nil) -> Bool {
        InputValidator.validateBrewPath(path ?? effectiveBrewPath)
    }

    // MARK: - 主题（FR-018）
    func applyTheme(to themeManager: ThemeManager) {
        themeManager.switchTheme(to: theme)
        themeManager.useSystemAppearance = useSystemAppearance
    }

    // MARK: - 持久化
    func saveSettings() {
        persistSettings()
        applyBrewPath()
        successMessage = "设置已保存"
    }

    private func persistSettings() {
        userDefaults.set(theme.rawValue, forKey: "appTheme")
        userDefaults.set(useSystemAppearance, forKey: "useSystemAppearance")
        userDefaults.set(brewPath, forKey: "brewPath")
        userDefaults.set(customBrewPath, forKey: "customBrewPath")
        userDefaults.set(useCustomPath, forKey: "useCustomPath")
        userDefaults.synchronize()
    }

    private func loadSettings() {
        if let themeRaw = userDefaults.string(forKey: "appTheme"),
           let theme = AppTheme(rawValue: themeRaw) {
            self.theme = theme
        }
        useSystemAppearance = userDefaults.object(forKey: "useSystemAppearance") as? Bool ?? true
        brewPath = userDefaults.string(forKey: "brewPath") ?? ""
        customBrewPath = userDefaults.string(forKey: "customBrewPath") ?? ""
        useCustomPath = userDefaults.object(forKey: "useCustomPath") as? Bool ?? false
    }

    // MARK: - 错误处理
    func clearMessages() {
        errorMessage = nil
        successMessage = nil
    }
}

// MARK: - 通知扩展（兼容 LocalizationManager 等既有组件）
extension Notification.Name {
    static let settingsDidChange = Notification.Name("settingsDidChange")
    static let languageDidChange = Notification.Name("languageDidChange")
    static let appearanceDidChange = Notification.Name("appearanceDidChange")
}

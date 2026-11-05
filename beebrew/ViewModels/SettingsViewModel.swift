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
        // 同步注入已持久化路径（避免 init 阶段在主线程执行 `which brew` 阻塞 UI，
        // 导致 SwiftUI AttributeGraph precondition_failure 崩溃）。
        applyBrewPath(detectIfNeeded: false)
        // 首次启动无持久化路径时，异步探测真实 brew 位置后回填。
        if brewPath.isEmpty {
            Task { [weak self] in
                await self?.detectAndApplyBrewPathAsync()
            }
        }
    }

    // MARK: - Homebrew 路径（FR-017）
    /// 有效 brew 路径：自定义 > 自动检测 > 默认。
    /// - Parameter detect: 当无可用路径时是否触发同步探测（默认 false，避免阻塞主线程）。
    var effectiveBrewPath: String {
        if useCustomPath && !customBrewPath.isEmpty {
            return customBrewPath
        }
        if !brewPath.isEmpty {
            return brewPath
        }
        return "/opt/homebrew/bin/brew"
    }

    /// 异步探测 brew 路径（不阻塞主线程），成功后注入 CommandExecutor。
    private func detectAndApplyBrewPathAsync() async {
        let path = await Task.detached {
            CommandExecutor.detectBrewPath()
        }.value
        guard let detected = path, !detected.isEmpty else { return }
        // 用户已手动配置时，不再覆盖。
        if useCustomPath && !customBrewPath.isEmpty { return }
        brewPath = detected
        applyBrewPath(detectIfNeeded: false)
        persistSettings()
    }

    /// 将有效路径注入 CommandExecutor，供后续所有命令使用。
    /// - Parameter detectIfNeeded: 为 true 时在无可用路径时同步探测（仅后台场景使用，主线程传 false）。
    func applyBrewPath(detectIfNeeded: Bool = false) {
        var path = effectiveBrewPath
        if detectIfNeeded && (path.isEmpty || path == "/opt/homebrew/bin/brew") {
            if let detected = CommandExecutor.detectBrewPath() {
                path = detected
            }
        }
        if InputValidator.validateBrewPath(path) {
            CommandExecutor.shared.brewPath = path
        }
    }

    /// 自动检测 brew 路径（无 shell，异步执行不阻塞 UI）
    func detectBrewPath() {
        isLoading = true
        errorMessage = nil
        successMessage = nil

        Task { [weak self] in
            guard let self else { return }
            let path = await Task.detached {
                CommandExecutor.detectBrewPath()
            }.value
            if let detected = path, !detected.isEmpty {
                brewPath = detected
                applyBrewPath(detectIfNeeded: false)
                successMessage = "已检测到 Homebrew：\(detected)"
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
        applyBrewPath(detectIfNeeded: false)
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

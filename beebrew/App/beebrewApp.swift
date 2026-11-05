import SwiftUI

// MARK: - 应用入口（改造后）
@main
struct beebrewApp: App {
    @StateObject private var packageViewModel = PackageViewModel()
    @StateObject private var settingsViewModel = SettingsViewModel()
    @StateObject private var localizationManager = LocalizationManager.shared
    @StateObject private var themeManager = ThemeManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(packageViewModel)
                .environmentObject(settingsViewModel)
                .environmentObject(localizationManager)
                .environmentObject(themeManager)
                .environment(\.locale, localizationManager.locale)
                .environment(\.localizationManager, localizationManager)
                .environment(\.themeManager, themeManager)
                .frame(minWidth: 900, minHeight: 600)   // NFR-003 / SRS 6.1 窗口最小尺寸
                .preferredColorScheme(themeManager.colorScheme)
        }
        .windowStyle(.titleBar)
        .windowResizability(.contentMinSize)
        .commands {
            // 侧边栏导航快捷键（FR-025：Cmd+1/2/3）
            CommandGroup(after: .newItem) {
                Button("已安装") {
                    Task { @MainActor in packageViewModel.currentTab = .installed }
                }
                .keyboardShortcut("1", modifiers: .command)

                Button("更新") {
                    Task { @MainActor in packageViewModel.currentTab = .updates }
                }
                .keyboardShortcut("2", modifiers: .command)

                Button("搜索") {
                    Task { @MainActor in packageViewModel.currentTab = .search }
                }
                .keyboardShortcut("3", modifiers: .command)
            }

            CommandGroup(after: .toolbar) {
                // 刷新（Cmd+R）
                Button("刷新") {
                    Task { await packageViewModel.refresh() }
                }
                .keyboardShortcut("r", modifiers: .command)

                // 聚焦搜索框（Cmd+F）
                Button("聚焦搜索") {
                    NotificationCenter.default.post(name: .searchFocusRequested, object: nil)
                }
                .keyboardShortcut("f", modifiers: .command)

                Divider()

                // 查看操作日志
                Button("查看日志") {
                    NotificationCenter.default.post(name: .logViewerRequested, object: nil)
                }
                .keyboardShortcut("l", modifiers: [.command, .shift])
            }
        }

        #if os(macOS)
        Settings {
            SettingsView()
                .environmentObject(settingsViewModel)
                .environmentObject(themeManager)
                .frame(width: 560, height: 420)
                .preferredColorScheme(themeManager.colorScheme)
        }
        #endif
    }
}

// MARK: - 通知扩展（搜索聚焦 / 日志查看，FR-025）
extension Notification.Name {
    static let searchFocusRequested = Notification.Name("searchFocusRequested")
    static let logViewerRequested = Notification.Name("logViewerRequested")
}

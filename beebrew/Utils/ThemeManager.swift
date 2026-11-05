import SwiftUI
import Combine

// MARK: - 主题管理器
/// 管理应用主题和外观设置
class ThemeManager: ObservableObject {
    static let shared = ThemeManager()
    
    @Published var currentTheme: AppTheme = .dark
    @Published var accentColor: Color = AppColors.primary
    @Published var useSystemAppearance: Bool = true
    
    private let userDefaults = UserDefaults.standard
    private let themeKey = "appTheme"
    private let accentColorKey = "accentColor"
    private let systemAppearanceKey = "useSystemAppearance"
    
    private init() {
        loadSettings()
        setupSystemThemeObserver()
    }
    
    // MARK: - 主题设置
    /// 切换主题
    func switchTheme(to theme: AppTheme) {
        currentTheme = theme
        saveSettings()
        
        // 应用主题变化
        applyTheme()
    }
    
    /// 切换浅色/深色模式
    func toggleDarkMode() {
        currentTheme = (currentTheme == .dark) ? .light : .dark
        saveSettings()
        applyTheme()
    }
    
    /// 设置强调色
    func setAccentColor(_ color: Color) {
        accentColor = color
        saveSettings()
    }
    
    // MARK: - 主题应用
    /// 应用当前主题
    private func applyTheme() {
        // 更新窗口外观
        #if os(macOS)
        if currentTheme == .dark {
            NSApp.appearance = NSAppearance(named: .darkAqua)
        } else {
            NSApp.appearance = NSAppearance(named: .aqua)
        }
        #endif
        
        // 发送主题变化通知
        NotificationCenter.default.post(name: .themeDidChange, object: nil)
    }
    
    /// 获取当前颜色方案
    var colorScheme: ColorScheme? {
        if useSystemAppearance {
            return nil // 让系统决定
        }
        return currentTheme.colorScheme
    }
    
    // MARK: - 系统主题观察
    private func setupSystemThemeObserver() {
        #if os(macOS)
        DistributedNotificationCenter.default.addObserver(
            forName: Notification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleSystemThemeChange()
        }
        #endif
    }
    
    private func handleSystemThemeChange() {
        if useSystemAppearance {
            #if os(macOS)
            let isDarkMode = UserDefaults.standard.string(forKey: "AppleInterfaceStyle") == "Dark"
            currentTheme = isDarkMode ? .dark : .light
            applyTheme()
            #endif
        }
    }
    
    // MARK: - 持久化
    private func loadSettings() {
        // 加载主题设置
        if let themeRawValue = userDefaults.string(forKey: themeKey),
           let theme = AppTheme(rawValue: themeRawValue) {
            currentTheme = theme
        }
        
        // 加载强调色
        if let colorData = userDefaults.data(forKey: accentColorKey),
           let color = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: colorData) {
            accentColor = Color(color)
        }
        
        // 加载系统外观设置
        useSystemAppearance = userDefaults.bool(forKey: systemAppearanceKey)
    }
    
    private func saveSettings() {
        // 保存主题
        userDefaults.set(currentTheme.rawValue, forKey: themeKey)
        
        // 保存强调色
        #if os(macOS)
        if let nsColor = NSColor(accentColor) {
            let colorData = try? NSKeyedArchiver.archivedData(withRootObject: nsColor, requiringSecureCoding: false)
            userDefaults.set(colorData, forKey: accentColorKey)
        }
        #endif
        
        // 保存系统外观设置
        userDefaults.set(useSystemAppearance, forKey: systemAppearanceKey)
        
        userDefaults.synchronize()
    }
    
    // MARK: - 实用方法
    /// 获取当前背景色
    var backgroundColor: Color {
        switch currentTheme {
        case .dark:
            return AppColors.backgroundPrimary
        case .light:
            return Color.white
        case .auto:
            #if os(macOS)
            let isDarkMode = UserDefaults.standard.string(forKey: "AppleInterfaceStyle") == "Dark"
            return isDarkMode ? AppColors.backgroundPrimary : Color.white
            #else
            return AppColors.backgroundPrimary
            #endif
        }
    }
    
    /// 获取当前卡片背景色
    var cardBackgroundColor: Color {
        switch currentTheme {
        case .dark:
            return AppColors.backgroundCard
        case .light:
            return Color(hex: "F5F5F7")
        case .auto:
            #if os(macOS)
            let isDarkMode = UserDefaults.standard.string(forKey: "AppleInterfaceStyle") == "Dark"
            return isDarkMode ? AppColors.backgroundCard : Color(hex: "F5F5F7")
            #else
            return AppColors.backgroundCard
            #endif
        }
    }
    
    /// 获取当前文本颜色
    var textColor: Color {
        switch currentTheme {
        case .dark:
            return AppColors.textPrimary
        case .light:
            return Color.black
        case .auto:
            #if os(macOS)
            let isDarkMode = UserDefaults.standard.string(forKey: "AppleInterfaceStyle") == "Dark"
            return isDarkMode ? AppColors.textPrimary : Color.black
            #else
            return AppColors.textPrimary
            #endif
        }
    }
    
    /// 获取当前次要文本颜色
    var secondaryTextColor: Color {
        switch currentTheme {
        case .dark:
            return AppColors.textSecondary
        case .light:
            return Color(hex: "3C3C43").opacity(0.6)
        case .auto:
            #if os(macOS)
            let isDarkMode = UserDefaults.standard.string(forKey: "AppleInterfaceStyle") == "Dark"
            return isDarkMode ? AppColors.textSecondary : Color(hex: "3C3C43").opacity(0.6)
            #else
            return AppColors.textSecondary
            #endif
        }
    }
}

// MARK: - 通知扩展
extension Notification.Name {
    static let themeDidChange = Notification.Name("themeDidChange")
}

// MARK: - 颜色转换扩展
#if os(macOS)
extension Color {
    /// 将SwiftUI Color转换为NSColor
    var nsColor: NSColor? {
        let scanner = Scanner(string: description.trimmingCharacters(in: CharacterSet.alphanumerics.inverted))
        var hexNumber: UInt64 = 0
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        
        if scanner.scanHexInt64(&hexNumber) {
            r = CGFloat((hexNumber & 0xff000000) >> 24) / 255
            g = CGFloat((hexNumber & 0x00ff0000) >> 16) / 255
            b = CGFloat((hexNumber & 0x0000ff00) >> 8) / 255
            a = CGFloat(hexNumber & 0x000000ff) / 255
            
            return NSColor(red: r, green: g, blue: b, alpha: a)
        }
        return nil
    }
}

extension NSColor {
    /// 使用SwiftUI Color创建NSColor
    convenience init?(_ color: Color) {
        if let nsColor = color.nsColor {
            self.init(cgColor: nsColor.cgColor)
        } else {
            return nil
        }
    }
}
#endif

// MARK: - 主题环境值
struct ThemeEnvironmentKey: EnvironmentKey {
    static let defaultValue = ThemeManager.shared
}

extension EnvironmentValues {
    var themeManager: ThemeManager {
        get { self[ThemeEnvironmentKey.self] }
        set { self[ThemeEnvironmentKey.self] = newValue }
    }
}

// MARK: - 主题预览
struct ThemePreview<Content: View>: View {
    @Environment(\.themeManager) private var themeManager
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .preferredColorScheme(themeManager.colorScheme)
            .background(themeManager.backgroundColor)
            .environment(\.themeManager, themeManager)
    }
}


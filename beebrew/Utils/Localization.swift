import Foundation
import SwiftUI

// MARK: - 本地化管理器
/// 管理应用的多语言支持
class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()
    
    @Published var currentLanguage: AppLanguage = .system
    @Published var locale: Locale = .current
    
    private let userDefaults = UserDefaults.standard
    private let languageKey = "appLanguage"
    
    private init() {
        loadLanguageSetting()
        updateLocale()
    }
    
    // MARK: - 语言设置
    enum AppLanguage: String, CaseIterable {
        case system = "system"
        case english = "en"
        case chineseSimplified = "zh-Hans"
        
        var displayName: String {
            switch self {
            case .system:
                return NSLocalizedString("跟随系统", comment: "")
            case .english:
                return "English"
            case .chineseSimplified:
                return "中文"
            }
        }
        
        var localeIdentifier: String {
            switch self {
            case .system:
                return Locale.current.identifier
            case .english:
                return "en"
            case .chineseSimplified:
                return "zh-Hans"
            }
        }
    }
    
    // MARK: - 语言管理
    /// 切换语言
    func switchLanguage(to language: AppLanguage) {
        currentLanguage = language
        saveLanguageSetting()
        updateLocale()
        
        // 发送语言变化通知
        NotificationCenter.default.post(name: .languageDidChange, object: nil)
    }
    
    /// 更新当前语言环境
    private func updateLocale() {
        locale = Locale(identifier: currentLanguage.localeIdentifier)
    }
    
    // MARK: - 持久化
    private func loadLanguageSetting() {
        if let languageRaw = userDefaults.string(forKey: languageKey),
           let language = AppLanguage(rawValue: languageRaw) {
            currentLanguage = language
        } else {
            // 默认跟随系统，但根据系统语言选择默认语言
            let systemLanguage = Locale.current.language.languageCode?.identifier ?? "en"
            currentLanguage = systemLanguage.hasPrefix("zh") ? .chineseSimplified : .english
        }
    }
    
    private func saveLanguageSetting() {
        userDefaults.set(currentLanguage.rawValue, forKey: languageKey)
        userDefaults.synchronize()
    }
    
    // MARK: - 实用方法
    /// 获取本地化字符串
    func localizedString(_ key: String, table: String? = nil, comment: String = "") -> String {
        let bundle = Bundle.main
        
        // 如果当前语言是"跟随系统"，使用系统语言
        if currentLanguage == .system {
            return NSLocalizedString(key, tableName: table, bundle: bundle, comment: comment)
        }
        
        // 否则使用指定语言
        if let path = bundle.path(forResource: currentLanguage.rawValue, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return bundle.localizedString(forKey: key, value: comment, table: table)
        }
        
        // 回退到英语
        if let path = bundle.path(forResource: "en", ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return bundle.localizedString(forKey: key, value: comment, table: table)
        }
        
        return key
    }
    
    /// 检查是否是中文环境
    var isChineseEnvironment: Bool {
        return locale.identifier.hasPrefix("zh")
    }
    
    /// 获取当前语言代码
    var languageCode: String {
        return currentLanguage.rawValue
    }
}

// MARK: - 本地化字符串扩展
extension String {
    /// 本地化字符串快捷方式
    var localized: String {
        return LocalizationManager.shared.localizedString(self)
    }
    
    /// 带注释的本地化字符串
    func localized(comment: String = "") -> String {
        return LocalizationManager.shared.localizedString(self, comment: comment)
    }
    
    /// 带表格名的本地化字符串
    func localized(table: String, comment: String = "") -> String {
        return LocalizationManager.shared.localizedString(self, table: table, comment: comment)
    }
}

// MARK: - 本地化视图修饰器
struct LocalizedViewModifier: ViewModifier {
    @EnvironmentObject private var localizationManager: LocalizationManager
    
    func body(content: Content) -> some View {
        content
            .environment(\.locale, localizationManager.locale)
    }
}

extension View {
    /// 应用本地化设置
    func localized() -> some View {
        self.modifier(LocalizedViewModifier())
    }
}

// MARK: - 本地化环境值
struct LocalizationEnvironmentKey: EnvironmentKey {
    static let defaultValue = LocalizationManager.shared
}

extension EnvironmentValues {
    var localizationManager: LocalizationManager {
        get { self[LocalizationEnvironmentKey.self] }
        set { self[LocalizationEnvironmentKey.self] = newValue }
    }
}

// MARK: - 本地化文本视图
struct LocalizedText: View {
    let key: String
    let table: String?
    let comment: String
    let textCase: Text.Case?
    
    init(_ key: String, table: String? = nil, comment: String = "", textCase: Text.Case? = nil) {
        self.key = key
        self.table = table
        self.comment = comment
        self.textCase = textCase
    }
    
    var body: some View {
        let localizedString = LocalizationManager.shared.localizedString(key, table: table, comment: comment)
        
        if let textCase = textCase {
            Text(localizedString)
                .textCase(textCase)
        } else {
            Text(localizedString)
        }
    }
}

// MARK: - 语言切换视图
struct LanguageSelectorView: View {
    @EnvironmentObject private var localizationManager: LocalizationManager
    
    var body: some View {
        Picker("语言", selection: $localizationManager.currentLanguage) {
            ForEach(LocalizationManager.AppLanguage.allCases, id: \.self) { language in
                Text(language.displayName).tag(language)
            }
        }
        .pickerStyle(.segmented)
        .onChange(of: localizationManager.currentLanguage) { newValue in
            localizationManager.switchLanguage(to: newValue)
        }
    }
}

// MARK: - 本地化资源管理
struct LocalizationResources {
    /// 创建本地化字符串文件
    static func createLocalizationFiles() {
        createEnglishStrings()
        createChineseStrings()
    }
    
    private static func createEnglishStrings() {
        let englishStrings = """
        // 通用
        "跟随系统" = "Follow System";
        "完成" = "Done";
        "取消" = "Cancel";
        "确定" = "OK";
        "是" = "Yes";
        "否" = "No";
        "保存" = "Save";
        "重置" = "Reset";
        "刷新" = "Refresh";
        
        // 导航
        "探索" = "Explore";
        "已安装" = "Installed";
        "更新" = "Updates";
        "系统" = "System";
        "设置" = "Settings";
        
        // 包状态
        "未安装" = "Not Installed";
        "已安装" = "Installed";
        "可更新" = "Update Available";
        "安装中" = "Installing";
        "卸载中" = "Uninstalling";
        "更新中" = "Updating";
        "错误" = "Error";
        
        // 包操作
        "安装" = "Install";
        "卸载" = "Uninstall";
        "更新" = "Update";
        "查看详情" = "View Details";
        "收起详情" = "Hide Details";
        
        // 过滤器
        "过滤器" = "Filter";
        "包类型" = "Package Type";
        "类别" = "Category";
        "显示已安装" = "Show Installed";
        "显示未安装" = "Show Not Installed";
        "显示可更新" = "Show Updateable";
        "排序方式" = "Sort By";
        "按名称" = "By Name";
        "按流行度" = "By Popularity";
        "按更新时间" = "By Update Time";
        "重置过滤器" = "Reset Filters";
        
        // 批量操作
        "批量操作" = "Bulk Actions";
        "更新选中" = "Update Selected";
        "卸载选中" = "Uninstall Selected";
        "取消选择" = "Deselect All";
        
        // 统计信息
        "总包数" = "Total Packages";
        "已安装" = "Installed";
        "可更新" = "Updateable";
        
        // 快捷操作
        "更新Homebrew" = "Update Homebrew";
        "清理缓存" = "Clean Cache";
        
        // 搜索
        "搜索Homebrew包..." = "Search Homebrew packages...";
        "搜索中..." = "Searching...";
        "未找到匹配的包" = "No packages found";
        "尝试不同的搜索关键词" = "Try different search keywords";
        "暂无包数据" = "No package data";
        "尝试搜索Homebrew包" = "Try searching Homebrew packages";
        
        // 错误消息
        "安装失败" = "Installation failed";
        "卸载失败" = "Uninstallation failed";
        "更新失败" = "Update failed";
        "更新所有包失败" = "Failed to update all packages";
        "更新Homebrew失败" = "Failed to update Homebrew";
        "清理缓存失败" = "Failed to clean cache";
        "无法加载包详情" = "Failed to load package details";
        
        // 设置
        "通用" = "General";
        "外观" = "Appearance";
        "Homebrew" = "Homebrew";
        "缓存" = "Cache";
        "关于" = "About";
        "应用语言" = "App Language";
        "自动检查更新" = "Auto-check for updates";
        "检查频率" = "Check Frequency";
        "从不" = "Never";
        "每小时" = "Hourly";
        "每天" = "Daily";
        "每周" = "Weekly";
        "显示通知" = "Show Notifications";
        "发送匿名使用统计" = "Send Anonymous Usage Statistics";
        "重置所有设置为默认值" = "Reset All Settings to Default";
        "应用主题" = "App Theme";
        "深色" = "Dark";
        "浅色" = "Light";
        "自动" = "Auto";
        "跟随系统外观" = "Follow System Appearance";
        "强调色" = "Accent Color";
        "预览" = "Preview";
        "Homebrew路径" = "Homebrew Path";
        "使用自定义路径" = "Use Custom Path";
        "自动检测路径" = "Auto Detect Path";
        "连接测试" = "Connection Test";
        "测试连接" = "Test Connection";
        "Homebrew路径有效" = "Homebrew path is valid";
        "Homebrew路径无效或不存在" = "Homebrew path is invalid or does not exist";
        "连接成功" = "Connection successful";
        "连接失败" = "Connection failed";
        "缓存管理" = "Cache Management";
        "缓存大小" = "Cache Size";
        "文件数量" = "File Count";
        "自动清理缓存" = "Auto Clean Cache";
        "最大缓存大小" = "Max Cache Size";
        "刷新缓存信息" = "Refresh Cache Info";
        "立即清理缓存" = "Clean Cache Now";
        "应用信息" = "App Information";
        "技术支持" = "Technical Support";
        "查看文档" = "View Documentation";
        "报告问题" = "Report Issues";
        "检查更新" = "Check for Updates";
        "法律信息" = "Legal Information";
        
        // 包类别
        "Python" = "Python";
        "Node.js" = "Node.js";
        "Ruby" = "Ruby";
        "Java" = "Java";
        "Go" = "Go";
        "Rust" = "Rust";
        "数据库" = "Database";
        "编辑器" = "Editor";
        "浏览器" = "Browser";
        "多媒体" = "Media";
        "游戏" = "Game";
        "工具" = "Utility";
        "其他" = "Other";
        
        // 包类型
        "Formula" = "Formula";
        "Cask" = "Cask";
        """
        
        // 在实际应用中，这里应该将字符串写入文件
        // let path = Bundle.main.path(forResource: "en", ofType: "lproj/Localizable.strings")
        // try? englishStrings.write(toFile: path, atomically: true, encoding: .utf8)
    }
    
    private static func createChineseStrings() {
        let chineseStrings = """
        // 通用
        "跟随系统" = "跟随系统";
        "完成" = "完成";
        "取消" = "取消";
        "确定" = "确定";
        "是" = "是";
        "否" = "否";
        "保存" = "保存";
        "重置" = "重置";
        "刷新" = "刷新";
        
        // 导航
        "探索" = "探索";
        "已安装" = "已安装";
        "更新" = "更新";
        "系统" = "系统";
        "设置" = "设置";
        
        // 包状态
        "未安装" = "未安装";
        "已安装" = "已安装";
        "可更新" = "可更新";
        "安装中" = "安装中";
        "卸载中" = "卸载中";
        "更新中" = "更新中";
        "错误" = "错误";
        
        // 包操作
        "安装" = "安装";
        "卸载" = "卸载";
        "更新" = "更新";
        "查看详情" = "查看详情";
        "收起详情" = "收起详情";
        
        // 过滤器
        "过滤器" = "过滤器";
        "包类型" = "包类型";
        "类别" = "类别";
        "显示已安装" = "显示已安装";
        "显示未安装" = "显示未安装";
        "显示可更新" = "显示可更新";
        "排序方式" = "排序方式";
        "按名称" = "按名称";
        "按流行度" = "按流行度";
        "按更新时间" = "按更新时间";
        "重置过滤器" = "重置过滤器";
        
        // 批量操作
        "批量操作" = "批量操作";
        "更新选中" = "更新选中";
        "卸载选中" = "卸载选中";
        "取消选择" = "取消选择";
        
        // 统计信息
        "总包数" = "总包数";
        "已安装" = "已安装";
        "可更新" = "可更新";
        
        // 快捷操作
        "更新Homebrew" = "更新Homebrew";
        "清理缓存" = "清理缓存";
        
        // 搜索
        "搜索Homebrew包..." = "搜索Homebrew包...";
        "搜索中..." = "搜索中...";
        "未找到匹配的包" = "未找到匹配的包";
        "尝试不同的搜索关键词" = "尝试不同的搜索关键词";
        "暂无包数据" = "暂无包数据";
        "尝试搜索Homebrew包" = "尝试搜索Homebrew包";
        
        // 错误消息
        "安装失败" = "安装失败";
        "卸载失败" = "卸载失败";
        "更新失败" = "更新失败";
        "更新所有包失败" = "更新所有包失败";
        "更新Homebrew失败" = "更新Homebrew失败";
        "清理缓存失败" = "清理缓存失败";
        "无法加载包详情" = "无法加载包详情";
        
        // 设置
        "通用" = "通用";
        "外观" = "外观";
        "Homebrew" = "Homebrew";
        "缓存" = "缓存";
        "关于" = "关于";
        "应用语言" = "应用语言";
        "自动检查更新" = "自动检查更新";
        "检查频率" = "检查频率";
        "从不" = "从不";
        "每小时" = "每小时";
        "每天" = "每天";
        "每周" = "每周";
        "显示通知" = "显示通知";
        "发送匿名使用统计" = "发送匿名使用统计";
        "重置所有设置为默认值" = "重置所有设置为默认值";
        "应用主题" = "应用主题";
        "深色" = "深色";
        "浅色" = "浅色";
        "自动" = "自动";
        "跟随系统外观" = "跟随系统外观";
        "强调色" = "强调色";
        "预览" = "预览";
        "Homebrew路径" = "Homebrew路径";
        "使用自定义路径" = "使用自定义路径";
        "自动检测路径" = "自动检测路径";
        "连接测试" = "连接测试";
        "测试连接" = "测试连接";
        "Homebrew路径有效" = "Homebrew路径有效";
        "Homebrew路径无效或不存在" = "Homebrew路径无效或不存在";
        "连接成功" = "连接成功";
        "连接失败" = "连接失败";
        "缓存管理" = "缓存管理";
        "缓存大小" = "缓存大小";
        "文件数量" = "文件数量";
        "自动清理缓存" = "自动清理缓存";
        "最大缓存大小" = "最大缓存大小";
        "刷新缓存信息" = "刷新缓存信息";
        "立即清理缓存" = "立即清理缓存";
        "应用信息" = "应用信息";
        "技术支持" = "技术支持";
        "查看文档" = "查看文档";
        "报告问题" = "报告问题";
        "检查更新" = "检查更新";
        "法律信息" = "法律信息";
        
        // 包类别
        "Python" = "Python";
        "Node.js" = "Node.js";
        "Ruby" = "Ruby";
        "Java" = "Java";
        "Go" = "Go";
        "Rust" = "Rust";
        "数据库" = "数据库";
        "编辑器" = "编辑器";
        "浏览器" = "浏览器";
        "多媒体" = "多媒体";
        "游戏" = "游戏";
        "工具" = "工具";
        "其他" = "其他";
        
        // 包类型
        "Formula" = "Formula";
        "Cask" = "Cask";
        """
        
        // 在实际应用中，这里应该将字符串写入文件
        // let path = Bundle.main.path(forResource: "zh-Hans", ofType: "lproj/Localizable.strings")
        // try? chineseStrings.write(toFile: path, atomically: true, encoding: .utf8)
    }
}

// MARK: - 本地化预览
struct LocalizationPreview<Content: View>: View {
    @EnvironmentObject private var localizationManager: LocalizationManager
    let content: Content
    let language: LocalizationManager.AppLanguage
    
    init(_ language: LocalizationManager.AppLanguage, @ViewBuilder content: () -> Content) {
        self.language = language
        self.content = content()
    }
    
    var body: some View {
        content
            .environment(\.locale, Locale(identifier: language.localeIdentifier))
            .environmentObject({
                let manager = LocalizationManager.shared
                manager.currentLanguage = language
                manager.locale = Locale(identifier: language.localeIdentifier)
                return manager
            }())
    }
}
import SwiftUI

// MARK: - 颜色系统
/// beebrew应用的色彩系统
struct AppColors {
    // 主色调 - 科技蓝
    static let primary = Color(hex: "0A84FF")
    static let primaryLight = Color(hex: "64D2FF")
    static let primaryDark = Color(hex: "0056CC")
    
    // 次要色调 - 紫色
    static let secondary = Color(hex: "5E5CE6")
    static let secondaryLight = Color(hex: "8A88FF")
    static let secondaryDark = Color(hex: "3D3BB3")
    
    // 背景色 - 深色主题
    static let backgroundPrimary = Color(hex: "1C1C1E")
    static let backgroundSecondary = Color(hex: "2C2C2E")
    static let backgroundTertiary = Color(hex: "3A3A3C")
    static let backgroundCard = Color(hex: "2A2A2C")
    
    // 文本颜色
    static let textPrimary = Color(hex: "FFFFFF")
    static let textSecondary = Color(hex: "EBEBF5")
    static let textTertiary = Color(hex: "8E8E93")
    static let textDisabled = Color(hex: "6C6C70")
    
    // 功能颜色
    static let success = Color(hex: "30D158")  // 绿色 - 成功
    static let error = Color(hex: "FF453A")    // 红色 - 错误
    static let warning = Color(hex: "FF9F0A")  // 橙色 - 警告
    static let info = Color(hex: "5E5CE6")     // 紫色 - 信息
    
    // 渐变
    static let gradientPrimary = LinearGradient(
        gradient: Gradient(colors: [primary, primaryLight]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let gradientSecondary = LinearGradient(
        gradient: Gradient(colors: [secondary, secondaryLight]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // 阴影
    static let shadowColor = Color.black.opacity(0.2)
    
    // 透明度
    static let overlayLight = Color.white.opacity(0.1)
    static let overlayDark = Color.black.opacity(0.2)
}

// MARK: - 颜色扩展
extension Color {
    /// 通过十六进制字符串创建颜色
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - 样式定义
struct AppStyles {
    /// 圆角大小
    static let cornerRadius: CGFloat = 12
    static let cornerRadiusSmall: CGFloat = 8
    static let cornerRadiusLarge: CGFloat = 16
    
    /// 阴影
    static let shadow: some ViewModifier = ShadowModifier()
    
    /// 卡片样式
    static let cardStyle: some ViewModifier = CardModifier()
    
    /// 按钮样式
    static let primaryButtonStyle: some ButtonStyle = PrimaryButtonStyle()
    static let secondaryButtonStyle: some ButtonStyle = SecondaryButtonStyle()
}

// MARK: - 阴影修饰器
struct ShadowModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .shadow(color: AppColors.shadowColor, radius: 8, x: 0, y: 4)
            .shadow(color: AppColors.shadowColor.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

// MARK: - 卡片修饰器
struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(AppColors.backgroundCard)
            .cornerRadius(AppStyles.cornerRadius)
            .modifier(AppStyles.shadow)
            .overlay(
                RoundedRectangle(cornerRadius: AppStyles.cornerRadius)
                    .stroke(AppColors.overlayLight, lineWidth: 1)
            )
    }
}

// MARK: - 按钮样式
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(AppColors.textPrimary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                AppColors.gradientPrimary
                    .cornerRadius(AppStyles.cornerRadiusSmall)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
            .modifier(AppStyles.shadow)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    var color: Color = AppColors.textSecondary

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(color)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(color.opacity(0.1))
            .cornerRadius(AppStyles.cornerRadiusSmall)
            .overlay(
                RoundedRectangle(cornerRadius: AppStyles.cornerRadiusSmall)
                    .stroke(color.opacity(0.3), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - 小尺寸主按钮（列表行内操作）
struct SmallPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(AppColors.primary)
            .cornerRadius(6)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - 主题定义
enum AppTheme: String, CaseIterable {
    case dark = "深色"
    case light = "浅色"
    case auto = "自动"
    
    var colorScheme: ColorScheme? {
        switch self {
        case .dark: return .dark
        case .light: return .light
        case .auto: return nil
        }
    }
}
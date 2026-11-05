import SwiftUI

// MARK: - 字体系统
/// beebrew应用的字体系统
struct AppFonts {
    // 字体家族
    static let primary = "SF Pro Display"
    static let secondary = "SF Pro Text"
    static let chinese = "PingFang SC"
    
    // 标题字体
    static let largeTitle: Font = .system(size: 34, weight: .bold, design: .default)
    static let title1: Font = .system(size: 28, weight: .bold, design: .default)
    static let title2: Font = .system(size: 22, weight: .semibold, design: .default)
    static let title3: Font = .system(size: 20, weight: .semibold, design: .default)
    
    // 正文字体
    static let headline: Font = .system(size: 17, weight: .semibold, design: .default)
    static let body: Font = .system(size: 17, weight: .regular, design: .default)
    static let callout: Font = .system(size: 16, weight: .regular, design: .default)
    static let subheadline: Font = .system(size: 15, weight: .regular, design: .default)
    static let footnote: Font = .system(size: 13, weight: .regular, design: .default)
    static let caption1: Font = .system(size: 12, weight: .regular, design: .default)
    static let caption2: Font = .system(size: 11, weight: .regular, design: .default)
    
    // 代码字体
    static let code: Font = .system(size: 14, weight: .regular, design: .monospaced)
    static let codeBold: Font = .system(size: 14, weight: .semibold, design: .monospaced)
    
    // 特殊字体
    static let badge: Font = .system(size: 10, weight: .medium, design: .default)
}

// MARK: - 文本样式
struct TextStyles {
    /// 标题样式
    static func titleStyle(_ font: Font = AppFonts.title2, color: Color = AppColors.textPrimary) -> some ViewModifier {
        TitleModifier(font: font, color: color)
    }
    
    /// 正文字体样式
    static func bodyStyle(_ font: Font = AppFonts.body, color: Color = AppColors.textSecondary) -> some ViewModifier {
        BodyModifier(font: font, color: color)
    }
    
    /// 辅助文本样式
    static func captionStyle(_ font: Font = AppFonts.caption1, color: Color = AppColors.textTertiary) -> some ViewModifier {
        CaptionModifier(font: font, color: color)
    }
    
    /// 标签样式
    static func labelStyle(color: Color = AppColors.primary, backgroundColor: Color = AppColors.primary.opacity(0.2)) -> some ViewModifier {
        LabelModifier(color: color, backgroundColor: backgroundColor)
    }
}

// MARK: - 文本修饰器
struct TitleModifier: ViewModifier {
    let font: Font
    let color: Color
    
    func body(content: Content) -> some View {
        content
            .font(font)
            .foregroundColor(color)
            .lineSpacing(4)
    }
}

struct BodyModifier: ViewModifier {
    let font: Font
    let color: Color
    
    func body(content: Content) -> some View {
        content
            .font(font)
            .foregroundColor(color)
            .lineSpacing(3)
    }
}

struct CaptionModifier: ViewModifier {
    let font: Font
    let color: Color
    
    func body(content: Content) -> some View {
        content
            .font(font)
            .foregroundColor(color)
            .lineSpacing(2)
    }
}

struct LabelModifier: ViewModifier {
    let color: Color
    let backgroundColor: Color
    
    func body(content: Content) -> some View {
        content
            .font(AppFonts.caption2)
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(backgroundColor)
            .cornerRadius(6)
    }
}

// MARK: - 预定义文本样式
extension View {
    /// 应用标题样式
    func appTitle(_ font: Font = AppFonts.title2, color: Color = AppColors.textPrimary) -> some View {
        self.modifier(TextStyles.titleStyle(font, color: color))
    }
    
    /// 应用正文字体样式
    func appBody(_ font: Font = AppFonts.body, color: Color = AppColors.textSecondary) -> some View {
        self.modifier(TextStyles.bodyStyle(font, color: color))
    }
    
    /// 应用辅助文本样式
    func appCaption(_ font: Font = AppFonts.caption1, color: Color = AppColors.textTertiary) -> some View {
        self.modifier(TextStyles.captionStyle(font, color: color))
    }
    
    /// 应用标签样式
    func appLabel(color: Color = AppColors.primary, backgroundColor: Color = AppColors.primary.opacity(0.2)) -> some View {
        self.modifier(TextStyles.labelStyle(color: color, backgroundColor: backgroundColor))
    }
}

// MARK: - 文本组件
struct AppText: View {
    enum Style {
        case largeTitle, title1, title2, title3
        case headline, body, callout, subheadline
        case footnote, caption1, caption2
        case code, codeBold
        case badge
        
        var font: Font {
            switch self {
            case .largeTitle: return AppFonts.largeTitle
            case .title1: return AppFonts.title1
            case .title2: return AppFonts.title2
            case .title3: return AppFonts.title3
            case .headline: return AppFonts.headline
            case .body: return AppFonts.body
            case .callout: return AppFonts.callout
            case .subheadline: return AppFonts.subheadline
            case .footnote: return AppFonts.footnote
            case .caption1: return AppFonts.caption1
            case .caption2: return AppFonts.caption2
            case .code: return AppFonts.code
            case .codeBold: return AppFonts.codeBold
            case .badge: return AppFonts.badge
            }
        }
    }
    
    let text: String
    let style: Style
    let color: Color
    let alignment: TextAlignment
    
    init(_ text: String, style: Style = .body, color: Color = AppColors.textSecondary, alignment: TextAlignment = .leading) {
        self.text = text
        self.style = style
        self.color = color
        self.alignment = alignment
    }
    
    var body: some View {
        Text(text)
            .font(style.font)
            .foregroundColor(color)
            .multilineTextAlignment(alignment)
            .lineSpacing(style == .body || style == .callout ? 3 : 2)
    }
}

// MARK: - 文本组合视图
struct AppTextGroup: View {
    let title: String
    let subtitle: String?
    let detail: String?
    
    init(title: String, subtitle: String? = nil, detail: String? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.detail = detail
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            AppText(title, style: .headline, color: AppColors.textPrimary)
            
            if let subtitle = subtitle {
                AppText(subtitle, style: .subheadline, color: AppColors.textSecondary)
            }
            
            if let detail = detail {
                AppText(detail, style: .caption1, color: AppColors.textTertiary)
            }
        }
    }
}

// MARK: - 标签视图
struct AppLabel: View {
    let text: String
    let icon: String?
    let style: LabelStyle
    
    enum LabelStyle {
        case primary, secondary, success, warning, error, info
        
        var backgroundColor: Color {
            switch self {
            case .primary: return AppColors.primary.opacity(0.2)
            case .secondary: return AppColors.secondary.opacity(0.2)
            case .success: return AppColors.success.opacity(0.2)
            case .warning: return AppColors.warning.opacity(0.2)
            case .error: return AppColors.error.opacity(0.2)
            case .info: return AppColors.info.opacity(0.2)
            }
        }
        
        var foregroundColor: Color {
            switch self {
            case .primary: return AppColors.primary
            case .secondary: return AppColors.secondary
            case .success: return AppColors.success
            case .warning: return AppColors.warning
            case .error: return AppColors.error
            case .info: return AppColors.info
            }
        }
    }
    
    var body: some View {
        HStack(spacing: 4) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .medium))
            }
            
            AppText(text, style: .caption2, color: style.foregroundColor)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(style.backgroundColor)
        .cornerRadius(6)
    }
}
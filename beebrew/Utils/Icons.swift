import SwiftUI

// MARK: - 图标系统
/// beebrew应用的图标系统
struct AppIcons {
    // 导航图标
    static let home = "house.fill"
    static let search = "magnifyingglass"
    static let installed = "checklist"
    static let updates = "arrow.clockwise"
    static let system = "gear"
    static let settings = "slider.horizontal.3"
    
    // 操作图标
    static let install = "plus.circle.fill"
    static let uninstall = "minus.circle.fill"
    static let update = "arrow.up.circle.fill"
    static let refresh = "arrow.clockwise.circle"
    static let info = "info.circle"
    static let star = "star.fill"
    static let starOutline = "star"
    
    // 状态图标
    static let success = "checkmark.circle.fill"
    static let error = "xmark.circle.fill"
    static let warning = "exclamationmark.triangle.fill"
    static let loading = "arrow.triangle.2.circlepath"
    static let downloading = "arrow.down.circle"
    
    // 包类型图标
    static let formula = "terminal.fill"
    static let cask = "macwindow"
    static let dependency = "link"
    static let library = "books.vertical.fill"
    static let tool = "hammer.fill"
    
    // 系统图标
    static let disk = "internaldrive.fill"
    static let memory = "memorychip"
    static let network = "network"
    static let battery = "battery.100"
    static let cpu = "cpu"
    
    // 界面图标
    static let chevronRight = "chevron.right"
    static let chevronDown = "chevron.down"
    static let menu = "line.horizontal.3"
    static let close = "xmark"
    static let back = "arrow.left"
    static let forward = "arrow.right"
    
    // 功能图标
    static let filter = "line.horizontal.3.decrease.circle"
    static let sort = "arrow.up.arrow.down"
    static let share = "square.and.arrow.up"
    static let copy = "doc.on.doc"
    static let trash = "trash"
    static let favorite = "heart.fill"
    
    // 蜜蜂主题图标（自定义）
    static let bee = "􀆅"  // 蜜蜂图标
    static let honeycomb = "􀑙"  // 蜂窝图标
    static let honey = "􀆃"  // 蜂蜜图标
}

// MARK: - 图标视图扩展
extension Image {
    /// 应用图标视图
    static func appIcon(_ name: String, size: CGFloat = 20, color: Color = AppColors.textPrimary) -> some View {
        Image(systemName: name)
            .font(.system(size: size, weight: .medium))
            .foregroundColor(color)
    }
    
    /// 带有背景的图标
    static func appIconWithBackground(_ name: String, backgroundColor: Color = AppColors.primary, foregroundColor: Color = .white) -> some View {
        Image(systemName: name)
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(foregroundColor)
            .frame(width: 32, height: 32)
            .background(backgroundColor)
            .cornerRadius(8)
    }
}

// MARK: - 图标样式
struct IconStyle {
    let size: CGFloat
    let weight: Font.Weight
    let color: Color
    
    static let small = IconStyle(size: 16, weight: .regular, color: AppColors.textTertiary)
    static let medium = IconStyle(size: 20, weight: .medium, color: AppColors.textSecondary)
    static let large = IconStyle(size: 24, weight: .semibold, color: AppColors.textPrimary)
    static let xlarge = IconStyle(size: 32, weight: .bold, color: AppColors.textPrimary)
}

// MARK: - 自定义图标视图
struct AppIconView: View {
    let name: String
    let style: IconStyle
    let backgroundColor: Color?
    
    init(_ name: String, style: IconStyle = .medium, backgroundColor: Color? = nil) {
        self.name = name
        self.style = style
        self.backgroundColor = backgroundColor
    }
    
    var body: some View {
        if let backgroundColor = backgroundColor {
            Image(systemName: name)
                .font(.system(size: style.size, weight: style.weight))
                .foregroundColor(style.color)
                .frame(width: style.size * 1.5, height: style.size * 1.5)
                .background(backgroundColor.opacity(0.2))
                .cornerRadius(style.size * 0.75)
        } else {
            Image(systemName: name)
                .font(.system(size: style.size, weight: style.weight))
                .foregroundColor(style.color)
        }
    }
}

// MARK: - 状态图标
struct StatusIconView: View {
    let status: PackageStatus
    let size: CGFloat
    
    enum PackageStatus {
        case installed, updating, error, warning, success, loading
        
        var iconName: String {
            switch self {
            case .installed: return AppIcons.success
            case .updating: return AppIcons.loading
            case .error: return AppIcons.error
            case .warning: return AppIcons.warning
            case .success: return AppIcons.success
            case .loading: return AppIcons.loading
            }
        }
        
        var color: Color {
            switch self {
            case .installed: return AppColors.success
            case .updating: return AppColors.primary
            case .error: return AppColors.error
            case .warning: return AppColors.warning
            case .success: return AppColors.success
            case .loading: return AppColors.textTertiary
            }
        }
    }
    
    var body: some View {
        if status == .loading {
            Image(systemName: status.iconName)
                .font(.system(size: size, weight: .medium))
                .foregroundColor(status.color)
                .rotationEffect(.degrees(360))
                .animation(
                    Animation.linear(duration: 1.0)
                        .repeatForever(autoreverses: false),
                    value: true
                )
        } else {
            Image(systemName: status.iconName)
                .font(.system(size: size, weight: .medium))
                .foregroundColor(status.color)
        }
    }
}
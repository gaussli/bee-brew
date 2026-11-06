import SwiftUI

// MARK: - 侧边栏导航（SRS 6.2）
/// 4 个导航项：已安装 / 更新（Badge）/ 搜索 / 设置，更新项展示可升级数量 Badge（FR-010）。
struct SidebarView: View {
    @EnvironmentObject private var packageViewModel: PackageViewModel
    @Environment(\.themeManager) private var themeManager

    var body: some View {
        List(selection: $packageViewModel.currentTab) {
            ForEach(AppTab.allCases) { tab in
                Label {
                    HStack {
                        Text(tab.rawValue)
                        Spacer()
                        if tab == .updates && !packageViewModel.outdatedPackages.isEmpty {
                            Text("\(packageViewModel.outdatedPackages.count)")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(AppColors.warning)
                                .clipShape(Capsule())
                        }
                    }
                } icon: {
                    Image(systemName: tab.iconName)
                        .foregroundColor(packageViewModel.currentTab == tab ? tab.color : AppColors.textSecondary)
                }
                .tag(tab)
            }

            Divider()

            // 日志入口
            Button {
                NotificationCenter.default.post(name: .logViewerRequested, object: nil)
            } label: {
                Label("日志", systemImage: "doc.text.magnifyingglass")
                    .foregroundColor(AppColors.textPrimary)
            }
            .buttonStyle(.plain)

            // 环境状态（FR-001）
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    if packageViewModel.environment.version.isEmpty {
                        Label("未检测到 Homebrew", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundColor(AppColors.warning)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    } else {
                        Label(packageViewModel.environment.version, systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(AppColors.success)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .truncationMode(.middle)
                    }
                    Text("已安装 \(packageViewModel.installedPackages.count)")
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                    Text("可更新 \(packageViewModel.outdatedPackages.count)")
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                }
                .padding(.vertical, 4)
            } header: {
                Text("状态")
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("BeeBrew")
    }
}

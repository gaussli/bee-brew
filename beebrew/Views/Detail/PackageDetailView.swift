import SwiftUI

// MARK: - 详情面板（新增，FR-013）
/// 右侧 300px 详情栏，展示当前选中包完整信息与操作。
struct PackageDetailView: View {
    @EnvironmentObject private var packageViewModel: PackageViewModel
    @Environment(\.themeManager) private var themeManager

    @State private var showUpgradeConfirm: Bool = false

    var body: some View {
        Group {
            if let package = packageViewModel.packageDetail ?? packageViewModel.selectedPackage {
                detailContent(package)
            } else {
                placeholder
            }
        }
        .navigationTitle("详情")
        .alert("确认升级", isPresented: $showUpgradeConfirm) {
            Button("升级", role: .destructive) {
                if let p = packageViewModel.packageDetail ?? packageViewModel.selectedPackage {
                    Task { await packageViewModel.upgrade(p) }
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            if let p = packageViewModel.packageDetail ?? packageViewModel.selectedPackage {
                Text("将 \(p.name) 从 \(p.installedVersion ?? "未知") 升级到 \(p.currentVersion ?? "最新版本")。是否继续？")
            }
        }
    }

    // MARK: - 详情内容
    private func detailContent(_ package: BrewPackage) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 头部
                HStack(spacing: 10) {
                    Image(systemName: package.iconName)
                        .font(.title2)
                        .foregroundColor(package.type.color)
                        .frame(width: 44, height: 44)
                        .background(package.type.color.opacity(0.12))
                        .cornerRadius(10)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(package.name)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.textPrimary)
                        Text(package.type.displayName)
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    Spacer()
                }

                // 描述
                if let desc = package.desc, !desc.isEmpty {
                    Text(desc)
                        .font(.subheadline)
                        .foregroundColor(AppColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Divider()

                // 基本信息
                VStack(alignment: .leading, spacing: 10) {
                    DetailRow(label: "版本", value: package.displayVersion)
                    if package.outdated, let target = package.currentVersion {
                        DetailRow(label: "可升级至", value: target, valueColor: AppColors.warning)
                    }
                    if package.installedVersions.count > 1 {
                        DetailRow(label: "已安装版本", value: package.installedVersions.joined(separator: ", "))
                    }
                    if let license = package.license {
                        DetailRow(label: "许可证", value: license)
                    }
                    if let installedTime = package.installedTime {
                        DetailRow(label: "安装时间", value: installedTime.formatted(date: .abbreviated, time: .shortened))
                    }
                    if package.isFormula {
                        DetailRow(label: "安装方式", value: package.installedAsDependency ? "作为依赖" : "主动安装")
                    }
                }

                // 依赖（FR-013：Formula 展示依赖）
                if package.isFormula && !package.dependencies.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("依赖")
                            .font(.headline)
                            .foregroundColor(AppColors.textPrimary)
                        FlowLayout(spacing: 6) {
                            ForEach(package.dependencies, id: \.self) { dependency in
                                Text(dependency)
                                    .font(.caption2)
                                    .foregroundColor(AppColors.textSecondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(AppColors.backgroundTertiary)
                                    .cornerRadius(5)
                            }
                        }
                    }
                }

                // 注意事项
                if let caveats = package.caveats, !caveats.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("注意事项")
                            .font(.headline)
                            .foregroundColor(AppColors.textPrimary)
                        Text(caveats)
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary)
                            .textSelection(.enabled)
                    }
                }

                // 主页链接
                if let homepage = package.homepage, let url = URL(string: homepage) {
                    Link(destination: url) {
                        Label("打开主页", systemImage: "safari")
                    }
                    .font(.subheadline)
                }

                Divider()

                // 操作按钮
                actionButtons(package)
            }
            .padding(16)
        }
        .background(themeManager.cardBackgroundColor)
    }

    // MARK: - 操作按钮
    @ViewBuilder
    private func actionButtons(_ package: BrewPackage) -> some View {
        let operation = packageViewModel.getPackageOperationState(package)
        HStack(spacing: 10) {
            if operation.isProcessing {
                ProgressView()
                    .frame(maxWidth: .infinity)
            } else {
                switch package.status {
                case .notInstalled:
                    Button {
                        Task { await packageViewModel.install(package) }
                    } label: {
                        Label("安装", systemImage: "arrow.down.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(AppStyles.primaryButtonStyle)

                case .installed:
                    Button {
                        Task { await packageViewModel.uninstall(package) }
                    } label: {
                        Label("卸载", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SecondaryButtonStyle(color: AppColors.error))

                case .outdated:
                    Button {
                        showUpgradeConfirm = true
                    } label: {
                        Label("升级", systemImage: "arrow.up.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(AppStyles.primaryButtonStyle)
                }
            }
        }
    }

    // MARK: - 占位
    private var placeholder: some View {
        VStack(spacing: 12) {
            Image(systemName: "info.circle")
                .font(.system(size: 44))
                .foregroundColor(AppColors.textTertiary)
            Text("未选中任何包")
                .font(.headline)
                .foregroundColor(AppColors.textSecondary)
            Text("从列表中选择一个包查看详情")
                .font(.caption)
                .foregroundColor(AppColors.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - 详情行
private struct DetailRow: View {
    let label: String
    let value: String
    var valueColor: Color = AppColors.textPrimary

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .font(.caption)
                .foregroundColor(AppColors.textTertiary)
                .frame(width: 72, alignment: .leading)
            Text(value)
                .font(.caption)
                .foregroundColor(valueColor)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - 流式布局（依赖标签）
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        var height: CGFloat = 0
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth + size.width + spacing > width, rowWidth > 0 {
                height += rowHeight + spacing
                rowWidth = size.width
                rowHeight = size.height
            } else {
                rowWidth += size.width + spacing
                rowHeight = max(rowHeight, size.height)
            }
        }
        height += rowHeight
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

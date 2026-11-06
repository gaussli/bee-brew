import SwiftUI

// MARK: - 升级确认弹框状态（单一 alert + 枚举，避免同视图链式多 alert）
private enum UpgradeConfirmation: Identifiable {
    case single(BrewPackage)
    case bulk(count: Int)

    var id: String {
        switch self {
        case .single(let package): return "single-\(package.id)"
        case .bulk: return "bulk"
        }
    }
}

// MARK: - 更新 / 系统维护视图（新增，替换原占位）
/// outdated 列表 + 单个/全部升级 + 更新 Homebrew + 清理预览（FR-010/011/015/016）。
struct UpdatesView: View {
    @EnvironmentObject private var packageViewModel: PackageViewModel
    @Environment(\.themeManager) private var themeManager

    @State private var showCleanupPreview: Bool = false
    @State private var upgradeConfirmation: UpgradeConfirmation?

    private var selectedOutdated: [BrewPackage] {
        packageViewModel.outdatedPackages.filter { packageViewModel.selectedPackages.contains($0.id) }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            if packageViewModel.outdatedPackages.isEmpty {
                upToDateView
            } else {
                outdatedList
            }

            if !packageViewModel.runningOperations.isEmpty {
                Divider()
                OperationProgressPanel()
            }

            if !packageViewModel.selectedPackages.isEmpty {
                Divider()
                bulkBar
            }
        }
        .navigationTitle("更新")
        .onAppear {
            Task { await packageViewModel.checkForUpdates() }
        }
        .sheet(isPresented: $showCleanupPreview) {
            CleanupPreviewSheet()
        }
        .alert(item: $upgradeConfirmation) { confirmation in
            switch confirmation {
            case .single(let package):
                return Alert(
                    title: Text("确认升级"),
                    message: Text("将 \(package.name) 从 \(package.installedVersion ?? "未知") 升级到 \(package.currentVersion ?? "最新版本")。是否继续？"),
                    primaryButton: .destructive(Text("升级")) {
                        Task { await packageViewModel.upgrade(package) }
                    },
                    secondaryButton: .cancel(Text("取消"))
                )
            case .bulk(let count):
                return Alert(
                    title: Text("确认批量升级"),
                    message: Text("将升级 \(count) 个包。是否继续？"),
                    primaryButton: .destructive(Text("升级")) {
                        Task { await packageViewModel.bulkUpgrade(selectedOutdated) }
                    },
                    secondaryButton: .cancel(Text("取消"))
                )
            }
        }
    }

    // MARK: - 头部
    private var header: some View {
        HStack(spacing: 12) {
            Button {
                Task { await packageViewModel.updateHomebrew() }
            } label: {
                Label("更新 Homebrew", systemImage: "arrow.triangle.2.circlepath")
            }
            .disabled(packageViewModel.runningOperations.contains("system:update"))

            Button {
                showCleanupPreview = true
            } label: {
                Label("清理旧版本", systemImage: "trash")
            }

            Spacer()

            if packageViewModel.isCheckingUpdates {
                ProgressView().controlSize(.small)
            }

            Button {
                Task { await packageViewModel.checkForUpdates() }
            } label: {
                Label("重新检查", systemImage: "arrow.clockwise")
            }
            .disabled(packageViewModel.isCheckingUpdates)

            Text("可升级 \(packageViewModel.outdatedPackages.count)")
                .font(.caption)
                .foregroundColor(AppColors.textTertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - 可升级列表（FR-010：当前版本 → 目标版本）
    private var outdatedList: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                ForEach(packageViewModel.outdatedPackages) { package in
                    HStack(spacing: 10) {
                        Button {
                            packageViewModel.toggleSelection(for: package)
                        } label: {
                            Image(systemName: packageViewModel.selectedPackages.contains(package.id)
                                  ? "checkmark.square.fill" : "square")
                                .font(.system(size: 15))
                                .foregroundColor(packageViewModel.selectedPackages.contains(package.id)
                                                 ? AppColors.primary : AppColors.textTertiary)
                        }
                        .buttonStyle(.plain)
                        .frame(width: 24)

                        Image(systemName: package.iconName)
                            .font(.system(size: 15))
                            .foregroundColor(package.type.color)
                            .frame(width: 28, height: 28)
                            .background(package.type.color.opacity(0.12))
                            .cornerRadius(6)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(package.name)
                                .font(.body)
                                .foregroundColor(AppColors.textPrimary)
                            Text(versionTransition(package))
                                .font(.caption)
                                .foregroundColor(AppColors.textSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        Button("升级") {
                            upgradeConfirmation = .single(package)
                        }
                        .buttonStyle(SecondaryButtonStyle(color: AppColors.warning))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        Task { await packageViewModel.loadPackageDetail(package) }
                    }
                    Divider().opacity(0.4)
                }
            }
            .padding(.vertical, 8)
        }
    }

    private func versionTransition(_ package: BrewPackage) -> String {
        let current = package.installedVersion ?? "未知"
        let target = package.currentVersion ?? "最新"
        return "\(current) → \(target)"
    }

    // MARK: - 批量栏（FR-011/012）
    private var bulkBar: some View {
        HStack(spacing: 12) {
            Text("已选 \(packageViewModel.selectedPackages.count) 项")
                .font(.subheadline)
                .foregroundColor(AppColors.textSecondary)
            Spacer()
            Button {
                upgradeConfirmation = .bulk(count: selectedOutdated.count)
            } label: {
                Label("升级选中", systemImage: "arrow.up.circle")
            }
            .buttonStyle(AppStyles.primaryButtonStyle)
            .disabled(selectedOutdated.isEmpty)

            Button("取消") {
                packageViewModel.deselectAll()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - 全部最新状态
    private var upToDateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundColor(AppColors.success)
            Text("所有包均为最新")
                .font(.title3)
                .foregroundColor(AppColors.textPrimary)
            Text("Homebrew \(packageViewModel.environment.version)")
                .foregroundColor(AppColors.textSecondary)
            if let error = packageViewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(AppColors.error)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - 操作进度面板（FR-014）
struct OperationProgressPanel: View {
    @EnvironmentObject private var packageViewModel: PackageViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                ProgressView()
                    .controlSize(.small)
                Text("正在执行操作...")
                    .font(.subheadline)
                    .foregroundColor(AppColors.textPrimary)
                Spacer()
                Button("取消") {
                    packageViewModel.cancelOperations()
                }
                .font(.caption)
            }

            if let last = packageViewModel.operationLog.last {
                Text(last.text)
                    .font(.caption)
                    .foregroundColor(last.stream == .stderr ? AppColors.warning : AppColors.textSecondary)
                    .lineLimit(2)
                    .textSelection(.enabled)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

// MARK: - 清理预览（FR-016）
struct CleanupPreviewSheet: View {
    @EnvironmentObject private var packageViewModel: PackageViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var isLoadingCleanup: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 标题栏
            HStack(spacing: 8) {
                Image(systemName: "trash")
                    .foregroundColor(AppColors.warning)
                Text("清理旧版本")
                    .font(.title3)
                    .fontWeight(.semibold)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 12)

            // 说明
            Text("以下为 brew cleanup 将删除的旧版本缓存（通过 --dry-run 预览）")
                .font(.caption)
                .foregroundColor(AppColors.textSecondary)
                .padding(.horizontal, 20)
                .padding(.bottom, 12)

            Divider()

            // 内容区
            if isLoadingCleanup {
                loadingView
            } else if let message = packageViewModel.errorMessage {
                errorView(message)
            } else if packageViewModel.cleanupPreview.isEmpty {
                emptyView
            } else {
                cleanupTable
            }

            Divider()

            // 底部统计 + 按钮
            HStack {
                Text("共 \(packageViewModel.cleanupPreview.count) 项待清理")
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
                Spacer()
                Button("取消") { dismiss() }
                    .buttonStyle(SecondaryButtonStyle())
                Button("重新加载") {
                    Task { await loadPreview() }
                }
                .buttonStyle(SecondaryButtonStyle())
                .disabled(isLoadingCleanup)
                Button("执行清理") {
                    Task {
                        await packageViewModel.cleanup()
                        dismiss()
                    }
                }
                .buttonStyle(AppStyles.primaryButtonStyle)
                .disabled(isLoadingCleanup || packageViewModel.cleanupPreview.isEmpty)
            }
            .padding(16)
        }
        .frame(width: 560, height: 400)
        .onAppear {
            Task { await loadPreview() }
        }
    }

    // MARK: - 加载 / 空态
    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("正在分析可清理的旧版本...")
                .font(.caption)
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 40))
                .foregroundColor(AppColors.textTertiary)
            Text("没有可清理的旧版本")
                .font(.headline)
                .foregroundColor(AppColors.textPrimary)
            Text("系统已是最新，无需清理")
                .font(.caption)
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundColor(AppColors.warning)
            Text("清理预览失败")
                .font(.headline)
                .foregroundColor(AppColors.textPrimary)
            Text(message)
                .font(.caption)
                .foregroundColor(AppColors.error)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 重新加载
    private func loadPreview() async {
        isLoadingCleanup = true
        _ = await packageViewModel.cleanupDryRun()
        isLoadingCleanup = false
    }

    // MARK: - 对齐的清理项表格
    private var cleanupTable: some View {
        ScrollView {
            VStack(spacing: 0) {
                // 表头
                HStack(spacing: 12) {
                    Text("路径")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("类型")
                        .frame(width: 60, alignment: .leading)
                    Text("")
                        .frame(width: 80)
                }
                .font(.caption2)
                .foregroundColor(AppColors.textTertiary)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)

                Divider()

                // 行
                ForEach(packageViewModel.cleanupPreview) { item in
                    CleanupRow(item: item)
                    Divider().opacity(0.3)
                }
            }
        }
    }
}

// MARK: - 清理项行（对齐布局）
private struct CleanupRow: View {
    let item: CleanupItem

    var body: some View {
        HStack(spacing: 12) {
            Text(item.path)
                .font(.caption)
                .foregroundColor(AppColors.textPrimary)
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("旧版本")
                .font(.caption2)
                .foregroundColor(AppColors.textSecondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(AppColors.backgroundTertiary)
                .cornerRadius(4)
                .frame(width: 60, alignment: .leading)

            Image(systemName: "trash")
                .font(.caption)
                .foregroundColor(AppColors.warning)
                .frame(width: 80, alignment: .center)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 6)
    }
}

import SwiftUI

// MARK: - 更新 / 系统维护视图（新增，替换原占位）
/// outdated 列表 + 单个/全部升级 + 更新 Homebrew + 清理预览（FR-010/011/015/016）。
struct UpdatesView: View {
    @EnvironmentObject private var packageViewModel: PackageViewModel
    @Environment(\.themeManager) private var themeManager

    @State private var showCleanupPreview: Bool = false

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

            if packageViewModel.isLoading {
                ProgressView().controlSize(.small)
            }

            Button {
                Task { await packageViewModel.checkForUpdates() }
            } label: {
                Label("重新检查", systemImage: "arrow.clockwise")
            }

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

                        Image(systemName: package.type.iconName)
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
                            Task { await packageViewModel.upgrade(package) }
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
                Task { await packageViewModel.bulkUpgrade(selectedOutdated) }
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

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("清理预览")
                .font(.title2)
                .fontWeight(.semibold)

            if packageViewModel.cleanupPreview.isEmpty {
                Text("点击「重新加载」执行 brew cleanup --dry-run 预览可释放的旧版本缓存")
                    .foregroundColor(AppColors.textSecondary)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(packageViewModel.cleanupPreview) { item in
                            Text(item.path)
                                .font(.caption)
                                .foregroundColor(AppColors.textSecondary)
                                .textSelection(.enabled)
                                .lineLimit(1)
                        }
                    }
                }
                Text("共 \(packageViewModel.cleanupPreview.count) 项")
                    .font(.caption)
                    .foregroundColor(AppColors.textTertiary)
            }

            HStack {
                Spacer()
                Button("取消") { dismiss() }
                Button("重新加载") {
                    Task { _ = await packageViewModel.cleanupDryRun() }
                }
                Button("执行清理") {
                    Task {
                        await packageViewModel.cleanup()
                        dismiss()
                    }
                }
                .buttonStyle(AppStyles.primaryButtonStyle)
            }
        }
        .padding(20)
        .frame(width: 480, height: 360)
        .onAppear {
            Task { _ = await packageViewModel.cleanupDryRun() }
        }
    }
}

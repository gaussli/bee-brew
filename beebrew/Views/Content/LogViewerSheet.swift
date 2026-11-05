import SwiftUI

// MARK: - 操作日志查看器（菜单入口）
/// 展示 PackageViewModel 转发自 BrewService 的完整操作日志（FR-024 预留），支持清空。
struct LogViewerSheet: View {
    @EnvironmentObject private var packageViewModel: PackageViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 标题栏
            HStack(spacing: 8) {
                Image(systemName: "doc.text.magnifyingglass")
                    .foregroundColor(AppColors.primary)
                Text("操作日志")
                    .font(.title3)
                    .fontWeight(.semibold)
                Spacer()
                Button("清空") {
                    packageViewModel.clearOperationLog()
                }
                .disabled(packageViewModel.operationLog.isEmpty)
                Button("关闭") { dismiss() }
            }
            .padding(16)

            Divider()

            // 日志内容
            if packageViewModel.operationLog.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "tray")
                        .font(.system(size: 40))
                        .foregroundColor(AppColors.textTertiary)
                    Text("暂无操作日志")
                        .font(.headline)
                        .foregroundColor(AppColors.textPrimary)
                    Text("执行安装 / 卸载 / 升级等操作后，这里会显示 brew 的完整输出")
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        ForEach(packageViewModel.operationLog) { entry in
                            logEntry(entry)
                        }
                    }
                    .padding(16)
                }
            }
        }
        .frame(width: 680, height: 480)
    }

    // MARK: - 单条日志
    private func logEntry(_ entry: OperationLogEntry) -> some View {
        HStack(alignment: .top, spacing: 8) {
            // 时间戳
            Text(entry.timestamp, style: .time)
                .font(.caption2)
                .foregroundColor(AppColors.textTertiary)
                .frame(width: 56, alignment: .trailing)

            // 流方向标记
            Image(systemName: entry.stream == .stderr ? "exclamationmark.triangle.fill" : "terminal")
                .font(.caption2)
                .foregroundColor(entry.stream == .stderr ? AppColors.warning : AppColors.textSecondary)
                .frame(width: 16)

            // 内容
            Text(entry.text)
                .font(.caption)
                .foregroundColor(entry.stream == .stderr ? AppColors.warning : AppColors.textPrimary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

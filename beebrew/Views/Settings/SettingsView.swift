import SwiftUI
import AppKit

// MARK: - 设置视图（改造后，对齐 FR-017/018）
/// 外观主题（跟随系统/浅色/深色）+ Homebrew 路径配置 + 关于。
struct SettingsView: View {
    @EnvironmentObject private var settingsViewModel: SettingsViewModel
    @Environment(\.themeManager) private var themeManager

    var body: some View {
        Form {
            Section("外观主题") {
                Picker("主题", selection: $settingsViewModel.theme) {
                    ForEach(AppTheme.allCases, id: \.self) { theme in
                        Text(theme.rawValue).tag(theme)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: settingsViewModel.theme) { _, newValue in
                    themeManager.switchTheme(to: newValue)
                    settingsViewModel.saveSettings()
                }

                Toggle("跟随系统外观", isOn: $settingsViewModel.useSystemAppearance)
                    .onChange(of: settingsViewModel.useSystemAppearance) { _, newValue in
                        themeManager.useSystemAppearance = newValue
                        settingsViewModel.saveSettings()
                    }
            }

            Section("Homebrew 路径") {
                Toggle("使用自定义路径", isOn: $settingsViewModel.useCustomPath)
                    .onChange(of: settingsViewModel.useCustomPath) { _, _ in
                        settingsViewModel.applyBrewPath()
                        settingsViewModel.saveSettings()
                    }

                if settingsViewModel.useCustomPath {
                    HStack {
                        TextField("Homebrew 路径（bin/brew）", text: $settingsViewModel.customBrewPath)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit {
                                settingsViewModel.applyBrewPath()
                                settingsViewModel.saveSettings()
                            }
                        Button("浏览...") { browseBrewDirectory() }
                    }
                } else {
                    Text(settingsViewModel.effectiveBrewPath)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(AppColors.textSecondary)
                        .textSelection(.enabled)
                }

                HStack {
                    Button("自动检测路径") { settingsViewModel.detectBrewPath() }
                        .disabled(settingsViewModel.isLoading)
                    if settingsViewModel.isLoading {
                        ProgressView().controlSize(.small)
                    }
                }

                if settingsViewModel.validateBrewPath() {
                    Label("Homebrew 路径有效", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(AppColors.success)
                } else {
                    Label("Homebrew 路径无效或不存在", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundColor(AppColors.warning)
                }

                if let message = settingsViewModel.errorMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundColor(AppColors.error)
                }
                if let message = settingsViewModel.successMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundColor(AppColors.success)
                }
            }

            Section("关于") {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "hexagon.fill")
                        .font(.system(size: 44))
                        .foregroundColor(AppColors.primary)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("BeeBrew")
                            .font(.headline)
                        Text("版本 1.0.0")
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary)
                        Text("macOS 原生 Homebrew GUI 客户端")
                            .font(.caption)
                            .foregroundColor(AppColors.textTertiary)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("设置")
    }

    // MARK: - 浏览目录（FR-017：仅允许选择已存在目录）
    private func browseBrewDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "选择"
        if panel.runModal() == .OK, let url = panel.url {
            settingsViewModel.customBrewPath = url.appendingPathComponent("bin/brew").path
            settingsViewModel.applyBrewPath()
            settingsViewModel.saveSettings()
        }
    }
}

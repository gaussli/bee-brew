import SwiftUI

// MARK: - 根视图 / 三栏容器（改造后，G4）
/// 使用 macOS 14 `NavigationSplitView` 实现三栏：左导航 / 中列表 / 右详情（SRS 6.1）。
struct ContentView: View {
    @EnvironmentObject private var packageViewModel: PackageViewModel
    @Environment(\.themeManager) private var themeManager

    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var showLogViewer: Bool = false

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 160, ideal: 180, max: 240)
        } content: {
            contentView
                .navigationSplitViewColumnWidth(min: 340, ideal: 480)
        } detail: {
            detailView
                .navigationSplitViewColumnWidth(min: 260, ideal: 300)
        }
        .frame(minWidth: 900, minHeight: 600)
        .sheet(isPresented: $showLogViewer) {
            LogViewerSheet()
        }
        .onReceive(NotificationCenter.default.publisher(for: .logViewerRequested)) { _ in
            showLogViewer = true
        }
    }

    // MARK: - 中间内容列
    @ViewBuilder
    private var contentView: some View {
        switch packageViewModel.currentTab {
        case .installed:
            InstalledView()
        case .updates:
            UpdatesView()
        case .search:
            SearchView()
        case .settings:
            SettingsView()
        }
    }

    // MARK: - 右侧详情列（设置页隐藏，DDD Q3）
    @ViewBuilder
    private var detailView: some View {
        if packageViewModel.currentTab == .settings {
            EmptyView()
        } else {
            PackageDetailView()
        }
    }
}

import Foundation
import SwiftUI
import Combine

// MARK: - 侧边栏导航项（SRS 6.2：已安装/更新/搜索/设置）
enum AppTab: String, CaseIterable, Identifiable, Hashable {
    case installed = "已安装"
    case updates = "更新"
    case search = "搜索"
    case settings = "设置"

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .installed: return "checklist"
        case .updates: return "arrow.clockwise"
        case .search: return "magnifyingglass"
        case .settings: return "gearshape"
        }
    }

    var color: Color {
        switch self {
        case .installed: return AppColors.success
        case .updates: return AppColors.warning
        case .search: return AppColors.primary
        case .settings: return AppColors.secondary
        }
    }
}

// MARK: - 包视图模型（改造后）
/// 管理包相关的 UI 状态与逻辑；真实加载 brew 数据（G2 改造）。
@MainActor
final class PackageViewModel: ObservableObject {

    private let brewService = BrewService()
    private var cancellables = Set<AnyCancellable>()
    private var searchTask: Task<Void, Never>?

    // MARK: - 发布的状态
    @Published var searchQuery: String = ""
    @Published var installedPackages: [BrewPackage] = []
    @Published var outdatedPackages: [BrewPackage] = []
    @Published var searchResults: [BrewPackage] = []
    @Published var selectedPackages: Set<String> = []       // FR-012（键 = package.id）
    @Published var selectedPackage: BrewPackage?             // FR-013 详情选中
    @Published var packageDetail: BrewPackage?               // FR-013 详情数据
    @Published var currentTab: AppTab = .installed
    @Published var filter = PackageFilter()                  // FR-019/020 预留
    @Published var isLoading: Bool = false
    @Published var isSearching: Bool = false
    @Published var isCheckingUpdates: Bool = false
    @Published var errorMessage: String?
    @Published var packageOperations: [String: PackageOperationState] = [:]
    @Published var environment: BrewEnvironment = BrewEnvironment()
    @Published var cleanupPreview: [CleanupItem] = []

    // 转发服务层进度日志（FR-014）
    @Published var operationLog: [OperationLogEntry] = []
    @Published var runningOperations: Set<String> = []

    // MARK: - 初始化（G2：真实异步加载）
    init() {
        setupSearchDebounce()
        setupServiceBindings()
        Task { await loadInitialData() }
    }

    // MARK: - 订阅
    private func setupSearchDebounce() {
        $searchQuery
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] query in
                guard let self else { return }
                self.searchTask?.cancel()
                self.searchTask = Task { await self.performSearch(query: query) }
            }
            .store(in: &cancellables)
    }

    private func setupServiceBindings() {
        brewService.$operationLog
            .sink { [weak self] log in self?.operationLog = log }
            .store(in: &cancellables)

        brewService.$runningOperations
            .sink { [weak self] ops in self?.runningOperations = ops }
            .store(in: &cancellables)
    }

    // MARK: - 数据加载
    func loadInitialData() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        environment = await brewService.detectEnvironment()

        // 并发读取已安装 + 可更新（NFR-001）
        async let installed: Void = loadInstalledPackages()
        async let outdated: Void = checkForUpdates()
        _ = await (installed, outdated)
    }

    func loadInstalledPackages() async {
        do {
            installedPackages = try await brewService.listInstalled()
        } catch {
            errorMessage = errorText(error)
        }
    }

    func checkForUpdates() async {
        isCheckingUpdates = true
        defer { isCheckingUpdates = false }
        do {
            outdatedPackages = try await brewService.listOutdated()
        } catch {
            // 可更新检测失败不应阻塞主流程，仅提示
            if errorMessage == nil {
                errorMessage = errorText(error)
            }
        }
    }

    func refresh() async {
        await loadInitialData()
    }

    // MARK: - 搜索（FR-005，300ms 防抖由 setupSearchDebounce 处理）
    func performSearch(query: String) async {
        guard !query.isEmpty else {
            searchResults = []
            isSearching = false
            return
        }

        isSearching = true
        defer { isSearching = false }

        do {
            var results = try await brewService.search(query: query)
            // 标记已安装（FR-005 验收：结果正确标记「已安装」状态）
            let installedIDs = Set(installedPackages.map { $0.id })
            for index in results.indices where installedIDs.contains(results[index].id) {
                results[index] = results[index].withInstalled(true)
            }
            searchResults = results
        } catch {
            searchResults = []
            errorMessage = errorText(error)
        }
    }

    // MARK: - 详情（FR-013）
    func loadPackageDetail(_ package: BrewPackage) async {
        selectedPackage = package
        packageDetail = package   // 先展示列表已有字段，避免空窗
        do {
            let detail = try await brewService.getPackageInfo(package)
            packageDetail = detail
            selectedPackage = detail
        } catch {
            errorMessage = errorText(error)
        }
    }

    func clearSelectedPackage() {
        selectedPackage = nil
        packageDetail = nil
    }

    // MARK: - 单包操作（FR-006~011）
    func install(_ package: BrewPackage) async {
        let success = await performOperation(package, state: .installing) {
            try await self.brewService.install(package)
        }
        if success {
            await loadInstalledPackages()
            await checkForUpdates()
        }
    }

    func uninstall(_ package: BrewPackage) async {
        let success = await performOperation(package, state: .uninstalling) {
            try await self.brewService.uninstall(package)
        }
        if success {
            await loadInstalledPackages()
            await checkForUpdates()
        }
    }

    func upgrade(_ package: BrewPackage) async {
        let success = await performOperation(package, state: .updating) {
            try await self.brewService.upgrade(package)
        }
        if success {
            await loadInstalledPackages()
            await checkForUpdates()
        }
    }

    func upgradeAll() async {
        let operationID = "system:upgrade-all"
        let success = await performSystemOperation(operationID) {
            try await self.brewService.upgradeAll()
        }
        if success {
            await loadInstalledPackages()
            await checkForUpdates()
        }
    }

    // MARK: - 批量操作（FR-012，串行执行）
    func bulkUninstall(_ packages: [BrewPackage]) async {
        for package in packages {
            await uninstall(package)
        }
        selectedPackages.removeAll()
    }

    func bulkUpgrade(_ packages: [BrewPackage]) async {
        for package in packages {
            await upgrade(package)
        }
        selectedPackages.removeAll()
    }

    // MARK: - 系统维护（FR-015/016）
    func updateHomebrew() async {
        let success = await performSystemOperation("system:update") {
            try await self.brewService.updateHomebrew()
        }
        if success {
            environment = await brewService.detectEnvironment()
            await checkForUpdates()
        }
    }

    func cleanupDryRun() async -> [CleanupItem] {
        errorMessage = nil
        do {
            cleanupPreview = try await brewService.cleanupDryRun()
        } catch {
            cleanupPreview = []
            errorMessage = errorText(error)
        }
        return cleanupPreview
    }

    func cleanup() async {
        let success = await performSystemOperation("system:cleanup") {
            try await self.brewService.cleanup()
        }
        if success {
            cleanupPreview = []
            await loadInstalledPackages()
        }
    }

    func cancelOperations() {
        brewService.cancelAll()
    }

    /// 清空操作日志（日志查看器入口使用）
    func clearOperationLog() {
        brewService.clearOperationLog()
    }

    // MARK: - 选中状态
    func toggleSelection(for package: BrewPackage) {
        if selectedPackages.contains(package.id) {
            selectedPackages.remove(package.id)
        } else {
            selectedPackages.insert(package.id)
        }
    }

    func selectAll(in packages: [BrewPackage]) {
        selectedPackages = Set(packages.map { $0.id })
    }

    func deselectAll() {
        selectedPackages.removeAll()
    }

    // MARK: - 实用方法
    func getPackageOperationState(_ package: BrewPackage) -> PackageOperationState {
        packageOperations[package.id] ?? .idle
    }

    func isPackageBeingOperatedOn(_ package: BrewPackage) -> Bool {
        getPackageOperationState(package).isProcessing
    }

    func filtered(_ packages: [BrewPackage]) -> [BrewPackage] {
        filter.apply(to: packages)
    }

    func clearError() {
        errorMessage = nil
    }

    // MARK: - 私有实现
    private func performOperation(
        _ package: BrewPackage,
        state: PackageOperationState,
        action: () async throws -> Void
    ) async -> Bool {
        guard packageOperations[package.id] == nil else { return false }
        packageOperations[package.id] = state
        errorMessage = nil
        scheduleOperationCleanup(for: package.id)

        do {
            try await action()
            packageOperations[package.id] = .success
            return true
        } catch {
            let message = errorText(error)
            packageOperations[package.id] = .failed(message)
            errorMessage = message
            return false
        }
    }

    private func performSystemOperation(
        _ id: String,
        action: () async throws -> Void
    ) async -> Bool {
        guard packageOperations[id] == nil else { return false }
        packageOperations[id] = .updating
        errorMessage = nil
        scheduleOperationCleanup(for: id)

        do {
            try await action()
            packageOperations[id] = .success
            return true
        } catch {
            let message = errorText(error)
            packageOperations[id] = .failed(message)
            errorMessage = message
            return false
        }
    }

    private func scheduleOperationCleanup(for id: String) {
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            self?.packageOperations.removeValue(forKey: id)
        }
    }

    private func errorText(_ error: Error) -> String {
        (error as? BrewError)?.errorDescription ?? error.localizedDescription
    }
}

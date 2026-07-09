import AppKit
import Foundation

private enum MenuLayout {
    static let popoverWidth: CGFloat = 390
    static let contentWidth: CGFloat = 354
    static let contentInset: CGFloat = 18
    static let verticalSpacing: CGFloat = 12
    static let maxVisibleHeight: CGFloat = 520
    static let minVisibleHeight: CGFloat = 300
}

struct DashboardPayload: Decodable {
    let generatedAt: String
    let activeProfile: String?
    let runtimeStatus: RuntimeStatus?
    let desktopStatus: DesktopStatus?
    let localSnapshot: LocalTokenSnapshot?
    let attributionSummary: AttributionSummary?
    let projectRankings: ProjectRankings?
    let toolRankings: ToolRankings?
    let skillRankings: SkillRankings?
    let profiles: [ProfileStatus]

    enum CodingKeys: String, CodingKey {
        case generatedAt = "generated_at"
        case activeProfile = "active_profile"
        case runtimeStatus = "runtime_status"
        case desktopStatus = "desktop_status"
        case localSnapshot = "local_snapshot"
        case attributionSummary = "attribution_summary"
        case projectRankings = "project_rankings"
        case toolRankings = "tool_rankings"
        case skillRankings = "skill_rankings"
        case profiles
    }
}

struct AttributionSummary: Decodable {
    let activeProfile: String?
    let managed: Bool?

    enum CodingKeys: String, CodingKey {
        case activeProfile = "active_profile"
        case managed
    }
}

struct DesktopStatus: Decodable {
    let running: Bool
    let managed: Bool
    let state: String
    let message: String
    let codexPid: Int?
    let recordedPid: Int?
    let activeProfile: String?

    enum CodingKeys: String, CodingKey {
        case running
        case managed
        case state
        case message
        case codexPid = "codex_pid"
        case recordedPid = "recorded_pid"
        case activeProfile = "active_profile"
    }
}

struct RuntimeStatus: Decodable {
    let state: String
    let light: String
    let label: String
    let activeProcessCount: Int
    let recentProcessCount: Int
    let latestActivityAgeMs: Int?

    enum CodingKeys: String, CodingKey {
        case state
        case light
        case label
        case activeProcessCount = "active_process_count"
        case recentProcessCount = "recent_process_count"
        case latestActivityAgeMs = "latest_activity_age_ms"
    }
}

struct ProfileStatus: Decodable {
    let name: String
    let auth: String
    let config: String
    let rateLimits: RateLimits
    let resetCreditDetails: ResetCreditDetails?
    let resetCreditStale: Bool?
    let resetCreditError: String?
    let usage: AccountUsage?
    let usageMetrics: AccountUsageMetrics?
    let tokenAttribution: TokenAttribution?
    let remoteStale: Bool?
    let remoteError: String?

    enum CodingKeys: String, CodingKey {
        case name
        case auth
        case config
        case rateLimits = "rate_limits"
        case resetCreditDetails = "reset_credit_details"
        case resetCreditStale = "reset_credit_stale"
        case resetCreditError = "reset_credit_error"
        case usage
        case usageMetrics = "usage_metrics"
        case tokenAttribution = "token_attribution"
        case remoteStale = "remote_stale"
        case remoteError = "remote_error"
    }
}

struct RateLimits: Decodable {
    let available: Bool
    let limitID: String?
    let planType: String?
    let creditsAvailable: Int?
    let resetCredits: ResetCredits?
    let primary: RateLimitWindow?
    let secondary: RateLimitWindow?

    enum CodingKeys: String, CodingKey {
        case available
        case limitID = "limit_id"
        case planType = "plan_type"
        case creditsAvailable = "credits_available"
        case resetCredits = "reset_credits"
        case primary
        case secondary
    }
}

struct ResetCredits: Decodable {
    let available: Bool?
    let availableCount: Int?
    let hasCredits: Bool?
    let unlimited: Bool?
    let expiresAt: TimeInterval?

    enum CodingKeys: String, CodingKey {
        case available
        case availableCount = "available_count"
        case hasCredits = "has_credits"
        case unlimited
        case expiresAt = "expires_at"
    }
}

struct ResetCreditDetails: Decodable {
    let available: Bool?
    let availableCount: Int?
    let totalEarnedCount: Int?
    let credits: [ResetCreditCard]
    let earliestExpiresAt: TimeInterval?

    enum CodingKeys: String, CodingKey {
        case available
        case availableCount = "available_count"
        case totalEarnedCount = "total_earned_count"
        case credits
        case earliestExpiresAt = "earliest_expires_at"
    }
}

struct ResetCreditCard: Decodable {
    let id: String?
    let status: String?
    let used: Bool?
    let grantedAt: TimeInterval?
    let expiresAt: TimeInterval?

    enum CodingKeys: String, CodingKey {
        case id
        case status
        case used
        case grantedAt = "granted_at"
        case expiresAt = "expires_at"
    }
}

struct RateLimitWindow: Decodable {
    let remainingPercent: Int?
    let resetsAt: TimeInterval?

    enum CodingKeys: String, CodingKey {
        case remainingPercent = "remaining_percent"
        case resetsAt = "resets_at"
    }
}

struct AccountUsage: Decodable {
    let summary: UsageSummary?
    let dailyUsageBuckets: [DailyUsageBucket]?
}

struct UsageSummary: Decodable {
    let lifetimeTokens: Int?
    let peakDailyTokens: Int?
    let currentStreakDays: Int?
    let longestStreakDays: Int?
}

struct DailyUsageBucket: Decodable {
    let startDate: String
    let tokens: Int
}

struct AccountUsageMetrics: Decodable {
    let todayTokens: Int?
    let todayAvailable: Bool
    let last7Tokens: Int?
    let last14Tokens: Int?
    let latestDate: String?
    let source: String?

    enum CodingKeys: String, CodingKey {
        case todayTokens = "today_tokens"
        case todayAvailable = "today_available"
        case last7Tokens = "last_7_tokens"
        case last14Tokens = "last_14_tokens"
        case latestDate = "latest_date"
        case source
    }
}

struct TokenAttribution: Decodable {
    let activeProfile: String?
    let managed: Bool
    let estimateAvailable: Bool
    let todayEstimatedTokens: Int?
    let todayOfficialTokens: Int?
    let todayDisplayTokens: Int?
    let todaySource: String?
    let previousDayAccuracy: AttributionAccuracy?

    enum CodingKeys: String, CodingKey {
        case activeProfile = "active_profile"
        case managed
        case estimateAvailable = "estimate_available"
        case todayEstimatedTokens = "today_estimated_tokens"
        case todayOfficialTokens = "today_official_tokens"
        case todayDisplayTokens = "today_display_tokens"
        case todaySource = "today_source"
        case previousDayAccuracy = "previous_day_accuracy"
    }
}

struct AttributionAccuracy: Decodable {
    let date: String
    let estimatedTokens: Int
    let officialTokens: Int
    let deltaTokens: Int
    let deltaPercent: Double?

    enum CodingKeys: String, CodingKey {
        case date
        case estimatedTokens = "estimated_tokens"
        case officialTokens = "official_tokens"
        case deltaTokens = "delta_tokens"
        case deltaPercent = "delta_percent"
    }
}

struct ProjectRankings: Decodable {
    let available: Bool
    let projects: [ProjectRankItem]
}

struct ProjectRankItem: Decodable {
    let name: String
    let path: String
    let threadCount: Int
    let tokensUsed: Int
    let latestUpdatedAt: Int

    enum CodingKeys: String, CodingKey {
        case name
        case path
        case threadCount = "thread_count"
        case tokensUsed = "tokens_used"
        case latestUpdatedAt = "latest_updated_at"
    }
}

struct ToolRankings: Decodable {
    let available: Bool
    let tools: [ToolRankItem]
}

struct ToolRankItem: Decodable {
    let id: String
    let namespace: String
    let name: String
    let callCount: Int
    let latestUpdatedAt: Int
    let threadTokens: Int

    enum CodingKeys: String, CodingKey {
        case id
        case namespace
        case name
        case callCount = "call_count"
        case latestUpdatedAt = "latest_updated_at"
        case threadTokens = "thread_tokens"
    }
}

struct SkillRankings: Decodable {
    let available: Bool
    let skills: [SkillRankItem]
    let badLineCount: Int?

    enum CodingKeys: String, CodingKey {
        case available
        case skills
        case badLineCount = "bad_line_count"
    }
}

struct SkillRankItem: Decodable {
    let name: String
    let useCount: Int
    let latestTimestamp: String?

    enum CodingKeys: String, CodingKey {
        case name
        case useCount = "use_count"
        case latestTimestamp = "latest_timestamp"
    }
}

struct LocalTokenSnapshot: Decodable {
    let eventCount: Int
    let latestTimestamp: String?
    let total: TokenUsageTotals
    let daily: [TokenUsageTotalsByDate]?
    let byModel: [TokenUsageTotalsByModel]?

    enum CodingKeys: String, CodingKey {
        case eventCount = "event_count"
        case latestTimestamp = "latest_timestamp"
        case total
        case daily
        case byModel = "by_model"
    }
}

struct TokenUsageTotals: Decodable {
    let inputTokens: Int
    let cachedInputTokens: Int
    let outputTokens: Int
    let reasoningOutputTokens: Int
    let totalTokens: Int

    enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case cachedInputTokens = "cached_input_tokens"
        case outputTokens = "output_tokens"
        case reasoningOutputTokens = "reasoning_output_tokens"
        case totalTokens = "total_tokens"
    }
}

struct TokenUsageTotalsByDate: Decodable {
    let date: String
    let inputTokens: Int
    let cachedInputTokens: Int
    let outputTokens: Int
    let reasoningOutputTokens: Int
    let totalTokens: Int

    enum CodingKeys: String, CodingKey {
        case date
        case inputTokens = "input_tokens"
        case cachedInputTokens = "cached_input_tokens"
        case outputTokens = "output_tokens"
        case reasoningOutputTokens = "reasoning_output_tokens"
        case totalTokens = "total_tokens"
    }
}

struct TokenUsageTotalsByModel: Decodable {
    let model: String
    let inputTokens: Int
    let cachedInputTokens: Int
    let outputTokens: Int
    let reasoningOutputTokens: Int
    let totalTokens: Int

    enum CodingKeys: String, CodingKey {
        case model
        case inputTokens = "input_tokens"
        case cachedInputTokens = "cached_input_tokens"
        case outputTokens = "output_tokens"
        case reasoningOutputTokens = "reasoning_output_tokens"
        case totalTokens = "total_tokens"
    }
}

enum CommandResult {
    case success(String)
    case failure(String)
}

enum AccountHealth {
    case green
    case yellow
    case red
    case unknown

    init(remaining: Int?) {
        guard let remaining else {
            self = .unknown
            return
        }
        if remaining >= 70 {
            self = .green
        } else if remaining >= 35 {
            self = .yellow
        } else {
            self = .red
        }
    }

    var emoji: String {
        switch self {
        case .green:
            return "🟢"
        case .yellow:
            return "🟡"
        case .red:
            return "🔴"
        case .unknown:
            return "⚪️"
        }
    }

    var color: NSColor {
        switch self {
        case .green:
            return NSColor.systemGreen
        case .yellow:
            return NSColor.systemYellow
        case .red:
            return NSColor.systemRed
        case .unknown:
            return NSColor.systemGray
        }
    }

    var label: String {
        switch self {
        case .green:
            return "充足"
        case .yellow:
            return "注意"
        case .red:
            return "紧张"
        case .unknown:
            return "未知"
        }
    }
}

enum RuntimeLight {
    case green
    case yellow
    case red
    case unknown

    init(status: RuntimeStatus?) {
        switch status?.light {
        case "green":
            self = .green
        case "yellow":
            self = .yellow
        case "red":
            self = .red
        default:
            self = .unknown
        }
    }

    var emoji: String {
        switch self {
        case .green:
            return "🟢"
        case .yellow:
            return "🟡"
        case .red:
            return "🔴"
        case .unknown:
            return "⚪️"
        }
    }

    var color: NSColor {
        switch self {
        case .green:
            return NSColor.systemGreen
        case .yellow:
            return NSColor.systemYellow
        case .red:
            return NSColor.systemRed
        case .unknown:
            return NSColor.systemGray
        }
    }

    var label: String {
        switch self {
        case .green:
            return "运行中"
        case .yellow:
            return "待接手"
        case .red:
            return "空闲"
        case .unknown:
            return "未知"
        }
    }
}

enum DashboardSectionTab: CaseIterable {
    case usage
    case quota
    case projects
    case tools

    var title: String {
        switch self {
        case .usage:
            return "用量趋势"
        case .quota:
            return "账号额度"
        case .projects:
            return "项目排行"
        case .tools:
            return "工具 / Skill"
        }
    }

    var symbol: String {
        switch self {
        case .usage:
            return "chart.bar"
        case .quota:
            return "gauge"
        case .projects:
            return "folder"
        case .tools:
            return "puzzlepiece.extension"
        }
    }
}

enum TimeText {
    static func beijingFull(_ value: String?) -> String {
        guard let value else {
            return "--"
        }
        if let date = parseISO8601(value) {
            return format(date, dateFormat: "yyyy年M月d日 HH:mm")
        }
        return value
    }

    static func beijingShort(_ value: String?) -> String {
        guard let value else {
            return "--"
        }
        if let date = parseISO8601(value) {
            return format(date, dateFormat: "yy年M月d日 HH:mm")
        }
        return value
    }

    static func beijingShort(_ timestamp: TimeInterval?) -> String {
        guard let timestamp else {
            return "--"
        }
        return format(Date(timeIntervalSince1970: timestamp), dateFormat: "yy年M月d日 HH:mm")
    }

    static func beijingHourMinute(_ timestamp: TimeInterval?) -> String {
        guard let timestamp else {
            return "--"
        }
        return format(Date(timeIntervalSince1970: timestamp), dateFormat: "HH:mm")
    }

    static func beijingMonthDay(_ timestamp: TimeInterval?) -> String {
        guard let timestamp else {
            return "--"
        }
        return format(Date(timeIntervalSince1970: timestamp), dateFormat: "M月d日")
    }

    static func beijingMonthDayMinute(_ timestamp: TimeInterval?) -> String {
        guard let timestamp else {
            return "--"
        }
        return format(Date(timeIntervalSince1970: timestamp), dateFormat: "M月d日 HH:mm")
    }

    static func monthDay(_ value: String) -> String {
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.timeZone = TimeZone(identifier: "Asia/Shanghai")
        parser.dateFormat = "yyyy-MM-dd"
        guard let date = parser.date(from: value) else {
            return value
        }
        return format(date, dateFormat: "M/d")
    }

    static func monthDayChinese(_ value: String?) -> String {
        guard let value else {
            return "--"
        }
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.timeZone = TimeZone(identifier: "Asia/Shanghai")
        parser.dateFormat = "yyyy-MM-dd"
        guard let date = parser.date(from: value) else {
            return value
        }
        return format(date, dateFormat: "M月d日")
    }

    private static func format(_ date: Date, dateFormat: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
        formatter.dateFormat = dateFormat
        return formatter.string(from: date)
    }

    private static func parseISO8601(_ value: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: value) {
            return date
        }
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: value)
    }
}

enum TokenText {
    static func compact(_ value: Int?) -> String {
        guard let value else {
            return "--"
        }
        let number = Double(value)
        if abs(number) >= 1_000_000_000 {
            return String(format: "%.1fB", number / 1_000_000_000)
        }
        if abs(number) >= 1_000_000 {
            return String(format: "%.1fM", number / 1_000_000)
        }
        if abs(number) >= 1_000 {
            return String(format: "%.1fK", number / 1_000)
        }
        return "\(value)"
    }

    static func percent(_ numerator: Int, _ denominator: Int) -> String {
        guard denominator > 0 else {
            return "--"
        }
        return "\(Int(round(Double(numerator) * 100 / Double(denominator))))%"
    }
}

final class CodexProfileMenuBarApp: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()
    private var latestPayload: DashboardPayload?
    private var latestError: String?
    private var isRefreshing = false
    private var refreshTimer: Timer?
    private var globalEventMonitor: Any?
    private var localEventMonitor: Any?
    private var dashboardWindowController: DashboardWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configureStatusItem()
        configurePopover()
        updatePopover()
        refreshStatus(showProgress: false)
        startAutoRefresh()
    }

    func applicationWillTerminate(_ notification: Notification) {
        stopPopoverDismissMonitors()
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else {
            return
        }
        button.image = makeStatusIcon(color: RuntimeLight.unknown.color)
        button.imagePosition = .imageLeft
        button.title = " -- ⚪️"
        button.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .semibold)
        button.toolTip = "Codex 账号管家"
        button.target = self
        button.action = #selector(togglePopover(_:))
    }

    private func configurePopover() {
        popover.behavior = .applicationDefined
        popover.animates = true
        popover.delegate = self
        popover.contentSize = NSSize(width: MenuLayout.popoverWidth, height: MenuLayout.maxVisibleHeight)
    }

    private func startAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.refreshStatus(showProgress: false, forceResetCredits: false)
        }
        RunLoop.main.add(refreshTimer!, forMode: .common)
    }

    @objc private func togglePopover(_ sender: Any?) {
        guard let button = statusItem.button else {
            return
        }
        if popover.isShown {
            popover.performClose(sender)
        } else {
            updatePopover()
            popover.show(relativeTo: statusIconAnchorRect(in: button), of: button, preferredEdge: .minY)
            startPopoverDismissMonitors()
        }
    }

    private func statusIconAnchorRect(in button: NSStatusBarButton) -> NSRect {
        let iconWidth = button.image?.size.width ?? 22
        let anchorWidth = min(max(iconWidth, 22), button.bounds.width)
        let x: CGFloat
        switch button.imagePosition {
        case .imageRight, .imageTrailing:
            x = max(0, button.bounds.width - anchorWidth)
        case .imageOnly, .imageLeft, .imageLeading, .imageOverlaps, .imageBelow, .imageAbove:
            x = 0
        case .noImage:
            x = button.bounds.midX - anchorWidth / 2
        @unknown default:
            x = 0
        }
        return NSRect(x: x, y: 0, width: anchorWidth, height: button.bounds.height)
    }

    @objc private func refreshStatus(_ sender: Any?) {
        refreshStatus(showProgress: true, forceResetCredits: true)
    }

    private func refreshStatus(showProgress: Bool, forceResetCredits: Bool = false) {
        if isRefreshing {
            return
        }
        isRefreshing = true
        latestError = nil
        if showProgress {
            updatePopover(message: "正在刷新 Codex 账号...")
        }
        DispatchQueue.global(qos: .userInitiated).async {
            var arguments = ["status", "--json"]
            if forceResetCredits {
                arguments.append("--refresh-reset-credits")
            }
            let result = Self.runPython(arguments: arguments)
            DispatchQueue.main.async {
                self.isRefreshing = false
                switch result {
                case .success(let output):
                    self.handleStatusOutput(output)
                case .failure(let error):
                    self.latestError = error
                    self.updateStatusTitle()
                    self.updatePopover(message: error)
                }
            }
        }
    }

    func popoverDidClose(_ notification: Notification) {
        stopPopoverDismissMonitors()
    }

    private func startPopoverDismissMonitors() {
        stopPopoverDismissMonitors()
        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            DispatchQueue.main.async {
                self?.closePopoverFromOutsideClick()
            }
        }
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self, self.popover.isShown else {
                return event
            }
            if event.window === self.popover.contentViewController?.view.window {
                return event
            }
            if event.window === self.statusItem.button?.window {
                return event
            }
            self.closePopoverFromOutsideClick()
            return event
        }
    }

    private func stopPopoverDismissMonitors() {
        if let globalEventMonitor {
            NSEvent.removeMonitor(globalEventMonitor)
            self.globalEventMonitor = nil
        }
        if let localEventMonitor {
            NSEvent.removeMonitor(localEventMonitor)
            self.localEventMonitor = nil
        }
    }

    private func closePopoverFromOutsideClick() {
        guard popover.isShown else {
            return
        }
        popover.performClose(nil)
    }

    private func handleStatusOutput(_ output: String) {
        guard let data = output.data(using: .utf8) else {
            latestError = "无法读取账号状态。"
            updateStatusTitle()
            updatePopover(message: latestError)
            return
        }
        do {
            latestPayload = try JSONDecoder().decode(DashboardPayload.self, from: data)
            latestError = nil
            updateStatusTitle()
            updatePopover()
            if let payload = latestPayload {
                dashboardWindowController?.update(payload: payload)
            }
        } catch {
            latestError = "无法解析账号状态。"
            updateStatusTitle()
            updatePopover(message: latestError)
        }
    }

    private func updateStatusTitle() {
        if latestError != nil {
            statusItem.button?.image = makeStatusIcon(color: RuntimeLight.red.color)
            statusItem.button?.title = " ! 🔴"
            return
        }
        let remaining = displayProfile()?.rateLimits.primary?.remainingPercent
            ?? latestPayload?.profiles.compactMap { $0.rateLimits.primary?.remainingPercent }.min()
        let runtime = RuntimeLight(status: latestPayload?.runtimeStatus)
        let percent = remaining.map { "\($0)%" } ?? "--"
        statusItem.button?.image = makeStatusIcon(color: runtime.color)
        statusItem.button?.title = " \(percent) \(runtime.emoji)"
    }

    private func displayProfile() -> ProfileStatus? {
        guard let payload = latestPayload, let active = payload.activeProfile else {
            return nil
        }
        return payload.profiles.first { $0.name == active }
    }

    private func makeStatusIcon(color: NSColor) -> NSImage {
        let size = NSSize(width: 22, height: 18)
        let image = NSImage(size: size)
        image.lockFocus()

        let rect = NSRect(x: 1, y: 1, width: 20, height: 16)
        let path = NSBezierPath(roundedRect: rect, xRadius: 5, yRadius: 5)
        let gradient = NSGradient(colors: [
            NSColor(calibratedRed: 0.50, green: 0.92, blue: 0.82, alpha: 1),
            NSColor(calibratedRed: 0.45, green: 0.68, blue: 1.0, alpha: 1),
        ])
        gradient?.draw(in: path, angle: 0)
        NSColor.black.withAlphaComponent(0.22).setStroke()
        path.lineWidth = 1
        path.stroke()

        let c = "C" as NSString
        c.draw(
            at: CGPoint(x: 5.2, y: 1.8),
            withAttributes: [
                .font: NSFont.monospacedSystemFont(ofSize: 13, weight: .heavy),
                .foregroundColor: NSColor.black.withAlphaComponent(0.82),
            ]
        )
        let dot = NSBezierPath(ovalIn: NSRect(x: 15.5, y: 12, width: 5, height: 5))
        color.setFill()
        dot.fill()

        image.unlockFocus()
        image.isTemplate = false
        return image
    }

    private func updatePopover(message: String? = nil) {
        let controller = AccountManagerViewController(
            payload: latestPayload,
            message: message ?? latestError,
            isRefreshing: isRefreshing,
            refreshAction: { [weak self] in self?.refreshStatus(nil) },
            openDashboardAction: { [weak self] in self?.openDashboardWindow() },
            launchAction: { [weak self] in self?.launchActiveProfile() },
            quitAction: { NSApp.terminate(nil) },
            switchAction: { [weak self] name in self?.switchProfile(name) }
        )
        popover.contentViewController = controller
        popover.contentSize = controller.preferredContentSize
    }

    private func openDashboardWindow() {
        guard let payload = latestPayload else {
            refreshStatus(showProgress: false, forceResetCredits: false)
            return
        }
        let controller = dashboardWindowController ?? DashboardWindowController(
            payload: payload,
            refreshAction: { [weak self] in self?.refreshStatus(nil) },
            switchAction: { [weak self] name in self?.switchProfile(name) }
        )
        dashboardWindowController = controller
        controller.update(payload: payload)
        controller.showWindow(nil)
        controller.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func launchActiveProfile() {
        guard let name = latestPayload?.activeProfile ?? latestPayload?.profiles.first?.name else {
            updatePopover(message: "没有可启动的账号。")
            return
        }
        switchProfile(name)
    }

    private func switchProfile(_ name: String) {
        statusItem.button?.image = makeStatusIcon(color: RuntimeLight.unknown.color)
        statusItem.button?.title = " ... ⚪️"
        updatePopover(message: "正在切换到 \(name)...")
        DispatchQueue.global(qos: .userInitiated).async {
            let result = Self.runPython(arguments: ["app", name])
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self.updatePopover(message: "已切换到 \(name)。")
                    self.refreshStatus(showProgress: false, forceResetCredits: true)
                case .failure(let error):
                    self.latestError = error
                    self.updateStatusTitle()
                    self.updatePopover(message: error)
                }
            }
        }
    }

    private static func runPython(arguments: [String]) -> CommandResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["python3", scriptPath()] + arguments
        var environment = ProcessInfo.processInfo.environment
        let defaultPath = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        environment["PATH"] = [environment["PATH"], defaultPath].compactMap { $0 }.joined(separator: ":")
        process.environment = environment

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        do {
            try process.run()
        } catch {
            return .failure("Could not start codex_profile.py.")
        }
        process.waitUntilExit()

        let output = String(data: stdout.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let errorOutput = String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        if process.terminationStatus == 0 {
            return .success(output)
        }
        let message = errorOutput
            .split(separator: "\n")
            .reversed()
            .first { line in
                let value = line.trimmingCharacters(in: .whitespaces)
                return !value.isEmpty && !value.hasPrefix("File ") && value != "Traceback (most recent call last):"
            }
            .map(String.init)
            ?? "Command failed."
        return .failure(message)
    }

    private static func scriptPath() -> String {
        if let override = ProcessInfo.processInfo.environment["CODEX_PROFILE_SWITCHER_SCRIPT"] {
            return override
        }
        if let resourcePath = Bundle.main.resourcePath {
            let bundled = URL(fileURLWithPath: resourcePath)
                .appendingPathComponent("codex-profile-switcher")
                .appendingPathComponent("codex_profile.py")
                .path
            if FileManager.default.fileExists(atPath: bundled) {
                return bundled
            }
        }
        return FileManager.default.currentDirectoryPath + "/codex_profile.py"
    }
}

final class DashboardWindowController: NSWindowController {
    private let controller: MainDashboardViewController

    init(
        payload: DashboardPayload,
        refreshAction: @escaping () -> Void,
        switchAction: @escaping (String) -> Void
    ) {
        controller = MainDashboardViewController(
            payload: payload,
            refreshAction: refreshAction,
            switchAction: switchAction
        )
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1160, height: 720),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Codex 账号管家"
        window.center()
        window.isOpaque = false
        window.backgroundColor = .clear
        window.titlebarAppearsTransparent = true
        window.contentViewController = controller
        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(payload: DashboardPayload) {
        controller.update(payload: payload)
    }
}

final class MainDashboardViewController: NSViewController {
    private var payload: DashboardPayload
    private let refreshAction: () -> Void
    private let switchAction: (String) -> Void
    private let contentWidth: CGFloat = 1080
    private var selectedTab: DashboardSectionTab = .usage

    init(
        payload: DashboardPayload,
        refreshAction: @escaping () -> Void,
        switchAction: @escaping (String) -> Void
    ) {
        self.payload = payload
        self.refreshAction = refreshAction
        self.switchAction = switchAction
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = MainDashboardRootView(frame: NSRect(x: 0, y: 0, width: 1160, height: 720))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        build()
    }

    func update(payload: DashboardPayload) {
        self.payload = payload
        if isViewLoaded {
            build()
        }
    }

    private func build() {
        view.subviews.forEach { $0.removeFromSuperview() }

        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.scrollerStyle = .overlay
        view.addSubview(scrollView)

        let document = NSView()
        document.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = document

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 16
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false
        document.addSubview(stack)

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            document.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor),
            document.trailingAnchor.constraint(equalTo: scrollView.contentView.trailingAnchor),
            document.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor),
            document.widthAnchor.constraint(greaterThanOrEqualTo: scrollView.contentView.widthAnchor),
            stack.centerXAnchor.constraint(equalTo: document.centerXAnchor),
            stack.topAnchor.constraint(equalTo: document.topAnchor, constant: 34),
            stack.widthAnchor.constraint(equalToConstant: contentWidth),
            document.bottomAnchor.constraint(equalTo: stack.bottomAnchor, constant: 34),
        ])

        stack.addArrangedSubview(mainHeader())
        stack.addArrangedSubview(DashboardHeroGridView(payload: payload, width: contentWidth, switchAction: switchAction))
        stack.addArrangedSubview(
            DashboardTabBarView(
                selectedTab: selectedTab,
                width: contentWidth,
                selectAction: { [weak self] tab in
                    self?.selectedTab = tab
                    self?.build()
                }
            )
        )
        stack.addArrangedSubview(selectedAnalyticsPanel())
    }

    private func selectedAnalyticsPanel() -> NSView {
        switch selectedTab {
        case .usage:
            return UsageTrendAnalyticsPanelView(payload: payload, width: contentWidth)
        case .quota:
            return QuotaOperationsPanelView(payload: payload, width: contentWidth, switchAction: switchAction)
        case .projects:
            return DashboardAnalyticsPanelView(payload: payload, width: contentWidth, mode: .projects)
        case .tools:
            return DashboardAnalyticsPanelView(payload: payload, width: contentWidth, mode: .tools)
        }
    }

    private func mainHeader() -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 12
        row.alignment = .centerY
        row.translatesAutoresizingMaskIntoConstraints = false
        row.widthAnchor.constraint(equalToConstant: contentWidth).isActive = true

        let logo = ToolLogoView()
        logo.translatesAutoresizingMaskIntoConstraints = false
        logo.widthAnchor.constraint(equalToConstant: 38).isActive = true
        logo.heightAnchor.constraint(equalToConstant: 38).isActive = true
        row.addArrangedSubview(logo)

        let titleStack = NSStackView()
        titleStack.orientation = .vertical
        titleStack.spacing = 1
        titleStack.alignment = .leading

        let title = DashboardText.label("Codex 账号管家", size: 20, weight: .heavy, alpha: 0.82)
        let subtitle = DashboardText.label("刷新 \(TimeText.beijingFull(payload.generatedAt)) · \(runtimeText())", size: 12, weight: .semibold, alpha: 0.54)
        titleStack.addArrangedSubview(title)
        titleStack.addArrangedSubview(subtitle)
        row.addArrangedSubview(titleStack)

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        row.addArrangedSubview(spacer)

        row.addArrangedSubview(HeaderStatusPillView(runtime: RuntimeLight(status: payload.runtimeStatus), text: runtimeShortText()))

        let refresh = NSButton(title: "刷新", target: self, action: #selector(refreshTapped))
        refresh.bezelStyle = .rounded
        refresh.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        row.addArrangedSubview(refresh)
        return row
    }

    private func runtimeShortText() -> String {
        let runtime = RuntimeLight(status: payload.runtimeStatus)
        if runtime == .green, let count = payload.runtimeStatus?.activeProcessCount, count > 0 {
            return "运行中 \(count)"
        }
        return runtime.label
    }

    private func runtimeText() -> String {
        RuntimeLight(status: payload.runtimeStatus).label
    }

    @objc private func refreshTapped() {
        refreshAction()
    }
}

final class MainDashboardRootView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        NSColor.clear.setFill()
        bounds.fill()
        let panel = NSBezierPath(roundedRect: bounds.insetBy(dx: 10, dy: 10), xRadius: 28, yRadius: 28)
        NSGradient(colors: [
            NSColor(calibratedRed: 0.74, green: 0.86, blue: 0.78, alpha: 0.97),
            NSColor(calibratedRed: 0.92, green: 0.84, blue: 0.74, alpha: 0.94),
            NSColor(calibratedRed: 0.75, green: 0.78, blue: 0.95, alpha: 0.97),
        ])?.draw(in: panel, angle: 315)
        NSColor.white.withAlphaComponent(0.50).setStroke()
        panel.lineWidth = 1.2
        panel.stroke()
        drawPattern()
    }

    private func drawPattern() {
        let symbols = ["5h", "7d", "C", "∑", "+"]
        for row in stride(from: 34, to: Int(bounds.height), by: 88) {
            for col in stride(from: 40, to: Int(bounds.width), by: 130) {
                let text = symbols[abs(row + col) % symbols.count] as NSString
                text.draw(
                    at: CGPoint(x: col, y: row),
                    withAttributes: [
                        .font: NSFont.monospacedSystemFont(ofSize: 14, weight: .heavy),
                        .foregroundColor: NSColor.white.withAlphaComponent(0.04),
                    ]
                )
            }
        }
    }
}

enum DashboardText {
    static func label(_ text: String, size: CGFloat, weight: NSFont.Weight, alpha: CGFloat = 0.76) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = NSFont.systemFont(ofSize: size, weight: weight)
        label.textColor = NSColor.black.withAlphaComponent(alpha)
        label.lineBreakMode = .byTruncatingTail
        return label
    }

    static func mono(_ text: String, size: CGFloat, weight: NSFont.Weight, alpha: CGFloat = 0.76) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = NSFont.monospacedSystemFont(ofSize: size, weight: weight)
        label.textColor = NSColor.black.withAlphaComponent(alpha)
        label.lineBreakMode = .byTruncatingTail
        return label
    }
}

class GlassPanelView: NSView {
    private let cornerRadius: CGFloat

    init(width: CGFloat, height: CGFloat, cornerRadius: CGFloat = 18) {
        self.cornerRadius = cornerRadius
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        widthAnchor.constraint(equalToConstant: width).isActive = true
        heightAnchor.constraint(equalToConstant: height).isActive = true
        wantsLayer = true
        layer?.cornerRadius = cornerRadius
        layer?.borderColor = NSColor.white.withAlphaComponent(0.42).cgColor
        layer?.borderWidth = 1
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(roundedRect: bounds, xRadius: cornerRadius, yRadius: cornerRadius)
        NSColor.white.withAlphaComponent(0.68).setFill()
        path.fill()
    }
}

final class DashboardHeroGridView: NSView {
    private let payload: DashboardPayload
    private let switchAction: (String) -> Void
    private let panelWidth: CGFloat

    init(payload: DashboardPayload, width: CGFloat, switchAction: @escaping (String) -> Void) {
        self.payload = payload
        self.switchAction = switchAction
        self.panelWidth = width
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        widthAnchor.constraint(equalToConstant: width).isActive = true
        heightAnchor.constraint(equalToConstant: 248).isActive = true
        build()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func build() {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 16
        row.alignment = .top
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: leadingAnchor),
            row.trailingAnchor.constraint(equalTo: trailingAnchor),
            row.topAnchor.constraint(equalTo: topAnchor),
            row.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        row.addArrangedSubview(DashboardQuotaFocusPanelView(payload: payload, width: 316))

        let right = NSStackView()
        right.orientation = .vertical
        right.spacing = 12
        right.alignment = .leading
        row.addArrangedSubview(right)

        let rightWidth = panelWidth - 332
        right.addArrangedSubview(DashboardMetricGridView(payload: payload, width: rightWidth))

        right.addArrangedSubview(
            AccountSwitcherStripView(
                profiles: payload.profiles,
                activeProfileName: payload.activeProfile,
                width: rightWidth,
                switchAction: switchAction
            )
        )
    }
}

final class DashboardQuotaFocusPanelView: GlassPanelView {
    private let payload: DashboardPayload
    private let panelWidth: CGFloat

    init(payload: DashboardPayload, width: CGFloat) {
        self.payload = payload
        self.panelWidth = width
        super.init(width: width, height: 248, cornerRadius: 22)
        build()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func build() {
        let active = activeProfile()
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 12
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 18),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -18),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 16),
        ])

        let header = NSStackView()
        header.orientation = .horizontal
        header.alignment = .centerY
        header.widthAnchor.constraint(equalToConstant: panelWidth - 36).isActive = true

        let badge = ProfileBadgeView(name: active?.name ?? "Codex", index: 0)
        badge.translatesAutoresizingMaskIntoConstraints = false
        badge.widthAnchor.constraint(equalToConstant: 42).isActive = true
        badge.heightAnchor.constraint(equalToConstant: 42).isActive = true
        header.addArrangedSubview(badge)

        let titleStack = NSStackView()
        titleStack.orientation = .vertical
        titleStack.spacing = 2
        titleStack.alignment = .leading
        let name = DashboardText.label(active?.name ?? "--", size: 15.5, weight: .heavy, alpha: 0.84)
        name.translatesAutoresizingMaskIntoConstraints = false
        name.widthAnchor.constraint(equalToConstant: 170).isActive = true
        titleStack.addArrangedSubview(name)
        titleStack.addArrangedSubview(DashboardText.mono(planText(active), size: 10.5, weight: .bold, alpha: 0.48))
        header.addArrangedSubview(titleStack)

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        header.addArrangedSubview(spacer)
        header.addArrangedSubview(DashboardText.label("当前", size: 11.5, weight: .bold, alpha: 0.58))
        stack.addArrangedSubview(header)

        let center = NSStackView()
        center.orientation = .horizontal
        center.spacing = 16
        center.alignment = .centerY
        center.widthAnchor.constraint(equalToConstant: panelWidth - 36).isActive = true

        let dial = QuotaDialView(profile: active)
        dial.translatesAutoresizingMaskIntoConstraints = false
        dial.widthAnchor.constraint(equalToConstant: 144).isActive = true
        dial.heightAnchor.constraint(equalToConstant: 142).isActive = true
        center.addArrangedSubview(dial)

        let resets = NSStackView()
        resets.orientation = .vertical
        resets.spacing = 9
        resets.alignment = .leading
        resets.addArrangedSubview(resetLine(title: "5h 重置", value: TimeText.beijingHourMinute(active?.rateLimits.primary?.resetsAt), tint: AccountHealth(remaining: active?.rateLimits.primary?.remainingPercent).color))
        resets.addArrangedSubview(resetLine(title: "7d 重置", value: TimeText.beijingMonthDay(active?.rateLimits.secondary?.resetsAt), tint: NSColor(calibratedRed: 0.55, green: 0.42, blue: 0.96, alpha: 1)))
        resets.addArrangedSubview(resetLine(title: "健康", value: AccountHealth(remaining: active?.rateLimits.primary?.remainingPercent).label, tint: AccountHealth(remaining: active?.rateLimits.primary?.remainingPercent).color))
        center.addArrangedSubview(resets)

        stack.addArrangedSubview(center)
    }

    private func activeProfile() -> ProfileStatus? {
        guard let active = payload.activeProfile else {
            return payload.profiles.first
        }
        return payload.profiles.first { $0.name == active } ?? payload.profiles.first
    }

    private func planText(_ profile: ProfileStatus?) -> String {
        let plan = profile?.rateLimits.planType?.uppercased() ?? "UNKNOWN"
        let stale = profile?.remoteStale == true ? " · 暂存" : ""
        return "\(plan)\(stale)"
    }

    private func resetLine(title: String, value: String, tint: NSColor) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 8
        row.alignment = .firstBaseline
        let dot = ColorDotView(color: tint)
        dot.translatesAutoresizingMaskIntoConstraints = false
        dot.widthAnchor.constraint(equalToConstant: 7).isActive = true
        dot.heightAnchor.constraint(equalToConstant: 7).isActive = true
        row.addArrangedSubview(dot)
        let label = DashboardText.label(title, size: 11.5, weight: .semibold, alpha: 0.50)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.widthAnchor.constraint(equalToConstant: 58).isActive = true
        row.addArrangedSubview(label)
        row.addArrangedSubview(DashboardText.mono(value, size: 12, weight: .bold, alpha: 0.66))
        return row
    }
}

final class DashboardMetricGridView: NSView {
    private let payload: DashboardPayload
    private let gridWidth: CGFloat

    init(payload: DashboardPayload, width: CGFloat) {
        self.payload = payload
        self.gridWidth = width
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        widthAnchor.constraint(equalToConstant: width).isActive = true
        heightAnchor.constraint(equalToConstant: 194).isActive = true
        build()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func build() {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
        ])

        let cardWidth = (gridWidth - 12) / 2
        let rows = [
            [
                MainMetricCardView(title: "今日 token", value: todayTokenValue(activeProfile()), caption: todayTokenCaption(activeProfile()), tint: NSColor.systemBlue, width: cardWidth, height: 88),
                MainMetricCardView(title: "近 7 日 token", value: TokenText.compact(activeProfile()?.usageMetrics?.last7Tokens), caption: "当前账号", tint: NSColor(calibratedRed: 0.55, green: 0.42, blue: 0.96, alpha: 1), width: cardWidth, height: 88),
            ],
            [
                MainMetricCardView(title: "重置卡", value: "\(resetCardCount(activeProfile())) 张", caption: nearestCreditExpiry(activeProfile()), tint: NSColor.systemOrange, width: cardWidth, height: 88),
                MainMetricCardView(title: "托管状态", value: runtimeShortValue(), caption: desktopStatusText(), tint: RuntimeLight(status: payload.runtimeStatus).color, width: cardWidth, height: 88),
            ],
        ]

        for metricRow in rows {
            let row = NSStackView()
            row.orientation = .horizontal
            row.spacing = 12
            row.alignment = .top
            stack.addArrangedSubview(row)
            metricRow.forEach { row.addArrangedSubview($0) }
        }
    }

    private func activeProfile() -> ProfileStatus? {
        guard let active = payload.activeProfile else {
            return payload.profiles.first
        }
        return payload.profiles.first { $0.name == active } ?? payload.profiles.first
    }

    private func todayTokenCaption(_ profile: ProfileStatus?) -> String {
        switch profile?.tokenAttribution?.todaySource {
        case "official":
            return "官方账号值"
        case "attribution_estimate":
            return "管家归因估算"
        default:
            return "账号统计"
        }
    }

    private func resetCardCount(_ profile: ProfileStatus?) -> Int {
        profile?.resetCreditDetails?.availableCount ?? profile?.rateLimits.resetCredits?.availableCount ?? 0
    }

    private func nearestCreditExpiry(_ profile: ProfileStatus?) -> String {
        guard let expiry = profile?.resetCreditDetails?.earliestExpiresAt ?? profile?.rateLimits.resetCredits?.expiresAt else {
            return "暂无到期"
        }
        return "\(TimeText.beijingMonthDay(expiry)) 到期"
    }

    private func todayTokenValue(_ profile: ProfileStatus?) -> String {
        if let value = profile?.tokenAttribution?.todayDisplayTokens {
            return TokenText.compact(value)
        }
        return TokenText.compact(profile?.usageMetrics?.todayTokens)
    }

    private func runtimeShortValue() -> String {
        let runtime = RuntimeLight(status: payload.runtimeStatus)
        if runtime == .green, let count = payload.runtimeStatus?.activeProcessCount, count > 0 {
            return "\(count) 个运行"
        }
        return runtime.label
    }

    private func desktopStatusText() -> String {
        guard let status = payload.desktopStatus else {
            return "路径未读取"
        }
        if status.state == "managed_default_home" {
            return "已接管 · \(status.activeProfile ?? payload.activeProfile ?? "当前账号")"
        }
        if status.running {
            return "未接管 · 建议重启"
        }
        return "已准备 · 可打开"
    }
}

final class MainMetricCardView: GlassPanelView {
    init(title: String, value: String, caption: String, tint: NSColor, width: CGFloat, height: CGFloat = 88) {
        super.init(width: width, height: height, cornerRadius: 16)
        layer?.borderColor = tint.withAlphaComponent(0.24).cgColor

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 5
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
        stack.addArrangedSubview(DashboardText.label(title, size: 11, weight: .semibold, alpha: 0.48))
        stack.addArrangedSubview(DashboardText.mono(value, size: 18, weight: .heavy, alpha: 0.84))
        stack.addArrangedSubview(DashboardText.label(caption, size: 10.5, weight: .medium, alpha: 0.46))
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class TokenTrendPanelView: GlassPanelView {
    init(payload: DashboardPayload, width: CGFloat) {
        super.init(width: width, height: 250, cornerRadius: 18)
        let active = payload.profiles.first { $0.name == payload.activeProfile } ?? payload.profiles.first
        let buckets = Array((active?.usage?.dailyUsageBuckets ?? payload.localSnapshot?.daily?.map { DailyUsageBucket(startDate: $0.date, tokens: $0.totalTokens) } ?? []).suffix(14))

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 12
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 18),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -18),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 16),
        ])

        let header = NSStackView()
        header.orientation = .horizontal
        header.alignment = .firstBaseline
        header.translatesAutoresizingMaskIntoConstraints = false
        header.widthAnchor.constraint(equalToConstant: width - 36).isActive = true
        header.addArrangedSubview(DashboardText.label("用量趋势", size: 15, weight: .heavy, alpha: 0.78))
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        header.addArrangedSubview(spacer)
        header.addArrangedSubview(DashboardText.mono("近14日 \(TokenText.compact(buckets.reduce(0) { $0 + $1.tokens }))", size: 12, weight: .bold, alpha: 0.58))
        stack.addArrangedSubview(header)

        let chart = DailyUsageChartView(buckets: buckets)
        chart.translatesAutoresizingMaskIntoConstraints = false
        chart.widthAnchor.constraint(equalToConstant: width - 36).isActive = true
        chart.heightAnchor.constraint(equalToConstant: 126).isActive = true
        stack.addArrangedSubview(chart)

        if let accuracy = active?.tokenAttribution?.previousDayAccuracy {
            stack.addArrangedSubview(DashboardText.label("昨日校准：估算 \(TokenText.compact(accuracy.estimatedTokens)) · 官方 \(TokenText.compact(accuracy.officialTokens)) · 差 \(TokenText.compact(abs(accuracy.deltaTokens)))", size: 12, weight: .semibold, alpha: 0.58))
        } else {
            stack.addArrangedSubview(DashboardText.label("今日显示为账号口径；当天可为管家归因估算，次日用官方数据校准。", size: 12, weight: .semibold, alpha: 0.52))
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class AccountsCompactPanelView: GlassPanelView {
    init(payload: DashboardPayload, width: CGFloat, switchAction: @escaping (String) -> Void) {
        super.init(width: width, height: 250, cornerRadius: 18)
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 10
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 16),
        ])
        stack.addArrangedSubview(DashboardText.label("账号额度", size: 15, weight: .heavy, alpha: 0.78))
        for profile in payload.profiles.prefix(3) {
            stack.addArrangedSubview(AccountMiniRowView(profile: profile, isActive: payload.activeProfile == profile.name, width: width - 32, switchAction: switchAction))
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class AccountMiniRowView: NSView {
    private let profile: ProfileStatus
    private let isActive: Bool
    private let switchAction: (String) -> Void

    init(profile: ProfileStatus, isActive: Bool, width: CGFloat, switchAction: @escaping (String) -> Void) {
        self.profile = profile
        self.isActive = isActive
        self.switchAction = switchAction
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        widthAnchor.constraint(equalToConstant: width).isActive = true
        heightAnchor.constraint(equalToConstant: 58).isActive = true
        wantsLayer = true
        layer?.cornerRadius = 13
        layer?.backgroundColor = NSColor.white.withAlphaComponent(0.30).cgColor
        build(width: width)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func build(width: CGFloat) {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 10
        row.alignment = .centerY
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            row.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
        let text = NSStackView()
        text.orientation = .vertical
        text.spacing = 3
        text.alignment = .leading
        text.addArrangedSubview(DashboardText.label(profile.name, size: 12.5, weight: .heavy, alpha: 0.82))
        text.addArrangedSubview(DashboardText.mono("5h \(profile.rateLimits.primary?.remainingPercent ?? 0)% · 7d \(profile.rateLimits.secondary?.remainingPercent ?? 0)%", size: 11, weight: .semibold, alpha: 0.58))
        row.addArrangedSubview(text)

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        row.addArrangedSubview(spacer)

        if isActive {
            row.addArrangedSubview(DashboardText.label("当前", size: 12, weight: .bold, alpha: 0.62))
        } else {
            let button = NSButton(title: "切换", target: self, action: #selector(switchTapped))
            button.bezelStyle = .rounded
            button.font = NSFont.systemFont(ofSize: 11, weight: .bold)
            row.addArrangedSubview(button)
        }
    }

    @objc private func switchTapped() {
        switchAction(profile.name)
    }
}

final class ProjectRankingPanelView: GlassPanelView {
    init(payload: DashboardPayload, width: CGFloat) {
        super.init(width: width, height: 300, cornerRadius: 18)
        let items = Array((payload.projectRankings?.projects ?? []).prefix(6))
        let stack = RankingStackBuilder.baseStack(in: self, width: width, title: "项目排行", subtitle: "按本地线程 token 汇总")
        if items.isEmpty {
            stack.addArrangedSubview(RankingStackBuilder.empty("暂无项目数据", width: width - 32))
        } else {
            for (index, item) in items.enumerated() {
                stack.addArrangedSubview(
                    RankingRowView(
                        index: index + 1,
                        title: item.name,
                        subtitle: "\(item.threadCount) 条线程",
                        value: TokenText.compact(item.tokensUsed),
                        width: width - 32
                    )
                )
            }
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class ToolSkillPanelView: GlassPanelView {
    init(payload: DashboardPayload, width: CGFloat) {
        super.init(width: width, height: 300, cornerRadius: 18)
        let stack = RankingStackBuilder.baseStack(in: self, width: width, title: "工具 / Skill", subtitle: "调用次数与最近使用")

        let tools = Array((payload.toolRankings?.tools ?? []).prefix(4))
        if !tools.isEmpty {
            stack.addArrangedSubview(DashboardText.label("工具 TOP", size: 11, weight: .bold, alpha: 0.52))
            for (index, item) in tools.enumerated() {
                stack.addArrangedSubview(
                    RankingRowView(
                        index: index + 1,
                        title: item.name,
                        subtitle: item.namespace.isEmpty ? "工具" : item.namespace,
                        value: "\(item.callCount) 次",
                        width: width - 32
                    )
                )
            }
        }

        let skills = Array((payload.skillRankings?.skills ?? []).prefix(3))
        if !skills.isEmpty {
            stack.addArrangedSubview(DashboardText.label("Skill TOP", size: 11, weight: .bold, alpha: 0.52))
            for (index, item) in skills.enumerated() {
                stack.addArrangedSubview(
                    RankingRowView(
                        index: index + 1,
                        title: item.name,
                        subtitle: TimeText.beijingFull(item.latestTimestamp),
                        value: "\(item.useCount) 次",
                        width: width - 32
                    )
                )
            }
        }

        if tools.isEmpty && skills.isEmpty {
            stack.addArrangedSubview(RankingStackBuilder.empty("暂无工具或 Skill 数据", width: width - 32))
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

enum RankingStackBuilder {
    static func baseStack(in view: NSView, width: CGFloat, title: String, subtitle: String) -> NSStackView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 8
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 16),
        ])

        let header = NSStackView()
        header.orientation = .horizontal
        header.alignment = .firstBaseline
        header.translatesAutoresizingMaskIntoConstraints = false
        header.widthAnchor.constraint(equalToConstant: width - 32).isActive = true
        header.addArrangedSubview(DashboardText.label(title, size: 15, weight: .heavy, alpha: 0.78))
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        header.addArrangedSubview(spacer)
        header.addArrangedSubview(DashboardText.label(subtitle, size: 10.5, weight: .medium, alpha: 0.42))
        stack.addArrangedSubview(header)
        return stack
    }

    static func empty(_ text: String, width: CGFloat) -> NSView {
        let label = DashboardText.label(text, size: 12, weight: .medium, alpha: 0.42)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.widthAnchor.constraint(equalToConstant: width).isActive = true
        label.alignment = .center
        return label
    }
}

final class RankingRowView: NSView {
    init(index: Int, title: String, subtitle: String, value: String, width: CGFloat) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        widthAnchor.constraint(equalToConstant: width).isActive = true
        heightAnchor.constraint(equalToConstant: 34).isActive = true
        wantsLayer = true
        layer?.cornerRadius = 10
        layer?.backgroundColor = NSColor.white.withAlphaComponent(0.28).cgColor

        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 9
        row.alignment = .centerY
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            row.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
        row.addArrangedSubview(DashboardText.mono("\(index)", size: 11, weight: .heavy, alpha: 0.54))

        let text = NSStackView()
        text.orientation = .vertical
        text.spacing = 1
        text.alignment = .leading
        text.addArrangedSubview(DashboardText.label(title, size: 11.5, weight: .bold, alpha: 0.76))
        text.addArrangedSubview(DashboardText.label(subtitle, size: 9.5, weight: .medium, alpha: 0.40))
        row.addArrangedSubview(text)

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        row.addArrangedSubview(spacer)
        row.addArrangedSubview(DashboardText.mono(value, size: 11, weight: .bold, alpha: 0.62))
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class DashboardTabBarView: GlassPanelView {
    init(selectedTab: DashboardSectionTab, width: CGFloat, selectAction: @escaping (DashboardSectionTab) -> Void) {
        super.init(width: width, height: 52, cornerRadius: 18)

        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 6
        row.distribution = .fillEqually
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            row.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            row.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
        ])

        for tab in DashboardSectionTab.allCases {
            row.addArrangedSubview(
                DashboardTabButtonView(
                    tab: tab,
                    isSelected: tab == selectedTab,
                    action: { selectAction(tab) }
                )
            )
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class DashboardTabButtonView: NSView {
    private let tab: DashboardSectionTab
    private let isSelected: Bool
    private let action: () -> Void
    private var hovering = false

    init(tab: DashboardSectionTab, isSelected: Bool, action: @escaping () -> Void) {
        self.tab = tab
        self.isSelected = isSelected
        self.action = action
        super.init(frame: .zero)
        wantsLayer = true

        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 7
        row.alignment = .centerY
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)
        NSLayoutConstraint.activate([
            row.centerXAnchor.constraint(equalTo: centerXAnchor),
            row.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])

        let icon = NSImageView(image: NSImage(systemSymbolName: tab.symbol, accessibilityDescription: tab.title) ?? NSImage())
        icon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
        icon.contentTintColor = isSelected ? NSColor.white : NSColor.black.withAlphaComponent(0.58)
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.widthAnchor.constraint(equalToConstant: 16).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 16).isActive = true
        row.addArrangedSubview(icon)

        let title = DashboardText.label(tab.title, size: 12, weight: .semibold, alpha: isSelected ? 1 : 0.58)
        title.textColor = isSelected ? NSColor.white : NSColor.black.withAlphaComponent(0.58)
        row.addArrangedSubview(title)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach { removeTrackingArea($0) }
        addTrackingArea(NSTrackingArea(rect: bounds, options: [.activeAlways, .mouseEnteredAndExited, .inVisibleRect], owner: self))
    }

    override func mouseEntered(with event: NSEvent) {
        hovering = true
        needsDisplay = true
    }

    override func mouseExited(with event: NSEvent) {
        hovering = false
        needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) {
        action()
    }

    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(roundedRect: bounds, xRadius: 13, yRadius: 13)
        if isSelected {
            NSColor(calibratedRed: 0.16, green: 0.33, blue: 0.62, alpha: 0.86).setFill()
        } else {
            NSColor.white.withAlphaComponent(hovering ? 0.34 : 0.16).setFill()
        }
        path.fill()
    }
}

final class AccountSwitcherStripView: NSView {
    private let profiles: [ProfileStatus]
    private let activeProfileName: String?
    private let switchAction: (String) -> Void
    private let stripWidth: CGFloat

    init(
        profiles: [ProfileStatus],
        activeProfileName: String?,
        width: CGFloat,
        switchAction: @escaping (String) -> Void
    ) {
        self.profiles = profiles
        self.activeProfileName = activeProfileName
        self.stripWidth = width
        self.switchAction = switchAction
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        widthAnchor.constraint(equalToConstant: width).isActive = true
        heightAnchor.constraint(equalToConstant: 42).isActive = true
        wantsLayer = true
        build()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 14, yRadius: 14)
        NSColor.white.withAlphaComponent(0.36).setFill()
        path.fill()
        NSColor.white.withAlphaComponent(0.50).setStroke()
        path.lineWidth = 1
        path.stroke()
    }

    private func build() {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 8
        row.alignment = .centerY
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            row.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])

        let title = DashboardText.label("快速切换", size: 11.5, weight: .bold, alpha: 0.52)
        title.translatesAutoresizingMaskIntoConstraints = false
        title.widthAnchor.constraint(equalToConstant: 62).isActive = true
        row.addArrangedSubview(title)

        guard !profiles.isEmpty else {
            row.addArrangedSubview(DashboardText.label("暂无账号", size: 12, weight: .semibold, alpha: 0.48))
            return
        }

        let visibleProfiles = Array(profiles.prefix(4))
        let availableWidth = max(92, stripWidth - 20 - 62 - CGFloat(visibleProfiles.count) * 8)
        let buttonWidth = min(152, max(104, availableWidth / CGFloat(visibleProfiles.count)))
        for profile in visibleProfiles {
            row.addArrangedSubview(
                AccountSwitchPillView(
                    profile: profile,
                    isActive: profile.name == activeProfileName,
                    width: buttonWidth,
                    switchAction: switchAction
                )
            )
        }
    }
}

final class AccountSwitchPillView: NSView {
    private let profile: ProfileStatus
    private let isActive: Bool
    private let switchAction: (String) -> Void
    private var isHovering = false

    init(profile: ProfileStatus, isActive: Bool, width: CGFloat, switchAction: @escaping (String) -> Void) {
        self.profile = profile
        self.isActive = isActive
        self.switchAction = switchAction
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        widthAnchor.constraint(equalToConstant: width).isActive = true
        heightAnchor.constraint(equalToConstant: 30).isActive = true
        wantsLayer = true
        build()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach { removeTrackingArea($0) }
        addTrackingArea(
            NSTrackingArea(
                rect: bounds,
                options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                owner: self,
                userInfo: nil
            )
        )
    }

    override func mouseEntered(with event: NSEvent) {
        guard !isActive else {
            return
        }
        isHovering = true
        needsDisplay = true
    }

    override func mouseExited(with event: NSEvent) {
        isHovering = false
        needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) {
        guard !isActive else {
            return
        }
        switchAction(profile.name)
    }

    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(roundedRect: bounds, xRadius: 10, yRadius: 10)
        let fill = isActive
            ? NSColor.systemGreen.withAlphaComponent(0.20)
            : NSColor.white.withAlphaComponent(isHovering ? 0.66 : 0.44)
        fill.setFill()
        path.fill()
        (isActive ? NSColor.systemGreen : NSColor.white).withAlphaComponent(0.56).setStroke()
        path.lineWidth = 1
        path.stroke()
    }

    private func build() {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 6
        row.alignment = .centerY
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 9),
            row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -9),
            row.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])

        let name = DashboardText.label(shortName(profile.name), size: 11.5, weight: .bold, alpha: 0.76)
        name.lineBreakMode = .byTruncatingMiddle
        row.addArrangedSubview(name)

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        row.addArrangedSubview(spacer)

        let state = DashboardText.label(isActive ? "当前" : "切换", size: 10.5, weight: .bold, alpha: isActive ? 0.60 : 0.50)
        row.addArrangedSubview(state)
    }

    private func shortName(_ name: String) -> String {
        if name.hasPrefix("hd-") {
            return String(name.dropFirst(3))
        }
        return name
    }
}

final class UsageTrendAnalyticsPanelView: GlassPanelView {
    init(payload: DashboardPayload, width: CGFloat) {
        super.init(width: width, height: 346, cornerRadius: 22)
        let active = Self.activeProfile(payload)
        let buckets = Self.displayBuckets(payload: payload, profile: active)

        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 16
        row.alignment = .top
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 18),
            row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -18),
            row.topAnchor.constraint(equalTo: topAnchor, constant: 18),
            row.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -18),
        ])

        let trend = AnalyticsCardView(title: "最近 14 日用量", subtitle: "当前账号优先，缺失时使用本地共享记录", width: 590, height: 310)
        let chart = DailyUsageChartView(buckets: buckets)
        trend.contentStack.addArrangedSubview(chart)
        chart.translatesAutoresizingMaskIntoConstraints = false
        chart.widthAnchor.constraint(equalToConstant: 552).isActive = true
        chart.heightAnchor.constraint(equalToConstant: 172).isActive = true
        trend.contentStack.addArrangedSubview(Self.accuracyLine(active))
        row.addArrangedSubview(trend)

        let summary = AnalyticsCardView(title: "Token 构成", subtitle: "输入 / 缓存 / 输出", width: 318, height: 310)
        if let snapshot = payload.localSnapshot {
            let split = TokenSplitBarView(total: Self.displayTotal(snapshot))
            split.translatesAutoresizingMaskIntoConstraints = false
            split.widthAnchor.constraint(equalToConstant: 280).isActive = true
            split.heightAnchor.constraint(equalToConstant: 24).isActive = true
            summary.contentStack.addArrangedSubview(Self.bigMetric("今日", value: Self.todayTokenValue(active), caption: Self.todayTokenCaption(active)))
            summary.contentStack.addArrangedSubview(split)
            summary.contentStack.addArrangedSubview(Self.breakdown(snapshot))
            summary.contentStack.addArrangedSubview(Self.modelRows(snapshot))
        } else {
            summary.contentStack.addArrangedSubview(RankingStackBuilder.empty("暂无本地 token 记录", width: 280))
        }
        row.addArrangedSubview(summary)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private static func activeProfile(_ payload: DashboardPayload) -> ProfileStatus? {
        guard let active = payload.activeProfile else {
            return payload.profiles.first
        }
        return payload.profiles.first { $0.name == active } ?? payload.profiles.first
    }

    private static func displayBuckets(payload: DashboardPayload, profile: ProfileStatus?) -> [DailyUsageBucket] {
        let accountBuckets = profile?.usage?.dailyUsageBuckets ?? []
        if !accountBuckets.isEmpty {
            return Array(accountBuckets.suffix(14))
        }
        return Array((payload.localSnapshot?.daily ?? []).suffix(14)).map {
            DailyUsageBucket(startDate: $0.date, tokens: $0.totalTokens)
        }
    }

    private static func displayTotal(_ snapshot: LocalTokenSnapshot) -> TokenUsageTotals {
        guard let daily = snapshot.daily, !daily.isEmpty else {
            return snapshot.total
        }
        return daily.reduce(TokenUsageTotals(inputTokens: 0, cachedInputTokens: 0, outputTokens: 0, reasoningOutputTokens: 0, totalTokens: 0)) { partial, item in
            TokenUsageTotals(
                inputTokens: partial.inputTokens + item.inputTokens,
                cachedInputTokens: partial.cachedInputTokens + item.cachedInputTokens,
                outputTokens: partial.outputTokens + item.outputTokens,
                reasoningOutputTokens: partial.reasoningOutputTokens + item.reasoningOutputTokens,
                totalTokens: partial.totalTokens + item.totalTokens
            )
        }
    }

    private static func todayTokenValue(_ profile: ProfileStatus?) -> String {
        if let value = profile?.tokenAttribution?.todayDisplayTokens {
            return TokenText.compact(value)
        }
        return TokenText.compact(profile?.usageMetrics?.todayTokens)
    }

    private static func todayTokenCaption(_ profile: ProfileStatus?) -> String {
        switch profile?.tokenAttribution?.todaySource {
        case "official":
            return "官方账号值"
        case "attribution_estimate":
            return "管家归因估算"
        default:
            return "账号统计"
        }
    }

    private static func bigMetric(_ title: String, value: String, caption: String) -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 3
        stack.alignment = .leading
        stack.addArrangedSubview(DashboardText.label(title, size: 11, weight: .semibold, alpha: 0.48))
        stack.addArrangedSubview(DashboardText.mono(value, size: 26, weight: .heavy, alpha: 0.82))
        stack.addArrangedSubview(DashboardText.label(caption, size: 11, weight: .medium, alpha: 0.48))
        return stack
    }

    private static func breakdown(_ snapshot: LocalTokenSnapshot) -> NSView {
        let total = displayTotal(snapshot)
        let label = DashboardText.label(
            [
                "输入 \(TokenText.compact(total.inputTokens))",
                "缓存 \(TokenText.compact(total.cachedInputTokens))",
                "输出 \(TokenText.compact(total.outputTokens))",
                "推理 \(TokenText.compact(total.reasoningOutputTokens))",
            ].joined(separator: " · "),
            size: 11,
            weight: .medium,
            alpha: 0.58
        )
        label.translatesAutoresizingMaskIntoConstraints = false
        label.widthAnchor.constraint(equalToConstant: 280).isActive = true
        return label
    }

    private static func modelRows(_ snapshot: LocalTokenSnapshot) -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 6
        stack.alignment = .leading
        for (index, model) in Array((snapshot.byModel ?? []).sorted { $0.totalTokens > $1.totalTokens }.prefix(3)).enumerated() {
            stack.addArrangedSubview(
                RankingRowView(index: index + 1, title: model.model, subtitle: "模型", value: TokenText.compact(model.totalTokens), width: 280)
            )
        }
        return stack
    }

    private static func accuracyLine(_ profile: ProfileStatus?) -> NSView {
        let text: String
        if let accuracy = profile?.tokenAttribution?.previousDayAccuracy {
            text = "昨日校准：估算 \(TokenText.compact(accuracy.estimatedTokens)) · 官方 \(TokenText.compact(accuracy.officialTokens)) · 差值 \(TokenText.compact(abs(accuracy.deltaTokens)))"
        } else {
            text = "当天为管家归因估算；次日用官方账号数据自动校准。"
        }
        let label = DashboardText.label(text, size: 12, weight: .semibold, alpha: 0.58)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.widthAnchor.constraint(equalToConstant: 552).isActive = true
        return label
    }
}

final class QuotaOperationsPanelView: GlassPanelView {
    init(payload: DashboardPayload, width: CGFloat, switchAction: @escaping (String) -> Void) {
        super.init(width: width, height: 346, cornerRadius: 22)

        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 16
        row.alignment = .top
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 18),
            row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -18),
            row.topAnchor.constraint(equalTo: topAnchor, constant: 18),
            row.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -18),
        ])

        let accounts = AnalyticsCardView(title: "账号额度", subtitle: "切换账号与当前窗口", width: 590, height: 310)
        for profile in payload.profiles {
            accounts.contentStack.addArrangedSubview(
                AccountQuotaRowView(profile: profile, isActive: payload.activeProfile == profile.name, width: 552, switchAction: switchAction)
            )
        }
        row.addArrangedSubview(accounts)

        let credits = AnalyticsCardView(title: "重置卡", subtitle: "按到期时间排序", width: 318, height: 310)
        for profile in payload.profiles {
            credits.contentStack.addArrangedSubview(ResetCreditCompactStripView(profile: profile, width: 280))
        }
        row.addArrangedSubview(credits)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

enum DashboardAnalyticsMode {
    case projects
    case tools
}

final class DashboardAnalyticsPanelView: GlassPanelView {
    init(payload: DashboardPayload, width: CGFloat, mode: DashboardAnalyticsMode) {
        super.init(width: width, height: 346, cornerRadius: 22)

        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 16
        row.alignment = .top
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 18),
            row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -18),
            row.topAnchor.constraint(equalTo: topAnchor, constant: 18),
            row.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -18),
        ])

        switch mode {
        case .projects:
            row.addArrangedSubview(RankingListPanelView(title: "近活跃项目", subtitle: "按本地 token 排序", width: 452, height: 310, rows: projectRows(payload)))
            row.addArrangedSubview(ProjectActivityPanelView(payload: payload, width: 456))
        case .tools:
            row.addArrangedSubview(RankingListPanelView(title: "工具使用 TOP", subtitle: "调用次数", width: 452, height: 310, rows: toolRows(payload)))
            row.addArrangedSubview(RankingListPanelView(title: "Skill 使用 TOP", subtitle: "加载次数与最近使用", width: 456, height: 310, rows: skillRows(payload)))
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func projectRows(_ payload: DashboardPayload) -> [(String, String, String)] {
        Array((payload.projectRankings?.projects ?? []).prefix(7)).map {
            ($0.name, "\($0.threadCount) 条线程", TokenText.compact($0.tokensUsed))
        }
    }

    private func toolRows(_ payload: DashboardPayload) -> [(String, String, String)] {
        Array((payload.toolRankings?.tools ?? []).prefix(7)).map {
            ($0.name, $0.namespace.isEmpty ? "工具" : $0.namespace, "\($0.callCount) 次")
        }
    }

    private func skillRows(_ payload: DashboardPayload) -> [(String, String, String)] {
        Array((payload.skillRankings?.skills ?? []).prefix(7)).map {
            ($0.name, TimeText.beijingFull($0.latestTimestamp), "\($0.useCount) 次")
        }
    }
}

class AnalyticsCardView: GlassPanelView {
    let contentStack = NSStackView()

    init(title: String, subtitle: String, width: CGFloat, height: CGFloat) {
        super.init(width: width, height: height, cornerRadius: 18)

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 10
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 18),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -18),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -16),
        ])

        let header = NSStackView()
        header.orientation = .horizontal
        header.alignment = .firstBaseline
        header.translatesAutoresizingMaskIntoConstraints = false
        header.widthAnchor.constraint(equalToConstant: width - 36).isActive = true
        header.addArrangedSubview(DashboardText.label(title, size: 14.5, weight: .heavy, alpha: 0.78))
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        header.addArrangedSubview(spacer)
        header.addArrangedSubview(DashboardText.label(subtitle, size: 10.5, weight: .medium, alpha: 0.42))
        stack.addArrangedSubview(header)

        contentStack.orientation = .vertical
        contentStack.spacing = 8
        contentStack.alignment = .leading
        stack.addArrangedSubview(contentStack)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class RankingListPanelView: AnalyticsCardView {
    init(title: String, subtitle: String, width: CGFloat, height: CGFloat, rows: [(String, String, String)]) {
        super.init(title: title, subtitle: subtitle, width: width, height: height)
        if rows.isEmpty {
            contentStack.addArrangedSubview(RankingStackBuilder.empty("暂无数据", width: width - 36))
        } else {
            for (index, row) in rows.enumerated() {
                contentStack.addArrangedSubview(RankingRowView(index: index + 1, title: row.0, subtitle: row.1, value: row.2, width: width - 36))
            }
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class ProjectActivityPanelView: AnalyticsCardView {
    init(payload: DashboardPayload, width: CGFloat) {
        super.init(title: "项目活动概览", subtitle: "本地线程口径", width: width, height: 310)
        let projects = payload.projectRankings?.projects ?? []
        let totalTokens = projects.reduce(0) { $0 + $1.tokensUsed }
        let totalThreads = projects.reduce(0) { $0 + $1.threadCount }
        contentStack.addArrangedSubview(metricRow(title: "项目数", value: "\(projects.count)", caption: "已记录工作区"))
        contentStack.addArrangedSubview(metricRow(title: "线程数", value: "\(totalThreads)", caption: "本地历史线程"))
        contentStack.addArrangedSubview(metricRow(title: "累计", value: TokenText.compact(totalTokens), caption: "排行内 token"))
        if let first = projects.first {
            contentStack.addArrangedSubview(metricRow(title: "最高", value: first.name, caption: TokenText.compact(first.tokensUsed)))
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func metricRow(title: String, value: String, caption: String) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 12
        row.alignment = .firstBaseline
        row.translatesAutoresizingMaskIntoConstraints = false
        row.widthAnchor.constraint(equalToConstant: 420).isActive = true
        row.addArrangedSubview(DashboardText.label(title, size: 12, weight: .semibold, alpha: 0.48))
        let valueLabel = DashboardText.mono(value, size: 17, weight: .heavy, alpha: 0.78)
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        valueLabel.widthAnchor.constraint(equalToConstant: 190).isActive = true
        row.addArrangedSubview(valueLabel)
        row.addArrangedSubview(DashboardText.label(caption, size: 11, weight: .medium, alpha: 0.44))
        return row
    }
}

final class AccountQuotaRowView: NSView {
    private let profile: ProfileStatus
    private let isActive: Bool
    private let switchAction: (String) -> Void

    init(profile: ProfileStatus, isActive: Bool, width: CGFloat, switchAction: @escaping (String) -> Void) {
        self.profile = profile
        self.isActive = isActive
        self.switchAction = switchAction
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        widthAnchor.constraint(equalToConstant: width).isActive = true
        heightAnchor.constraint(equalToConstant: 82).isActive = true
        wantsLayer = true
        layer?.cornerRadius = 14
        layer?.backgroundColor = NSColor.white.withAlphaComponent(isActive ? 0.42 : 0.28).cgColor
        layer?.borderColor = (isActive ? NSColor.systemGreen : NSColor.white).withAlphaComponent(0.42).cgColor
        layer?.borderWidth = 1
        build(width: width)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func build(width: CGFloat) {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 12
        row.alignment = .centerY
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            row.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])

        let badge = ProfileBadgeView(name: profile.name, index: isActive ? 0 : 1)
        badge.translatesAutoresizingMaskIntoConstraints = false
        badge.widthAnchor.constraint(equalToConstant: 44).isActive = true
        badge.heightAnchor.constraint(equalToConstant: 44).isActive = true
        row.addArrangedSubview(badge)

        let nameStack = NSStackView()
        nameStack.orientation = .vertical
        nameStack.spacing = 3
        nameStack.alignment = .leading
        let name = DashboardText.label(profile.name, size: 14.5, weight: .heavy, alpha: 0.84)
        name.translatesAutoresizingMaskIntoConstraints = false
        name.widthAnchor.constraint(equalToConstant: 160).isActive = true
        nameStack.addArrangedSubview(name)
        nameStack.addArrangedSubview(DashboardText.mono("PLUS · \(isActive ? "当前" : "可切换")", size: 10.5, weight: .bold, alpha: 0.48))
        row.addArrangedSubview(nameStack)

        let bars = NSStackView()
        bars.orientation = .vertical
        bars.spacing = 7
        bars.alignment = .leading
        bars.addArrangedSubview(barLine(title: "5h", window: profile.rateLimits.primary, width: 210))
        bars.addArrangedSubview(barLine(title: "7d", window: profile.rateLimits.secondary, width: 210))
        row.addArrangedSubview(bars)

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        row.addArrangedSubview(spacer)

        if isActive {
            row.addArrangedSubview(DashboardText.label("当前", size: 12, weight: .bold, alpha: 0.58))
        } else {
            let button = NSButton(title: "切换", target: self, action: #selector(switchTapped))
            button.bezelStyle = .rounded
            button.font = NSFont.systemFont(ofSize: 11.5, weight: .bold)
            row.addArrangedSubview(button)
        }
    }

    private func barLine(title: String, window: RateLimitWindow?, width: CGFloat) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 8
        row.alignment = .centerY
        let label = DashboardText.mono(title, size: 11, weight: .bold, alpha: 0.56)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.widthAnchor.constraint(equalToConstant: 24).isActive = true
        row.addArrangedSubview(label)
        let remaining = window?.remainingPercent
        let bar = PixelBarView(percent: remaining ?? 0, color: AccountHealth(remaining: remaining).color)
        bar.translatesAutoresizingMaskIntoConstraints = false
        bar.widthAnchor.constraint(equalToConstant: width).isActive = true
        bar.heightAnchor.constraint(equalToConstant: 14).isActive = true
        row.addArrangedSubview(bar)
        let value = DashboardText.mono("\(remaining.map { "\($0)%" } ?? "--")", size: 11, weight: .bold, alpha: 0.62)
        value.translatesAutoresizingMaskIntoConstraints = false
        value.widthAnchor.constraint(equalToConstant: 40).isActive = true
        row.addArrangedSubview(value)
        return row
    }

    @objc private func switchTapped() {
        switchAction(profile.name)
    }
}

final class ResetCreditCompactStripView: NSView {
    init(profile: ProfileStatus, width: CGFloat) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        widthAnchor.constraint(equalToConstant: width).isActive = true
        heightAnchor.constraint(equalToConstant: 78).isActive = true
        wantsLayer = true
        layer?.cornerRadius = 14
        layer?.backgroundColor = NSColor.white.withAlphaComponent(0.28).cgColor

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 7
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])

        let header = NSStackView()
        header.orientation = .horizontal
        header.alignment = .firstBaseline
        header.widthAnchor.constraint(equalToConstant: width - 24).isActive = true
        header.addArrangedSubview(DashboardText.label(profile.name, size: 12, weight: .heavy, alpha: 0.76))
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        header.addArrangedSubview(spacer)
        header.addArrangedSubview(DashboardText.mono("\(count(profile)) 张", size: 11, weight: .bold, alpha: 0.58))
        stack.addArrangedSubview(header)

        let line = DashboardText.label(expiryText(profile), size: 11.5, weight: .semibold, alpha: 0.60)
        line.translatesAutoresizingMaskIntoConstraints = false
        line.widthAnchor.constraint(equalToConstant: width - 24).isActive = true
        stack.addArrangedSubview(line)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func count(_ profile: ProfileStatus) -> Int {
        profile.resetCreditDetails?.availableCount ?? profile.rateLimits.resetCredits?.availableCount ?? 0
    }

    private func expiryText(_ profile: ProfileStatus) -> String {
        let cards = (profile.resetCreditDetails?.credits ?? [])
            .filter { $0.used != true }
            .compactMap(\.expiresAt)
            .sorted()
        guard !cards.isEmpty else {
            return profile.resetCreditError ?? "暂无可用重置卡"
        }
        return cards.prefix(3).map { TimeText.beijingMonthDayMinute($0) }.joined(separator: " · ")
    }
}

final class PopoverRuntimeSummaryView: NSView {
    private let payload: DashboardPayload?
    private let message: String?

    init(payload: DashboardPayload?, message: String?) {
        self.payload = payload
        self.message = message
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        widthAnchor.constraint(equalToConstant: MenuLayout.contentWidth).isActive = true
        heightAnchor.constraint(equalToConstant: 136).isActive = true
        wantsLayer = true
        layer?.cornerRadius = 16
        layer?.borderColor = NSColor.white.withAlphaComponent(0.46).cgColor
        layer?.borderWidth = 1
        build()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.white.withAlphaComponent(0.34).setFill()
        NSBezierPath(roundedRect: bounds, xRadius: 16, yRadius: 16).fill()
    }

    private func build() {
        guard let payload else {
            let label = DashboardText.label(message ?? "正在读取 Codex 状态", size: 13, weight: .semibold, alpha: 0.58)
            label.translatesAutoresizingMaskIntoConstraints = false
            addSubview(label)
            NSLayoutConstraint.activate([
                label.centerXAnchor.constraint(equalTo: centerXAnchor),
                label.centerYAnchor.constraint(equalTo: centerYAnchor),
            ])
            return
        }

        let active = activeProfile(payload)
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 14
        row.alignment = .centerY
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            row.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])

        let dial = QuotaDialView(profile: active)
        dial.translatesAutoresizingMaskIntoConstraints = false
        dial.widthAnchor.constraint(equalToConstant: 104).isActive = true
        dial.heightAnchor.constraint(equalToConstant: 112).isActive = true
        row.addArrangedSubview(dial)

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 7
        stack.alignment = .leading
        row.addArrangedSubview(stack)

        stack.addArrangedSubview(DashboardText.label(active?.name ?? "--", size: 15, weight: .heavy, alpha: 0.82))
        stack.addArrangedSubview(DashboardText.label(runtimeLine(payload), size: 11.5, weight: .semibold, alpha: 0.58))
        stack.addArrangedSubview(DashboardText.mono("今日 \(todayToken(active)) · 重置卡 \(resetCount(active)) 张", size: 11.5, weight: .bold, alpha: 0.62))
        stack.addArrangedSubview(DashboardText.label(desktopLine(payload), size: 11.5, weight: .semibold, alpha: 0.54))
    }

    private func activeProfile(_ payload: DashboardPayload) -> ProfileStatus? {
        guard let active = payload.activeProfile else {
            return payload.profiles.first
        }
        return payload.profiles.first { $0.name == active } ?? payload.profiles.first
    }

    private func runtimeLine(_ payload: DashboardPayload) -> String {
        let runtime = RuntimeLight(status: payload.runtimeStatus)
        return "\(runtime.label) · 刷新 \(TimeText.beijingFull(payload.generatedAt))"
    }

    private func desktopLine(_ payload: DashboardPayload) -> String {
        guard let status = payload.desktopStatus else {
            return "Codex 路径未读取"
        }
        if status.state == "managed_default_home" {
            return "Codex 已接管 · \(status.activeProfile ?? payload.activeProfile ?? "当前账号")"
        }
        if status.running {
            return "Codex 未接管 · 建议重启接管"
        }
        return "Codex 已准备"
    }

    private func todayToken(_ profile: ProfileStatus?) -> String {
        if let value = profile?.tokenAttribution?.todayDisplayTokens {
            return TokenText.compact(value)
        }
        return TokenText.compact(profile?.usageMetrics?.todayTokens)
    }

    private func resetCount(_ profile: ProfileStatus?) -> Int {
        profile?.resetCreditDetails?.availableCount ?? profile?.rateLimits.resetCredits?.availableCount ?? 0
    }
}

final class PopoverProfileSwitcherView: NSView {
    private let payload: DashboardPayload
    private let switchAction: (String) -> Void
    private let panelWidth: CGFloat

    init(payload: DashboardPayload, width: CGFloat, switchAction: @escaping (String) -> Void) {
        self.payload = payload
        self.panelWidth = width
        self.switchAction = switchAction
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        widthAnchor.constraint(equalToConstant: width).isActive = true
        heightAnchor.constraint(equalToConstant: 100).isActive = true
        wantsLayer = true
        layer?.cornerRadius = 16
        layer?.borderColor = NSColor.white.withAlphaComponent(0.46).cgColor
        layer?.borderWidth = 1
        build()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.white.withAlphaComponent(0.32).setFill()
        NSBezierPath(roundedRect: bounds, xRadius: 16, yRadius: 16).fill()
    }

    private func build() {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 9
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])

        let header = NSStackView()
        header.orientation = .horizontal
        header.alignment = .firstBaseline
        header.translatesAutoresizingMaskIntoConstraints = false
        header.widthAnchor.constraint(equalToConstant: panelWidth - 24).isActive = true
        header.addArrangedSubview(DashboardText.label("账号切换", size: 12.5, weight: .heavy, alpha: 0.72))
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        header.addArrangedSubview(spacer)
        header.addArrangedSubview(DashboardText.label("直接切换并接管 Codex", size: 10.5, weight: .semibold, alpha: 0.42))
        stack.addArrangedSubview(header)

        stack.addArrangedSubview(
            AccountSwitcherStripView(
                profiles: payload.profiles,
                activeProfileName: payload.activeProfile,
                width: panelWidth - 24,
                switchAction: switchAction
            )
        )
    }
}

final class AccountManagerViewController: NSViewController {
    private let payload: DashboardPayload?
    private let message: String?
    private let isRefreshing: Bool
    private let refreshAction: () -> Void
    private let openDashboardAction: () -> Void
    private let launchAction: () -> Void
    private let quitAction: () -> Void
    private let switchAction: (String) -> Void

    init(
        payload: DashboardPayload?,
        message: String?,
        isRefreshing: Bool,
        refreshAction: @escaping () -> Void,
        openDashboardAction: @escaping () -> Void,
        launchAction: @escaping () -> Void,
        quitAction: @escaping () -> Void,
        switchAction: @escaping (String) -> Void
    ) {
        self.payload = payload
        self.message = message
        self.isRefreshing = isRefreshing
        self.refreshAction = refreshAction
        self.openDashboardAction = openDashboardAction
        self.launchAction = launchAction
        self.quitAction = quitAction
        self.switchAction = switchAction
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        let size = Self.preferredSize(payload: payload, hasMessage: message != nil)
        preferredContentSize = size
        view = AccountManagerView(frame: NSRect(origin: .zero, size: size))
    }

    private static func preferredSize(payload: DashboardPayload?, hasMessage: Bool) -> NSSize {
        let contentHeight = estimatedContentHeight(payload: payload, hasMessage: hasMessage)
        let screenLimit = max(
            MenuLayout.minVisibleHeight,
            (NSScreen.main?.visibleFrame.height ?? MenuLayout.maxVisibleHeight) - 64
        )
        let maxHeight = min(MenuLayout.maxVisibleHeight, screenLimit)
        let height = min(max(contentHeight, MenuLayout.minVisibleHeight), maxHeight)
        return NSSize(width: MenuLayout.popoverWidth, height: height)
    }

    private static func estimatedContentHeight(payload: DashboardPayload?, hasMessage: Bool) -> CGFloat {
        var itemHeights: [CGFloat] = [56, 136]
        if (payload?.profiles.isEmpty == false) {
            itemHeights.append(100)
        }
        if hasMessage {
            itemHeights.append(22)
        }
        itemHeights.append(actionRowHeight(payload: payload))
        let spacing = CGFloat(max(0, itemHeights.count - 1)) * MenuLayout.verticalSpacing
        return MenuLayout.contentInset * 2 + itemHeights.reduce(0, +) + spacing
    }

    private static func actionRowHeight(payload: DashboardPayload?) -> CGFloat {
        let hasLaunchAction = (payload?.activeProfile ?? payload?.profiles.first?.name) != nil
        return hasLaunchAction ? 38 : 38
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        build()
    }

    private func build() {
        guard let root = view as? AccountManagerView else {
            return
        }

        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.scrollerStyle = .overlay
        scrollView.verticalScrollElasticity = .allowed
        root.addSubview(scrollView)

        let document = NSView()
        document.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = document

        let actions = actionRow()
        root.addSubview(actions)

        let content = NSStackView()
        content.orientation = .vertical
        content.spacing = MenuLayout.verticalSpacing
        content.alignment = .leading
        content.translatesAutoresizingMaskIntoConstraints = false
        document.addSubview(content)

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: root.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: actions.topAnchor, constant: -8),
            document.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor),
            document.trailingAnchor.constraint(equalTo: scrollView.contentView.trailingAnchor),
            document.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor),
            document.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor),
            document.heightAnchor.constraint(greaterThanOrEqualTo: scrollView.contentView.heightAnchor),
            content.leadingAnchor.constraint(equalTo: document.leadingAnchor, constant: MenuLayout.contentInset),
            content.trailingAnchor.constraint(equalTo: document.trailingAnchor, constant: -MenuLayout.contentInset),
            content.topAnchor.constraint(equalTo: document.topAnchor, constant: MenuLayout.contentInset),
            document.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: 16),
            actions.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: MenuLayout.contentInset),
            actions.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -MenuLayout.contentInset),
            actions.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -14),
        ])

        content.addArrangedSubview(headerView())
        content.addArrangedSubview(PopoverRuntimeSummaryView(payload: payload, message: message))
        if let payload, !payload.profiles.isEmpty {
            content.addArrangedSubview(
                PopoverProfileSwitcherView(
                    payload: payload,
                    width: MenuLayout.contentWidth,
                    switchAction: switchAction
                )
            )
        }

        if let message {
            content.addArrangedSubview(messageView(message))
        }

    }

    private func headerView() -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 10
        row.alignment = .centerY
        row.translatesAutoresizingMaskIntoConstraints = false
        row.widthAnchor.constraint(equalToConstant: MenuLayout.contentWidth).isActive = true

        let logo = ToolLogoView()
        logo.translatesAutoresizingMaskIntoConstraints = false
        logo.widthAnchor.constraint(equalToConstant: 34).isActive = true
        logo.heightAnchor.constraint(equalToConstant: 34).isActive = true
        row.addArrangedSubview(logo)

        let titles = NSStackView()
        titles.orientation = .vertical
        titles.spacing = 1
        titles.alignment = .leading

        let title = NSTextField(labelWithString: "Codex 账号管家")
        title.font = NSFont.systemFont(ofSize: 18, weight: .heavy)
        title.textColor = NSColor(calibratedRed: 0.08, green: 0.14, blue: 0.15, alpha: 1)
        title.alignment = .left

        let updated = NSTextField(labelWithString: "刷新 \(TimeText.beijingFull(payload?.generatedAt))")
        updated.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .medium)
        updated.textColor = NSColor.black.withAlphaComponent(0.56)
        updated.alignment = .left

        titles.addArrangedSubview(title)
        titles.addArrangedSubview(updated)
        row.addArrangedSubview(titles)

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        row.addArrangedSubview(spacer)

        row.addArrangedSubview(HeaderStatusPillView(runtime: RuntimeLight(status: payload?.runtimeStatus), text: runtimeShortText()))
        return row
    }

    private func trafficLights() -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 8
        row.alignment = .centerY

        let runtime = RuntimeLight(status: payload?.runtimeStatus)
        for item in [RuntimeLight.green, .yellow, .red] {
            let dot = ColorDotView(color: item == runtime ? item.color : NSColor.systemGray.withAlphaComponent(0.25))
            dot.translatesAutoresizingMaskIntoConstraints = false
            dot.widthAnchor.constraint(equalToConstant: 13).isActive = true
            dot.heightAnchor.constraint(equalToConstant: 13).isActive = true
            row.addArrangedSubview(dot)
        }
        let label = NSTextField(labelWithString: runtimeSummary(runtimeStatus: payload?.runtimeStatus, runtime: runtime))
        label.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        label.textColor = NSColor(calibratedWhite: 0.18, alpha: 1)
        row.addArrangedSubview(label)
        return row
    }

    private func runtimeShortText() -> String {
        let runtime = RuntimeLight(status: payload?.runtimeStatus)
        guard let runtimeStatus = payload?.runtimeStatus else {
            return runtime.label
        }
        switch runtime {
        case .green:
            return runtimeStatus.activeProcessCount > 0 ? "运行中 \(runtimeStatus.activeProcessCount)" : "有输出"
        case .yellow:
            return "待接手"
        case .red:
            return "空闲"
        case .unknown:
            return "未知"
        }
    }

    private func desktopStatusView() -> NSView {
        let label = NSTextField(labelWithString: desktopStatusText())
        label.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        label.textColor = desktopStatusColor()
        label.alignment = .left
        label.lineBreakMode = .byTruncatingTail
        label.translatesAutoresizingMaskIntoConstraints = false
        label.widthAnchor.constraint(equalToConstant: MenuLayout.contentWidth).isActive = true
        return label
    }

    private func desktopStatusText() -> String {
        guard let status = payload?.desktopStatus else {
            return "Codex 路径：未读取"
        }
        if status.state == "managed_default_home" {
            return "Codex 路径：已接管 · \(status.activeProfile ?? "当前账号")"
        }
        if status.state == "managed_legacy" {
            return "Codex 路径：旧模式托管 · 建议重启一次"
        }
        if status.running {
            return "Codex 路径：未接管 · 用当前账号重启"
        }
        return "Codex 路径：已准备 · 用当前账号打开"
    }

    private func desktopStatusColor() -> NSColor {
        guard let status = payload?.desktopStatus else {
            return NSColor(calibratedWhite: 0.28, alpha: 1)
        }
        if status.state == "managed_default_home" {
            return NSColor(calibratedRed: 0.08, green: 0.34, blue: 0.25, alpha: 1)
        }
        if status.running || status.state == "managed_legacy" {
            return NSColor(calibratedRed: 0.52, green: 0.32, blue: 0.02, alpha: 1)
        }
        return NSColor(calibratedRed: 0.08, green: 0.34, blue: 0.25, alpha: 1)
    }

    private func runtimeSummary(runtimeStatus: RuntimeStatus?, runtime: RuntimeLight) -> String {
        guard let runtimeStatus else {
            return "\(runtime.label) · 尚未读取运行状态"
        }
        switch runtime {
        case .green:
            if runtimeStatus.activeProcessCount > 0 {
                return "\(runtime.label) · \(runtimeStatus.activeProcessCount) 个对话进程正在运行"
            }
            return "\(runtime.label) · 最近 90 秒内有 Codex 输出"
        case .yellow:
            return "\(runtime.label) · 最近 15 分钟内有活动，可能等你继续"
        case .red:
            return "\(runtime.label) · 当前没有运行中的对话"
        case .unknown:
            return "\(runtime.label) · 尚未读取运行状态"
        }
    }

    private func displayProfile() -> ProfileStatus? {
        guard let payload, let active = payload.activeProfile else {
            return nil
        }
        return payload.profiles.first { $0.name == active }
    }

    private func messageView(_ message: String) -> NSView {
        let label = NSTextField(labelWithString: message)
        label.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        label.textColor = NSColor(calibratedRed: 0.15, green: 0.24, blue: 0.38, alpha: 1)
        label.alignment = .left
        label.lineBreakMode = .byTruncatingTail
        label.translatesAutoresizingMaskIntoConstraints = false
        label.widthAnchor.constraint(equalToConstant: MenuLayout.contentWidth).isActive = true
        return label
    }

    private func actionRow() -> NSView {
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.distribution = .fillEqually
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.widthAnchor.constraint(equalToConstant: MenuLayout.contentWidth).isActive = true
        stack.addArrangedSubview(
            ActionRowView(
                icon: "↻",
                title: isRefreshing ? "刷新中" : "刷新",
                isEnabled: !isRefreshing,
                action: refreshAction
            )
        )
        stack.addArrangedSubview(
            ActionRowView(
                icon: "▣",
                title: "面板",
                isEnabled: payload != nil,
                action: openDashboardAction
            )
        )
        if launchTargetName() != nil {
            stack.addArrangedSubview(
                ActionRowView(
                    icon: "🚀",
                    title: launchTitle(),
                    isEnabled: true,
                    action: launchAction
                )
            )
        }
        stack.addArrangedSubview(
            ActionRowView(
                icon: "⏻",
                title: "退出",
                isEnabled: true,
                action: quitAction
            )
        )
        return stack
    }

    private func launchTargetName() -> String? {
        payload?.activeProfile ?? payload?.profiles.first?.name
    }

    private func launchTitle() -> String {
        guard let status = payload?.desktopStatus else {
            return "打开"
        }
        if status.state == "managed_default_home" {
            return "重启"
        }
        if status.running {
            return "接管"
        }
        return "打开"
    }

    @objc private func refreshTapped() {
        refreshAction()
    }

    @objc private func quitTapped() {
        quitAction()
    }
}

final class AccountManagerView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let gradient = NSGradient(colors: [
            NSColor(calibratedRed: 0.78, green: 0.86, blue: 0.79, alpha: 0.86),
            NSColor(calibratedRed: 0.85, green: 0.82, blue: 0.74, alpha: 0.78),
            NSColor(calibratedRed: 0.78, green: 0.82, blue: 0.94, alpha: 0.86),
        ])
        gradient?.draw(in: bounds, angle: 315)
        drawPattern()
    }

    private func drawPattern() {
        let symbols = ["C", "5h", "7d", "+", "∑"]
        let color = NSColor.white.withAlphaComponent(0.18)
        for row in stride(from: 18, to: Int(bounds.height), by: 56) {
            for col in stride(from: 20, to: Int(bounds.width), by: 94) {
                let index = abs(row + col) % symbols.count
                let text = symbols[index] as NSString
                text.draw(
                    at: CGPoint(x: col, y: row),
                    withAttributes: [
                        .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .bold),
                        .foregroundColor: color,
                    ]
                )
            }
        }
    }
}

final class ToolLogoView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        let rect = bounds.insetBy(dx: 2, dy: 2)
        let path = NSBezierPath(roundedRect: rect, xRadius: 9, yRadius: 9)
        NSGradient(colors: [
            NSColor(calibratedRed: 0.52, green: 0.95, blue: 0.80, alpha: 1),
            NSColor(calibratedRed: 0.48, green: 0.62, blue: 1.0, alpha: 1),
        ])?.draw(in: path, angle: 315)
        NSColor.white.withAlphaComponent(0.72).setStroke()
        path.lineWidth = 1.5
        path.stroke()

        let label = "C" as NSString
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 18, weight: .heavy),
            .foregroundColor: NSColor.black.withAlphaComponent(0.78),
        ]
        let size = label.size(withAttributes: attributes)
        label.draw(at: CGPoint(x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2 - 1), withAttributes: attributes)
    }
}

final class HeaderStatusPillView: NSView {
    private let runtime: RuntimeLight
    private let text: String

    init(runtime: RuntimeLight, text: String) {
        self.runtime = runtime
        self.text = text
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        widthAnchor.constraint(equalToConstant: 92).isActive = true
        heightAnchor.constraint(equalToConstant: 28).isActive = true
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(roundedRect: bounds, xRadius: 14, yRadius: 14)
        NSColor.white.withAlphaComponent(0.52).setFill()
        path.fill()
        runtime.color.withAlphaComponent(0.24).setStroke()
        path.lineWidth = 1
        path.stroke()

        runtime.color.setFill()
        NSBezierPath(ovalIn: NSRect(x: 10, y: 9, width: 10, height: 10)).fill()

        let value = text as NSString
        value.draw(
            at: CGPoint(x: 27, y: 7),
            withAttributes: [
                .font: NSFont.systemFont(ofSize: 11, weight: .bold),
                .foregroundColor: NSColor.black.withAlphaComponent(0.70),
            ]
        )
    }
}

final class QuotaDialView: NSView {
    private let profile: ProfileStatus?

    init(profile: ProfileStatus?) {
        self.profile = profile
        super.init(frame: .zero)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        let center = CGPoint(x: bounds.midX, y: bounds.midY + 10)
        drawRing(center: center, radius: 48, percent: profile?.rateLimits.primary?.remainingPercent, color: AccountHealth(remaining: profile?.rateLimits.primary?.remainingPercent).color)
        drawRing(center: center, radius: 34, percent: profile?.rateLimits.secondary?.remainingPercent, color: NSColor(calibratedRed: 0.55, green: 0.42, blue: 0.96, alpha: 1))

        let primary = "\(profile?.rateLimits.primary?.remainingPercent ?? 0)%"
        let secondary = "\(profile?.rateLimits.secondary?.remainingPercent ?? 0)%"
        drawCentered("5h \(primary)", y: center.y + 5, color: AccountHealth(remaining: profile?.rateLimits.primary?.remainingPercent).color)
        drawCentered("7d \(secondary)", y: center.y - 14, color: NSColor(calibratedRed: 0.55, green: 0.42, blue: 0.96, alpha: 1))

        drawLegend(color: AccountHealth(remaining: profile?.rateLimits.primary?.remainingPercent).color, label: "5h", value: TimeText.beijingHourMinute(profile?.rateLimits.primary?.resetsAt), y: 16)
        drawLegend(color: NSColor(calibratedRed: 0.55, green: 0.42, blue: 0.96, alpha: 1), label: "7d", value: TimeText.beijingMonthDay(profile?.rateLimits.secondary?.resetsAt), y: 0)
    }

    private func drawRing(center: CGPoint, radius: CGFloat, percent: Int?, color: NSColor) {
        let track = NSBezierPath()
        track.appendArc(withCenter: center, radius: radius, startAngle: 0, endAngle: 360)
        NSColor.white.withAlphaComponent(0.38).setStroke()
        track.lineWidth = 10
        track.stroke()

        let value = CGFloat(max(0, min(100, percent ?? 0)))
        guard value > 0 else {
            return
        }
        let arc = NSBezierPath()
        arc.appendArc(withCenter: center, radius: radius, startAngle: 90, endAngle: 90 - 360 * value / 100, clockwise: true)
        color.withAlphaComponent(0.88).setStroke()
        arc.lineWidth = 10
        arc.lineCapStyle = .round
        arc.stroke()
    }

    private func drawCentered(_ text: String, y: CGFloat, color: NSColor) {
        let label = text as NSString
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .heavy),
            .foregroundColor: color,
        ]
        let size = label.size(withAttributes: attributes)
        label.draw(at: CGPoint(x: bounds.midX - size.width / 2, y: y), withAttributes: attributes)
    }

    private func drawLegend(color: NSColor, label: String, value: String, y: CGFloat) {
        color.setFill()
        NSBezierPath(ovalIn: NSRect(x: 8, y: y + 3, width: 6, height: 6)).fill()
        let text = "\(label) 重置" as NSString
        text.draw(
            at: CGPoint(x: 20, y: y),
            withAttributes: [
                .font: NSFont.systemFont(ofSize: 10, weight: .semibold),
                .foregroundColor: NSColor.black.withAlphaComponent(0.58),
            ]
        )
        (value as NSString).draw(
            at: CGPoint(x: 82, y: y),
            withAttributes: [
                .font: NSFont.monospacedSystemFont(ofSize: 10, weight: .medium),
                .foregroundColor: NSColor.black.withAlphaComponent(0.58),
            ]
        )
    }
}

final class DailyUsageChartView: NSView {
    private let buckets: [DailyUsageBucket]
    private var hoveredIndex: Int?

    init(buckets: [DailyUsageBucket]) {
        self.buckets = buckets
        super.init(frame: .zero)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach { removeTrackingArea($0) }
        addTrackingArea(
            NSTrackingArea(
                rect: bounds,
                options: [.mouseEnteredAndExited, .mouseMoved, .activeAlways, .inVisibleRect],
                owner: self,
                userInfo: nil
            )
        )
    }

    override func mouseMoved(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        hoveredIndex = barRects().firstIndex { $0.rect.insetBy(dx: -4, dy: -8).contains(point) }
        needsDisplay = true
    }

    override func mouseExited(with event: NSEvent) {
        hoveredIndex = nil
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        let background = NSBezierPath(roundedRect: bounds, xRadius: 7, yRadius: 7)
        NSColor.white.withAlphaComponent(0.54).setFill()
        background.fill()

        guard !buckets.isEmpty else {
            let text = "暂无" as NSString
            text.draw(
                at: CGPoint(x: bounds.midX - 13, y: bounds.midY - 7),
                withAttributes: [
                    .font: NSFont.systemFont(ofSize: 11, weight: .medium),
                    .foregroundColor: NSColor.black.withAlphaComponent(0.4),
                ]
            )
            return
        }

        drawGrid()
        let rects = barRects()
        for (index, item) in rects.enumerated() {
            let bar = NSBezierPath(roundedRect: item.rect, xRadius: 3, yRadius: 3)
            let isHovered = hoveredIndex == index
            let color = isHovered
                ? NSColor(calibratedRed: 0.12, green: 0.38, blue: 0.82, alpha: 0.96)
                : NSColor(calibratedRed: 0.40, green: 0.62, blue: 0.92, alpha: 0.82)
            color.setFill()
            bar.fill()

            if index % 3 == 0 || index == rects.count - 1 {
                drawAxisLabel(TimeText.monthDay(item.bucket.startDate), x: item.rect.midX)
            }
        }

        if let hoveredIndex, hoveredIndex < rects.count {
            drawTooltip(for: rects[hoveredIndex])
        }
    }

    private func chartRect() -> NSRect {
        bounds.insetBy(dx: 10, dy: 18).offsetBy(dx: 0, dy: 6)
    }

    private func barRects() -> [(rect: NSRect, bucket: DailyUsageBucket)] {
        guard !buckets.isEmpty else {
            return []
        }
        let chart = chartRect()
        let maxTokens = max(1, buckets.map(\.tokens).max() ?? 1)
        let gap: CGFloat = 5
        let width = max(8, (chart.width - CGFloat(buckets.count - 1) * gap) / CGFloat(buckets.count))
        return buckets.enumerated().map { index, bucket in
            let ratio = CGFloat(bucket.tokens) / CGFloat(maxTokens)
            let height = max(4, chart.height * ratio)
            let x = chart.minX + CGFloat(index) * (width + gap)
            let y = chart.minY
            return (NSRect(x: x, y: y, width: width, height: height), bucket)
        }
    }

    private func drawGrid() {
        let chart = chartRect()
        NSColor.black.withAlphaComponent(0.10).setStroke()
        for step in 0...2 {
            let y = chart.minY + chart.height * CGFloat(step) / 2
            let line = NSBezierPath()
            line.move(to: CGPoint(x: chart.minX, y: y))
            line.line(to: CGPoint(x: chart.maxX, y: y))
            line.lineWidth = 0.7
            line.stroke()
        }
    }

    private func drawAxisLabel(_ text: String, x: CGFloat) {
        let label = text as NSString
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 8.5, weight: .medium),
            .foregroundColor: NSColor.black.withAlphaComponent(0.45),
        ]
        let size = label.size(withAttributes: attributes)
        label.draw(
            at: CGPoint(x: x - size.width / 2, y: bounds.minY + 3),
            withAttributes: attributes
        )
    }

    private func drawTooltip(for item: (rect: NSRect, bucket: DailyUsageBucket)) {
        let text = "\(TimeText.monthDay(item.bucket.startDate)) · \(TokenText.compact(item.bucket.tokens)) token" as NSString
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 10, weight: .bold),
            .foregroundColor: NSColor.white,
        ]
        let size = text.size(withAttributes: attributes)
        let width = min(bounds.width - 16, size.width + 16)
        let x = min(max(bounds.minX + 8, item.rect.midX - width / 2), bounds.maxX - width - 8)
        let y = min(bounds.maxY - 26, item.rect.maxY + 6)
        let bubble = NSRect(x: x, y: y, width: width, height: 22)
        NSColor(calibratedWhite: 0.10, alpha: 0.90).setFill()
        NSBezierPath(roundedRect: bubble, xRadius: 7, yRadius: 7).fill()
        text.draw(at: CGPoint(x: bubble.minX + 8, y: bubble.minY + 5), withAttributes: attributes)
    }
}

final class TokenSplitBarView: NSView {
    private let total: TokenUsageTotals

    init(total: TokenUsageTotals) {
        self.total = total
        super.init(frame: .zero)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        let outline = NSBezierPath(roundedRect: bounds, xRadius: 8, yRadius: 8)
        NSColor.white.withAlphaComponent(0.52).setFill()
        outline.fill()

        let denominator = max(1, total.inputTokens + total.outputTokens + total.reasoningOutputTokens)
        var x = bounds.minX
        let segments: [(Int, NSColor)] = [
            (max(0, total.inputTokens - total.cachedInputTokens), NSColor(calibratedRed: 0.33, green: 0.71, blue: 0.98, alpha: 0.9)),
            (total.cachedInputTokens, NSColor(calibratedRed: 0.28, green: 0.82, blue: 0.48, alpha: 0.9)),
            (total.outputTokens, NSColor(calibratedRed: 0.98, green: 0.62, blue: 0.34, alpha: 0.9)),
            (total.reasoningOutputTokens, NSColor(calibratedRed: 0.65, green: 0.48, blue: 0.96, alpha: 0.9)),
        ]
        for (value, color) in segments where value > 0 {
            let width = bounds.width * CGFloat(value) / CGFloat(denominator)
            let rect = NSRect(x: x, y: bounds.minY, width: width, height: bounds.height)
            color.setFill()
            NSBezierPath(rect: rect).fill()
            x += width
        }

        NSColor.black.withAlphaComponent(0.18).setStroke()
        outline.lineWidth = 1
        outline.stroke()
    }
}

final class PixelBarView: NSView {
    private let percent: Int
    private let color: NSColor

    init(percent: Int, color: NSColor) {
        self.percent = max(0, min(100, percent))
        self.color = color
        super.init(frame: .zero)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        let outline = NSBezierPath(roundedRect: bounds, xRadius: 8, yRadius: 8)
        NSColor.white.withAlphaComponent(0.48).setFill()
        outline.fill()
        NSColor.black.withAlphaComponent(0.22).setStroke()
        outline.lineWidth = 1
        outline.stroke()

        let width = bounds.width * CGFloat(percent) / 100
        let fillRect = NSRect(x: bounds.minX + 2, y: bounds.minY + 2, width: max(0, width - 4), height: bounds.height - 4)
        let fill = NSBezierPath(roundedRect: fillRect, xRadius: 6, yRadius: 6)
        color.withAlphaComponent(0.88).setFill()
        fill.fill()

        NSColor.white.withAlphaComponent(0.42).setFill()
        for x in stride(from: fillRect.minX + 8, to: fillRect.maxX, by: 18) {
            NSBezierPath(ovalIn: NSRect(x: x, y: fillRect.midY, width: 3, height: 3)).fill()
        }
    }
}

final class ProfileBadgeView: NSView {
    private let name: String
    private let index: Int

    init(name: String, index: Int) {
        self.name = name
        self.index = index
        super.init(frame: .zero)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        let rect = bounds.insetBy(dx: 3, dy: 3)
        let path = NSBezierPath(roundedRect: rect, xRadius: 14, yRadius: 14)
        let colors = index % 2 == 0
            ? [
                NSColor(calibratedRed: 0.46, green: 0.90, blue: 0.85, alpha: 1),
                NSColor(calibratedRed: 0.38, green: 0.62, blue: 1.0, alpha: 1),
            ]
            : [
                NSColor(calibratedRed: 0.97, green: 0.64, blue: 0.88, alpha: 1),
                NSColor(calibratedRed: 0.60, green: 0.62, blue: 1.0, alpha: 1),
            ]
        NSGradient(colors: colors)?.draw(in: path, angle: 315)
        NSColor.white.withAlphaComponent(0.72).setStroke()
        path.lineWidth = 2
        path.stroke()

        let label = initials(from: name) as NSString
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 16, weight: .heavy),
            .foregroundColor: NSColor.white,
        ]
        let size = label.size(withAttributes: attributes)
        label.draw(
            at: CGPoint(x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2 - 1),
            withAttributes: attributes
        )
    }

    private func initials(from value: String) -> String {
        let parts = value
            .split(separator: "-")
            .filter { !$0.isEmpty && $0.lowercased() != "hd" }
        let source = parts.isEmpty ? value.split(separator: "-") : parts
        let initials = source.prefix(2).compactMap { $0.first }.map { String($0).uppercased() }.joined()
        return initials.isEmpty ? "C" : initials
    }
}

final class ActionRowView: NSView {
    private let action: () -> Void
    private let isRowEnabled: Bool
    private var isHovering = false

    init(icon: String, title: String, isEnabled: Bool, action: @escaping () -> Void) {
        self.action = action
        self.isRowEnabled = isEnabled
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(equalToConstant: 38).isActive = true
        wantsLayer = true

        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 6
        row.alignment = .centerY
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)

        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            row.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])

        let iconLabel = NSTextField(labelWithString: icon)
        iconLabel.font = NSFont.systemFont(ofSize: 15)
        iconLabel.translatesAutoresizingMaskIntoConstraints = false
        iconLabel.widthAnchor.constraint(equalToConstant: 18).isActive = true

        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = NSFont.systemFont(ofSize: 11.5, weight: .semibold)
        titleLabel.textColor = isEnabled ? NSColor.black.withAlphaComponent(0.78) : NSColor.black.withAlphaComponent(0.36)
        titleLabel.lineBreakMode = .byTruncatingTail

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        row.addArrangedSubview(iconLabel)
        row.addArrangedSubview(titleLabel)
        row.addArrangedSubview(spacer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach { removeTrackingArea($0) }
        addTrackingArea(
            NSTrackingArea(
                rect: bounds,
                options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                owner: self,
                userInfo: nil
            )
        )
    }

    override func mouseEntered(with event: NSEvent) {
        guard isRowEnabled else {
            return
        }
        isHovering = true
        needsDisplay = true
    }

    override func mouseExited(with event: NSEvent) {
        isHovering = false
        needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) {
        guard isRowEnabled else {
            return
        }
        action()
    }

    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 10, yRadius: 10)
        NSColor.white.withAlphaComponent(isHovering ? 0.58 : 0.34).setFill()
        path.fill()
        NSColor.white.withAlphaComponent(0.50).setStroke()
        path.lineWidth = 1
        path.stroke()
    }
}

final class ColorDotView: NSView {
    private let color: NSColor

    init(color: NSColor) {
        self.color = color
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        color.setFill()
        NSBezierPath(ovalIn: bounds).fill()
    }
}

let app = NSApplication.shared
let delegate = CodexProfileMenuBarApp()
app.delegate = delegate
app.run()

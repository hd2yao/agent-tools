import AppKit
import Foundation

struct DashboardPayload: Decodable {
    let generatedAt: String
    let activeProfile: String?
    let runtimeStatus: RuntimeStatus?
    let desktopStatus: DesktopStatus?
    let localSnapshot: LocalTokenSnapshot?
    let profiles: [ProfileStatus]

    enum CodingKeys: String, CodingKey {
        case generatedAt = "generated_at"
        case activeProfile = "active_profile"
        case runtimeStatus = "runtime_status"
        case desktopStatus = "desktop_status"
        case localSnapshot = "local_snapshot"
        case profiles
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
    let usage: AccountUsage?
    let remoteStale: Bool?
    let remoteError: String?

    enum CodingKeys: String, CodingKey {
        case name
        case auth
        case config
        case rateLimits = "rate_limits"
        case usage
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

enum ManagerPage {
    case quota
    case token
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
    private var currentPage: ManagerPage = .quota

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
        popover.contentSize = NSSize(width: 460, height: 920)
    }

    private func startAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.refreshStatus(showProgress: false)
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
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            startPopoverDismissMonitors()
        }
    }

    @objc private func refreshStatus(_ sender: Any?) {
        refreshStatus(showProgress: true)
    }

    private func refreshStatus(showProgress: Bool) {
        if isRefreshing {
            return
        }
        isRefreshing = true
        latestError = nil
        if showProgress {
            updatePopover(message: "正在刷新 Codex 账号...")
        }
        DispatchQueue.global(qos: .userInitiated).async {
            let result = Self.runPython(arguments: ["status", "--json"])
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
        popover.contentViewController = AccountManagerViewController(
            payload: latestPayload,
            message: message ?? latestError,
            isRefreshing: isRefreshing,
            page: currentPage,
            setPageAction: { [weak self] page in
                self?.currentPage = page
                self?.updatePopover()
            },
            refreshAction: { [weak self] in self?.refreshStatus(nil) },
            launchAction: { [weak self] in self?.launchActiveProfile() },
            quitAction: { NSApp.terminate(nil) },
            switchAction: { [weak self] name in self?.switchProfile(name) }
        )
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
                    self.refreshStatus(showProgress: false)
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

final class AccountManagerViewController: NSViewController {
    private let payload: DashboardPayload?
    private let message: String?
    private let isRefreshing: Bool
    private let page: ManagerPage
    private let setPageAction: (ManagerPage) -> Void
    private let refreshAction: () -> Void
    private let launchAction: () -> Void
    private let quitAction: () -> Void
    private let switchAction: (String) -> Void

    init(
        payload: DashboardPayload?,
        message: String?,
        isRefreshing: Bool,
        page: ManagerPage,
        setPageAction: @escaping (ManagerPage) -> Void,
        refreshAction: @escaping () -> Void,
        launchAction: @escaping () -> Void,
        quitAction: @escaping () -> Void,
        switchAction: @escaping (String) -> Void
    ) {
        self.payload = payload
        self.message = message
        self.isRefreshing = isRefreshing
        self.page = page
        self.setPageAction = setPageAction
        self.refreshAction = refreshAction
        self.launchAction = launchAction
        self.quitAction = quitAction
        self.switchAction = switchAction
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = AccountManagerView(frame: NSRect(x: 0, y: 0, width: 460, height: 920))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        build()
    }

    private func build() {
        guard let root = view as? AccountManagerView else {
            return
        }

        let content = NSStackView()
        content.orientation = .vertical
        content.spacing = 14
        content.alignment = .leading
        content.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(content)

        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 18),
            content.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -18),
            content.topAnchor.constraint(equalTo: root.topAnchor, constant: 18),
            content.bottomAnchor.constraint(lessThanOrEqualTo: root.bottomAnchor, constant: -16),
        ])

        content.addArrangedSubview(headerView())
        content.addArrangedSubview(pageToggle())

        if let message {
            content.addArrangedSubview(messageView(message))
        }

        if let payload {
            switch page {
            case .quota:
                for (index, profile) in payload.profiles.enumerated() {
                    content.addArrangedSubview(
                        AccountCardView(
                            profile: profile,
                            index: index,
                            isActive: payload.activeProfile == profile.name,
                            switchAction: switchAction
                        )
                    )
                }
            case .token:
                content.addArrangedSubview(TokenDashboardView(payload: payload))
            }
        }

        content.addArrangedSubview(actionRow())
    }

    private func pageToggle() -> NSView {
        PageToggleView(
            activePage: page,
            quotaAction: { self.setPageAction(.quota) },
            tokenAction: { self.setPageAction(.token) }
        )
    }

    private func headerView() -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 6
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.widthAnchor.constraint(equalToConstant: 424).isActive = true

        let title = NSTextField(labelWithString: "CODEX 账号管家")
        title.font = NSFont.systemFont(ofSize: 18, weight: .heavy)
        title.textColor = NSColor(calibratedRed: 0.06, green: 0.18, blue: 0.17, alpha: 1)
        title.alignment = .left

        let updated = NSTextField(labelWithString: "更新：\(TimeText.beijingFull(payload?.generatedAt))")
        updated.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .medium)
        updated.textColor = NSColor(calibratedWhite: 0.18, alpha: 1)
        updated.alignment = .left

        let lights = trafficLights()

        stack.addArrangedSubview(title)
        stack.addArrangedSubview(updated)
        stack.addArrangedSubview(lights)
        stack.addArrangedSubview(desktopStatusView())
        return stack
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

    private func desktopStatusView() -> NSView {
        let label = NSTextField(labelWithString: desktopStatusText())
        label.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        label.textColor = desktopStatusColor()
        label.alignment = .left
        label.lineBreakMode = .byTruncatingTail
        label.translatesAutoresizingMaskIntoConstraints = false
        label.widthAnchor.constraint(equalToConstant: 424).isActive = true
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
        label.widthAnchor.constraint(equalToConstant: 424).isActive = true
        return label
    }

    private func actionRow() -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 2
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.widthAnchor.constraint(equalToConstant: 424).isActive = true
        stack.addArrangedSubview(
            ActionRowView(
                icon: "💨",
                title: isRefreshing ? "刷新中..." : "刷新",
                isEnabled: !isRefreshing,
                action: refreshAction
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
                icon: "🚪",
                title: "退出账号管家",
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
            return "用当前账号打开 Codex"
        }
        if status.state == "managed_default_home" {
            return "重启当前账号 Codex"
        }
        if status.running {
            return "接管并重启 Codex"
        }
        return "用当前账号打开 Codex"
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
            NSColor(calibratedRed: 0.74, green: 0.97, blue: 0.84, alpha: 1),
            NSColor(calibratedRed: 0.74, green: 0.9, blue: 1.0, alpha: 1),
            NSColor(calibratedRed: 0.82, green: 0.78, blue: 1.0, alpha: 1),
        ])
        gradient?.draw(in: bounds, angle: 315)
        drawPattern()
    }

    private func drawPattern() {
        let symbols = ["C", "{ }", "♥", "+", "⚡"]
        let color = NSColor.white.withAlphaComponent(0.26)
        for row in stride(from: 18, to: Int(bounds.height), by: 48) {
            for col in stride(from: 20, to: Int(bounds.width), by: 82) {
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

final class PageToggleView: NSView {
    init(activePage: ManagerPage, quotaAction: @escaping () -> Void, tokenAction: @escaping () -> Void) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        widthAnchor.constraint(equalToConstant: 424).isActive = true
        heightAnchor.constraint(equalToConstant: 34).isActive = true
        wantsLayer = true

        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 4
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)

        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 3),
            row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -3),
            row.topAnchor.constraint(equalTo: topAnchor, constant: 3),
            row.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -3),
        ])

        row.addArrangedSubview(
            PageToggleButtonView(title: "额度", isActive: activePage == .quota, action: quotaAction)
        )
        row.addArrangedSubview(
            PageToggleButtonView(title: "Token 分析", isActive: activePage == .token, action: tokenAction)
        )
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.white.withAlphaComponent(0.36).setFill()
        NSBezierPath(roundedRect: bounds, xRadius: 12, yRadius: 12).fill()
    }
}

final class PageToggleButtonView: NSView {
    private let title: String
    private let isActive: Bool
    private let action: () -> Void

    init(title: String, isActive: Bool, action: @escaping () -> Void) {
        self.title = title
        self.isActive = isActive
        self.action = action
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        widthAnchor.constraint(equalToConstant: 207).isActive = true
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func mouseDown(with event: NSEvent) {
        action()
    }

    override func draw(_ dirtyRect: NSRect) {
        if isActive {
            NSColor(calibratedRed: 0.10, green: 0.28, blue: 0.25, alpha: 0.88).setFill()
        } else {
            NSColor.white.withAlphaComponent(0.18).setFill()
        }
        NSBezierPath(roundedRect: bounds, xRadius: 10, yRadius: 10).fill()

        let text = title as NSString
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: .bold),
            .foregroundColor: isActive ? NSColor.white : NSColor.black.withAlphaComponent(0.66),
        ]
        let size = text.size(withAttributes: attributes)
        text.draw(
            at: CGPoint(x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2),
            withAttributes: attributes
        )
    }
}

final class AccountCardView: NSView {
    private let profile: ProfileStatus
    private let index: Int
    private let isActive: Bool
    private let switchAction: (String) -> Void

    init(profile: ProfileStatus, index: Int, isActive: Bool, switchAction: @escaping (String) -> Void) {
        self.profile = profile
        self.index = index
        self.isActive = isActive
        self.switchAction = switchAction
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        widthAnchor.constraint(equalToConstant: 424).isActive = true
        heightAnchor.constraint(equalToConstant: 210).isActive = true
        wantsLayer = true
        layer?.cornerRadius = 18
        layer?.borderColor = NSColor.white.withAlphaComponent(0.75).cgColor
        layer?.borderWidth = 1
        build()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(roundedRect: bounds, xRadius: 18, yRadius: 18)
        let top = index % 2 == 0
            ? NSColor(calibratedRed: 0.9, green: 1.0, blue: 0.96, alpha: 0.94)
            : NSColor(calibratedRed: 1.0, green: 0.94, blue: 1.0, alpha: 0.94)
        top.setFill()
        path.fill()
    }

    private func build() {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -12),
        ])

        stack.addArrangedSubview(titleRow())
        stack.addArrangedSubview(barRow(label: "5小时额度", window: profile.rateLimits.primary))
        stack.addArrangedSubview(barRow(label: "7天额度", window: profile.rateLimits.secondary))
        stack.addArrangedSubview(footerRow())
    }

    private func titleRow() -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 10
        row.alignment = .centerY

        let avatar = ProfileBadgeView(name: profile.name, index: index)
        avatar.translatesAutoresizingMaskIntoConstraints = false
        avatar.widthAnchor.constraint(equalToConstant: 58).isActive = true
        avatar.heightAnchor.constraint(equalToConstant: 50).isActive = true
        row.addArrangedSubview(avatar)

        let text = NSStackView()
        text.orientation = .vertical
        text.spacing = 2
        text.alignment = .leading

        let name = NSTextField(labelWithString: profile.name)
        name.font = NSFont.systemFont(ofSize: 20, weight: .heavy)
        name.textColor = NSColor.black
        name.alignment = .left
        name.lineBreakMode = .byTruncatingTail

        let staleSuffix = profile.remoteStale == true ? " · 暂存" : ""
        let plan = NSTextField(labelWithString: "套餐：\(profile.rateLimits.planType?.uppercased() ?? "UNKNOWN")\(staleSuffix)")
        plan.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .bold)
        plan.textColor = NSColor(calibratedRed: 0.14, green: 0.28, blue: 0.46, alpha: 1)
        plan.alignment = .left

        text.addArrangedSubview(name)
        text.addArrangedSubview(plan)
        row.addArrangedSubview(text)

        let spacer = NSView()
        row.addArrangedSubview(spacer)
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        if isActive {
            let badge = NSTextField(labelWithString: "当前")
            badge.font = NSFont.systemFont(ofSize: 12, weight: .bold)
            badge.textColor = NSColor(calibratedRed: 0.1, green: 0.33, blue: 0.28, alpha: 1)
            badge.alignment = .center
            badge.wantsLayer = true
            badge.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.55).cgColor
            badge.layer?.cornerRadius = 8
            badge.translatesAutoresizingMaskIntoConstraints = false
            badge.widthAnchor.constraint(equalToConstant: 42).isActive = true
            badge.heightAnchor.constraint(equalToConstant: 22).isActive = true
            row.addArrangedSubview(badge)
        }
        return row
    }

    private func barRow(label: String, window: RateLimitWindow?) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 10
        row.alignment = .centerY

        let title = NSTextField(labelWithString: label)
        title.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        title.textColor = NSColor.black
        title.translatesAutoresizingMaskIntoConstraints = false
        title.widthAnchor.constraint(equalToConstant: 82).isActive = true

        let remaining = window?.remainingPercent
        let bar = PixelBarView(percent: remaining ?? 0, color: AccountHealth(remaining: remaining).color)
        bar.translatesAutoresizingMaskIntoConstraints = false
        bar.widthAnchor.constraint(equalToConstant: 218).isActive = true
        bar.heightAnchor.constraint(equalToConstant: 20).isActive = true

        let value = NSTextField(labelWithString: "\(remaining.map { "\($0)%" } ?? "--") 剩余")
        value.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .bold)
        value.textColor = NSColor.black
        value.alignment = .right
        value.translatesAutoresizingMaskIntoConstraints = false
        value.widthAnchor.constraint(equalToConstant: 76).isActive = true

        row.addArrangedSubview(title)
        row.addArrangedSubview(bar)
        row.addArrangedSubview(value)
        return row
    }

    private func footerRow() -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 10
        row.alignment = .centerY

        let primary = profile.rateLimits.primary?.remainingPercent
        let usage = usageLabel(remaining: primary)
        let primaryReset = TimeText.beijingHourMinute(profile.rateLimits.primary?.resetsAt)
        let secondaryReset = TimeText.beijingMonthDay(profile.rateLimits.secondary?.resetsAt)

        let details = NSStackView()
        details.orientation = .vertical
        details.spacing = 2
        details.alignment = .leading
        details.translatesAutoresizingMaskIntoConstraints = false
        details.widthAnchor.constraint(equalToConstant: 294).isActive = true

        details.addArrangedSubview(infoLine(label: "使用：", value: usage, valueWeight: .semibold))
        details.addArrangedSubview(
            infoLine(
                label: "重置：",
                value: "5小时 \(primaryReset) · 7天 \(secondaryReset)",
                valueWeight: .medium,
                valueAlpha: 0.72
            )
        )
        details.addArrangedSubview(
            infoLine(
                label: "重置机会：",
                value: resetCreditsText(),
                valueWeight: .medium,
                valueAlpha: 0.72
            )
        )
        row.addArrangedSubview(details)

        let button = NSButton(title: isActive ? "已部署 ✓" : "切过去!", target: self, action: #selector(switchTapped))
        button.bezelStyle = .rounded
        button.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .heavy)
        button.isEnabled = !isActive
        button.translatesAutoresizingMaskIntoConstraints = false
        button.widthAnchor.constraint(equalToConstant: 92).isActive = true
        row.addArrangedSubview(button)

        return row
    }

    private func resetCreditsText() -> String {
        guard let credits = profile.rateLimits.resetCredits, credits.available == true else {
            return "未提供"
        }
        if credits.unlimited == true {
            return "不限"
        }
        let countText = credits.availableCount.map { "\($0) 次" } ?? "--"
        if let expiresAt = credits.expiresAt {
            return "\(countText) · \(TimeText.beijingMonthDay(expiresAt))到期"
        }
        return "\(countText)可用"
    }

    private func infoLine(
        label: String,
        value: String,
        valueWeight: NSFont.Weight,
        valueAlpha: CGFloat = 1
    ) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 8
        row.alignment = .firstBaseline
        row.translatesAutoresizingMaskIntoConstraints = false
        row.widthAnchor.constraint(equalToConstant: 294).isActive = true

        let title = NSTextField(labelWithString: label)
        title.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        title.textColor = NSColor.black
        title.alignment = .left
        title.translatesAutoresizingMaskIntoConstraints = false
        title.widthAnchor.constraint(equalToConstant: 82).isActive = true

        let detail = NSTextField(labelWithString: value)
        detail.font = NSFont.systemFont(ofSize: 12, weight: valueWeight)
        detail.textColor = NSColor.black.withAlphaComponent(valueAlpha)
        detail.alignment = .left
        detail.lineBreakMode = .byTruncatingTail
        detail.translatesAutoresizingMaskIntoConstraints = false
        detail.widthAnchor.constraint(equalToConstant: 204).isActive = true

        row.addArrangedSubview(title)
        row.addArrangedSubview(detail)
        return row
    }

    @objc private func switchTapped() {
        switchAction(profile.name)
    }

    private func usageLabel(remaining: Int?) -> String {
        guard let remaining else {
            return "未知"
        }
        if remaining < 35 {
            return "偏高"
        }
        if remaining < 70 {
            return "中等"
        }
        return "充足"
    }
}

final class TokenDashboardView: NSView {
    private let payload: DashboardPayload

    init(payload: DashboardPayload) {
        self.payload = payload
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        widthAnchor.constraint(equalToConstant: 424).isActive = true
        heightAnchor.constraint(equalToConstant: 560).isActive = true
        build()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func build() {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 10
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor),
        ])

        let title = NSTextField(labelWithString: "Token 分析")
        title.font = NSFont.systemFont(ofSize: 16, weight: .heavy)
        title.textColor = NSColor.black.withAlphaComponent(0.82)
        title.alignment = .left
        stack.addArrangedSubview(title)

        for (index, profile) in payload.profiles.enumerated() {
            stack.addArrangedSubview(AccountTokenCardView(profile: profile, index: index))
        }

        if let snapshot = payload.localSnapshot {
            stack.addArrangedSubview(TokenSummaryView(snapshot: snapshot))
        }
    }
}

final class AccountTokenCardView: NSView {
    private let profile: ProfileStatus
    private let index: Int

    init(profile: ProfileStatus, index: Int) {
        self.profile = profile
        self.index = index
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        widthAnchor.constraint(equalToConstant: 424).isActive = true
        heightAnchor.constraint(equalToConstant: 164).isActive = true
        wantsLayer = true
        layer?.cornerRadius = 16
        layer?.borderColor = NSColor.white.withAlphaComponent(0.70).cgColor
        layer?.borderWidth = 1
        build()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(roundedRect: bounds, xRadius: 16, yRadius: 16)
        let color = index % 2 == 0
            ? NSColor(calibratedRed: 0.92, green: 1.0, blue: 0.97, alpha: 0.94)
            : NSColor(calibratedRed: 1.0, green: 0.95, blue: 1.0, alpha: 0.94)
        color.setFill()
        path.fill()
    }

    private func build() {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -12),
        ])

        stack.addArrangedSubview(headerRow())

        let buckets = Array((profile.usage?.dailyUsageBuckets ?? []).suffix(14))
        let chart = DailyUsageChartView(buckets: buckets)
        chart.translatesAutoresizingMaskIntoConstraints = false
        chart.widthAnchor.constraint(equalToConstant: 396).isActive = true
        chart.heightAnchor.constraint(equalToConstant: 82).isActive = true
        stack.addArrangedSubview(chart)

        stack.addArrangedSubview(metricsRow(buckets: buckets))
    }

    private func headerRow() -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 8
        row.translatesAutoresizingMaskIntoConstraints = false
        row.widthAnchor.constraint(equalToConstant: 396).isActive = true

        let name = NSTextField(labelWithString: profile.name)
        name.font = NSFont.systemFont(ofSize: 14, weight: .heavy)
        name.textColor = NSColor.black.withAlphaComponent(0.86)
        name.lineBreakMode = .byTruncatingTail
        row.addArrangedSubview(name)

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        row.addArrangedSubview(spacer)

        let total = tokenTotal(Array((profile.usage?.dailyUsageBuckets ?? []).suffix(14)))
        let value = NSTextField(labelWithString: "近14日 \(TokenText.compact(total))")
        value.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .bold)
        value.textColor = NSColor.black.withAlphaComponent(0.72)
        row.addArrangedSubview(value)
        return row
    }

    private func metricsRow(buckets: [DailyUsageBucket]) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 14
        row.alignment = .centerY
        row.translatesAutoresizingMaskIntoConstraints = false
        row.widthAnchor.constraint(equalToConstant: 396).isActive = true

        let latest = buckets.last?.tokens
        let peak = buckets.map(\.tokens).max()
        let streak = profile.usage?.summary?.currentStreakDays
        let lifetime = profile.usage?.summary?.lifetimeTokens
        for text in [
            "今日 \(TokenText.compact(latest))",
            "峰值 \(TokenText.compact(peak))",
            "连续 \(streak.map { "\($0)天" } ?? "--")",
            "累计 \(TokenText.compact(lifetime))",
        ] {
            let label = NSTextField(labelWithString: text)
            label.font = NSFont.monospacedSystemFont(ofSize: 10.5, weight: .medium)
            label.textColor = NSColor.black.withAlphaComponent(0.60)
            row.addArrangedSubview(label)
        }
        return row
    }

    private func tokenTotal(_ buckets: [DailyUsageBucket]) -> Int {
        buckets.reduce(0) { $0 + $1.tokens }
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

final class TokenSummaryView: NSView {
    private let snapshot: LocalTokenSnapshot

    init(snapshot: LocalTokenSnapshot) {
        self.snapshot = snapshot
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        widthAnchor.constraint(equalToConstant: 424).isActive = true
        heightAnchor.constraint(equalToConstant: 104).isActive = true
        wantsLayer = true
        layer?.cornerRadius = 16
        layer?.borderColor = NSColor.white.withAlphaComponent(0.65).cgColor
        layer?.borderWidth = 1
        build()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(roundedRect: bounds, xRadius: 16, yRadius: 16)
        NSColor.white.withAlphaComponent(0.42).setFill()
        path.fill()
    }

    private func build() {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 7
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])

        let total = displayTotal()
        let title = NSTextField(labelWithString: "本地14日拆分（共享） · \(TokenText.compact(total.totalTokens))")
        title.font = NSFont.systemFont(ofSize: 13, weight: .heavy)
        title.textColor = NSColor.black.withAlphaComponent(0.78)
        stack.addArrangedSubview(title)

        let chart = TokenSplitBarView(total: total)
        chart.translatesAutoresizingMaskIntoConstraints = false
        chart.widthAnchor.constraint(equalToConstant: 396).isActive = true
        chart.heightAnchor.constraint(equalToConstant: 22).isActive = true
        stack.addArrangedSubview(chart)

        let detail = NSTextField(labelWithString: tokenBreakdownText())
        detail.font = NSFont.monospacedSystemFont(ofSize: 10.5, weight: .medium)
        detail.textColor = NSColor.black.withAlphaComponent(0.62)
        detail.lineBreakMode = .byTruncatingTail
        detail.translatesAutoresizingMaskIntoConstraints = false
        detail.widthAnchor.constraint(equalToConstant: 396).isActive = true
        stack.addArrangedSubview(detail)
    }

    private func tokenBreakdownText() -> String {
        let total = displayTotal()
        return [
            "输入 \(TokenText.compact(total.inputTokens))",
            "缓存 \(TokenText.compact(total.cachedInputTokens))",
            "输出 \(TokenText.compact(total.outputTokens))",
            "推理 \(TokenText.compact(total.reasoningOutputTokens))",
        ].joined(separator: " · ")
    }

    private func displayTotal() -> TokenUsageTotals {
        guard let daily = snapshot.daily, !daily.isEmpty else {
            return snapshot.total
        }
        return daily.reduce(
            TokenUsageTotals(
                inputTokens: 0,
                cachedInputTokens: 0,
                outputTokens: 0,
                reasoningOutputTokens: 0,
                totalTokens: 0
            )
        ) { partial, item in
            TokenUsageTotals(
                inputTokens: partial.inputTokens + item.inputTokens,
                cachedInputTokens: partial.cachedInputTokens + item.cachedInputTokens,
                outputTokens: partial.outputTokens + item.outputTokens,
                reasoningOutputTokens: partial.reasoningOutputTokens + item.reasoningOutputTokens,
                totalTokens: partial.totalTokens + item.totalTokens
            )
        }
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
        NSColor(calibratedWhite: 0.98, alpha: 0.75).setFill()
        outline.fill()
        NSColor(calibratedWhite: 0.15, alpha: 0.8).setStroke()
        outline.lineWidth = 2
        outline.stroke()

        let width = bounds.width * CGFloat(percent) / 100
        let fillRect = NSRect(x: bounds.minX + 3, y: bounds.minY + 3, width: max(0, width - 6), height: bounds.height - 6)
        let fill = NSBezierPath(roundedRect: fillRect, xRadius: 6, yRadius: 6)
        color.withAlphaComponent(0.8).setFill()
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
        heightAnchor.constraint(equalToConstant: 36).isActive = true
        wantsLayer = true

        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 10
        row.alignment = .centerY
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)

        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            row.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])

        let iconLabel = NSTextField(labelWithString: icon)
        iconLabel.font = NSFont.systemFont(ofSize: 20)
        iconLabel.translatesAutoresizingMaskIntoConstraints = false
        iconLabel.widthAnchor.constraint(equalToConstant: 28).isActive = true

        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = NSFont.systemFont(ofSize: 15, weight: .semibold)
        titleLabel.textColor = isEnabled ? NSColor.black.withAlphaComponent(0.78) : NSColor.black.withAlphaComponent(0.36)

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
        guard isHovering else {
            return
        }
        NSColor.white.withAlphaComponent(0.38).setFill()
        NSBezierPath(roundedRect: bounds.insetBy(dx: 2, dy: 2), xRadius: 10, yRadius: 10).fill()
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

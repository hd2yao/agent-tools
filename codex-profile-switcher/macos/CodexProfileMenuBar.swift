import AppKit
import Foundation

struct DashboardPayload: Decodable {
    let generatedAt: String
    let activeProfile: String?
    let runtimeStatus: RuntimeStatus?
    let profiles: [ProfileStatus]

    enum CodingKeys: String, CodingKey {
        case generatedAt = "generated_at"
        case activeProfile = "active_profile"
        case runtimeStatus = "runtime_status"
        case profiles
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
    let remoteError: String?

    enum CodingKeys: String, CodingKey {
        case name
        case auth
        case config
        case rateLimits = "rate_limits"
        case remoteError = "remote_error"
    }
}

struct RateLimits: Decodable {
    let available: Bool
    let limitID: String?
    let planType: String?
    let creditsAvailable: Int?
    let primary: RateLimitWindow?
    let secondary: RateLimitWindow?

    enum CodingKeys: String, CodingKey {
        case available
        case limitID = "limit_id"
        case planType = "plan_type"
        case creditsAvailable = "credits_available"
        case primary
        case secondary
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

enum TimeText {
    static func beijingShort(_ value: String?) -> String {
        guard let value else {
            return "--"
        }
        let parser = ISO8601DateFormatter()
        if let date = parser.date(from: value) {
            return beijingShort(date)
        }
        return value
    }

    static func beijingShort(_ timestamp: TimeInterval?) -> String {
        guard let timestamp else {
            return "--"
        }
        return beijingShort(Date(timeIntervalSince1970: timestamp))
    }

    private static func beijingShort(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
        formatter.dateFormat = "yy年M月d日 HH:mm"
        return formatter.string(from: date)
    }
}

final class CodexProfileMenuBarApp: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()
    private var latestPayload: DashboardPayload?
    private var latestError: String?
    private var isRefreshing = false
    private var refreshTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configureStatusItem()
        configurePopover()
        updatePopover()
        refreshStatus(nil)
        startAutoRefresh()
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
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
        popover.contentSize = NSSize(width: 460, height: 560)
    }

    private func startAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.refreshStatus(nil)
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
        }
    }

    @objc private func refreshStatus(_ sender: Any?) {
        if isRefreshing {
            return
        }
        isRefreshing = true
        statusItem.button?.image = makeStatusIcon(color: RuntimeLight.unknown.color)
        statusItem.button?.title = " ... ⚪️"
        latestError = nil
        updatePopover(message: "正在刷新 Codex 账号...")
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
            refreshAction: { [weak self] in self?.refreshStatus(nil) },
            quitAction: { NSApp.terminate(nil) },
            switchAction: { [weak self] name in self?.switchProfile(name) }
        )
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
                    self.refreshStatus(nil)
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
        let message = errorOutput.split(separator: "\n").first.map(String.init) ?? "Command failed."
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
    private let refreshAction: () -> Void
    private let quitAction: () -> Void
    private let switchAction: (String) -> Void

    init(
        payload: DashboardPayload?,
        message: String?,
        isRefreshing: Bool,
        refreshAction: @escaping () -> Void,
        quitAction: @escaping () -> Void,
        switchAction: @escaping (String) -> Void
    ) {
        self.payload = payload
        self.message = message
        self.isRefreshing = isRefreshing
        self.refreshAction = refreshAction
        self.quitAction = quitAction
        self.switchAction = switchAction
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = AccountManagerView(frame: NSRect(x: 0, y: 0, width: 460, height: 560))
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

        if let message {
            content.addArrangedSubview(messageView(message))
        }

        if let payload {
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
        }

        content.addArrangedSubview(actionRow())
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

        let updated = NSTextField(labelWithString: "更新：\(TimeText.beijingShort(payload?.generatedAt))")
        updated.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .medium)
        updated.textColor = NSColor(calibratedWhite: 0.18, alpha: 1)
        updated.alignment = .left

        let lights = trafficLights()

        stack.addArrangedSubview(title)
        stack.addArrangedSubview(updated)
        stack.addArrangedSubview(lights)
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
        stack.addArrangedSubview(
            ActionRowView(
                icon: "🚪",
                title: "退出",
                isEnabled: true,
                action: quitAction
            )
        )
        return stack
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
        heightAnchor.constraint(equalToConstant: 176).isActive = true
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

        let plan = NSTextField(labelWithString: "套餐：\(profile.rateLimits.planType?.uppercased() ?? "UNKNOWN")")
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
        row.spacing = 8
        row.alignment = .centerY

        let primary = profile.rateLimits.primary?.remainingPercent
        let usage = usageLabel(remaining: primary)
        let reset = TimeText.beijingShort(profile.rateLimits.primary?.resetsAt)
        let detail = NSTextField(labelWithString: "使用：\(usage) | 重置：\(reset)")
        detail.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        detail.textColor = NSColor.black
        row.addArrangedSubview(detail)

        let spacer = NSView()
        row.addArrangedSubview(spacer)
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let button = NSButton(title: isActive ? "已部署 ✓" : "切过去!", target: self, action: #selector(switchTapped))
        button.bezelStyle = .rounded
        button.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .heavy)
        button.isEnabled = !isActive
        row.addArrangedSubview(button)

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

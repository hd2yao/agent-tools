import AppKit
import Foundation

struct DashboardPayload: Decodable {
    let generatedAt: String
    let profiles: [ProfileStatus]

    enum CodingKeys: String, CodingKey {
        case generatedAt = "generated_at"
        case profiles
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
            return "Ready"
        case .yellow:
            return "Watch"
        case .red:
            return "Low"
        case .unknown:
            return "Unknown"
        }
    }
}

final class CodexProfileMenuBarApp: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()
    private var latestPayload: DashboardPayload?
    private var latestError: String?
    private var isRefreshing = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configureStatusItem()
        configurePopover()
        updatePopover()
        refreshStatus(nil)
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else {
            return
        }
        button.title = "</> -- ⚪️"
        button.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .semibold)
        button.toolTip = "Codex Account Manager"
        button.target = self
        button.action = #selector(togglePopover(_:))
    }

    private func configurePopover() {
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
        popover.contentSize = NSSize(width: 460, height: 560)
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
        statusItem.button?.title = "</> ... ⚪️"
        latestError = nil
        updatePopover(message: "Refreshing Codex accounts...")
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
            latestError = "Could not read status output."
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
            latestError = "Could not decode Codex status."
            updateStatusTitle()
            updatePopover(message: latestError)
        }
    }

    private func updateStatusTitle() {
        if latestError != nil {
            statusItem.button?.title = "</> ! 🔴"
            return
        }
        let remaining = latestPayload?.profiles.compactMap { $0.rateLimits.primary?.remainingPercent }.min()
        let health = AccountHealth(remaining: remaining)
        let percent = remaining.map { "\($0)%" } ?? "--"
        statusItem.button?.title = "</> \(percent) \(health.emoji)"
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
        statusItem.button?.title = "</> ... ⚪️"
        updatePopover(message: "Switching to \(name)...")
        DispatchQueue.global(qos: .userInitiated).async {
            let result = Self.runPython(arguments: ["app", name])
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self.updatePopover(message: "Switched to \(name).")
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
                content.addArrangedSubview(AccountCardView(profile: profile, index: index, switchAction: switchAction))
            }
        }

        content.addArrangedSubview(actionRow())
    }

    private func headerView() -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 6

        let title = NSTextField(labelWithString: "CODEX ACCOUNT MANAGER")
        title.font = NSFont.systemFont(ofSize: 18, weight: .heavy)
        title.textColor = NSColor(calibratedRed: 0.06, green: 0.18, blue: 0.17, alpha: 1)

        let updated = NSTextField(labelWithString: "Last Update: \(formatGeneratedAt(payload?.generatedAt))")
        updated.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .medium)
        updated.textColor = NSColor(calibratedWhite: 0.18, alpha: 1)

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

        let minRemaining = payload?.profiles.compactMap { $0.rateLimits.primary?.remainingPercent }.min()
        let health = AccountHealth(remaining: minRemaining)
        for item in [AccountHealth.green, .yellow, .red] {
            let dot = ColorDotView(color: item == health ? item.color : NSColor.systemGray.withAlphaComponent(0.25))
            dot.translatesAutoresizingMaskIntoConstraints = false
            dot.widthAnchor.constraint(equalToConstant: 13).isActive = true
            dot.heightAnchor.constraint(equalToConstant: 13).isActive = true
            row.addArrangedSubview(dot)
        }
        let label = NSTextField(labelWithString: "\(health.label) · \(minRemaining.map { "\($0)% lowest primary" } ?? "no data")")
        label.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        label.textColor = NSColor(calibratedWhite: 0.18, alpha: 1)
        row.addArrangedSubview(label)
        return row
    }

    private func messageView(_ message: String) -> NSView {
        let label = NSTextField(labelWithString: message)
        label.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        label.textColor = NSColor(calibratedRed: 0.15, green: 0.24, blue: 0.38, alpha: 1)
        label.lineBreakMode = .byTruncatingTail
        return label
    }

    private func actionRow() -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 10
        row.alignment = .centerY

        let refresh = NSButton(title: isRefreshing ? "Refreshing..." : "Refresh", target: self, action: #selector(refreshTapped))
        refresh.bezelStyle = .rounded
        refresh.isEnabled = !isRefreshing

        let quit = NSButton(title: "Quit", target: self, action: #selector(quitTapped))
        quit.bezelStyle = .rounded

        row.addArrangedSubview(refresh)
        row.addArrangedSubview(quit)
        return row
    }

    @objc private func refreshTapped() {
        refreshAction()
    }

    @objc private func quitTapped() {
        quitAction()
    }

    private func formatGeneratedAt(_ value: String?) -> String {
        guard let value else {
            return "--"
        }
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: value) {
            return date.formatted(date: .numeric, time: .shortened)
        }
        return value
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
        let symbols = ["</>", "{ }", "♥", "+", "⚡"]
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
    private let switchAction: (String) -> Void

    init(profile: ProfileStatus, index: Int, switchAction: @escaping (String) -> Void) {
        self.profile = profile
        self.index = index
        self.switchAction = switchAction
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
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
        stack.addArrangedSubview(barRow(label: "Primary", window: profile.rateLimits.primary))
        stack.addArrangedSubview(barRow(label: "Secondary", window: profile.rateLimits.secondary))
        stack.addArrangedSubview(footerRow())
    }

    private func titleRow() -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 10
        row.alignment = .centerY

        let avatar = NSTextField(labelWithString: index % 2 == 0 ? "🤖" : "👩🏻‍💻")
        avatar.font = NSFont.systemFont(ofSize: 34)
        row.addArrangedSubview(avatar)

        let text = NSStackView()
        text.orientation = .vertical
        text.spacing = 2

        let name = NSTextField(labelWithString: profile.name)
        name.font = NSFont.systemFont(ofSize: 20, weight: .heavy)
        name.textColor = NSColor.black
        name.lineBreakMode = .byTruncatingTail

        let plan = NSTextField(labelWithString: "Plan: \(profile.rateLimits.planType?.uppercased() ?? "UNKNOWN")")
        plan.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .bold)
        plan.textColor = NSColor(calibratedRed: 0.14, green: 0.28, blue: 0.46, alpha: 1)

        text.addArrangedSubview(name)
        text.addArrangedSubview(plan)
        row.addArrangedSubview(text)

        let spacer = NSView()
        row.addArrangedSubview(spacer)
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let health = AccountHealth(remaining: profile.rateLimits.primary?.remainingPercent)
        let dot = NSTextField(labelWithString: health.emoji)
        dot.font = NSFont.systemFont(ofSize: 18)
        row.addArrangedSubview(dot)
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
        title.widthAnchor.constraint(equalToConstant: 74).isActive = true

        let remaining = window?.remainingPercent
        let bar = PixelBarView(percent: remaining ?? 0, color: AccountHealth(remaining: remaining).color)
        bar.translatesAutoresizingMaskIntoConstraints = false
        bar.heightAnchor.constraint(equalToConstant: 20).isActive = true

        let value = NSTextField(labelWithString: "\(remaining.map { "\($0)%" } ?? "--") REMAINING")
        value.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .bold)
        value.textColor = NSColor.black
        value.alignment = .right
        value.translatesAutoresizingMaskIntoConstraints = false
        value.widthAnchor.constraint(equalToConstant: 112).isActive = true

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
        let reset = formatReset(profile.rateLimits.primary?.resetsAt)
        let detail = NSTextField(labelWithString: "Usage: \(usage) | Resets: \(reset)")
        detail.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        detail.textColor = NSColor.black
        row.addArrangedSubview(detail)

        let spacer = NSView()
        row.addArrangedSubview(spacer)
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let button = NSButton(title: index % 2 == 0 ? "DEPLOY!" : "LET'S GO!", target: self, action: #selector(switchTapped))
        button.bezelStyle = .rounded
        button.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .heavy)
        row.addArrangedSubview(button)

        return row
    }

    @objc private func switchTapped() {
        switchAction(profile.name)
    }

    private func usageLabel(remaining: Int?) -> String {
        guard let remaining else {
            return "Unknown"
        }
        if remaining < 35 {
            return "High"
        }
        if remaining < 70 {
            return "Medium"
        }
        return "Minimal"
    }

    private func formatReset(_ value: TimeInterval?) -> String {
        guard let value else {
            return "--"
        }
        return Date(timeIntervalSince1970: value).formatted(date: .numeric, time: .shortened)
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

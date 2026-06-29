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
    let windowMinutes: Int?
    let resetsAt: TimeInterval?

    enum CodingKeys: String, CodingKey {
        case remainingPercent = "remaining_percent"
        case windowMinutes = "window_minutes"
        case resetsAt = "resets_at"
    }
}

enum CommandResult {
    case success(String)
    case failure(String)
}

final class CodexProfileMenuBarApp: NSObject, NSApplicationDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private var latestPayload: DashboardPayload?
    private var isRefreshing = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configureStatusItem()
        rebuildMenu(message: "Loading Codex profiles...")
        refreshStatus(nil)
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else {
            return
        }
        button.image = NSImage(
            systemSymbolName: "chevron.left.forwardslash.chevron.right",
            accessibilityDescription: "Codex Profiles"
        )
        button.title = ""
    }

    @objc private func refreshStatus(_ sender: Any?) {
        if isRefreshing {
            return
        }
        isRefreshing = true
        statusItem.button?.title = "..."
        DispatchQueue.global(qos: .userInitiated).async {
            let result = Self.runPython(arguments: ["status", "--json"])
            DispatchQueue.main.async {
                self.isRefreshing = false
                switch result {
                case .success(let output):
                    self.handleStatusOutput(output)
                case .failure(let error):
                    self.statusItem.button?.title = "!"
                    self.rebuildMenu(message: error)
                }
            }
        }
    }

    private func handleStatusOutput(_ output: String) {
        guard let data = output.data(using: .utf8) else {
            statusItem.button?.title = "!"
            rebuildMenu(message: "Could not read status output.")
            return
        }
        do {
            let decoder = JSONDecoder()
            let payload = try decoder.decode(DashboardPayload.self, from: data)
            latestPayload = payload
            updateStatusTitle(payload)
            rebuildMenu(payload: payload)
        } catch {
            statusItem.button?.title = "!"
            rebuildMenu(message: "Could not decode Codex status.")
        }
    }

    private func updateStatusTitle(_ payload: DashboardPayload) {
        let remaining = payload.profiles.compactMap { $0.rateLimits.primary?.remainingPercent }.min()
        if let remaining {
            statusItem.button?.title = " \(remaining)%"
        } else {
            statusItem.button?.title = ""
        }
    }

    private func rebuildMenu(payload: DashboardPayload? = nil, message: String? = nil) {
        let menu = NSMenu()

        if let message {
            let item = NSMenuItem(title: message, action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
        }

        let payload = payload ?? latestPayload
        if let payload {
            let updated = NSMenuItem(title: "Updated \(formatGeneratedAt(payload.generatedAt))", action: nil, keyEquivalent: "")
            updated.isEnabled = false
            menu.addItem(updated)
            menu.addItem(NSMenuItem.separator())

            for profile in payload.profiles {
                appendProfile(profile, to: menu)
                menu.addItem(NSMenuItem.separator())
            }
        }

        let refresh = NSMenuItem(title: "Refresh", action: #selector(refreshStatus(_:)), keyEquivalent: "r")
        refresh.target = self
        menu.addItem(refresh)

        menu.addItem(NSMenuItem.separator())

        let quit = NSMenuItem(title: "Quit", action: #selector(quit(_:)), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        statusItem.menu = menu
    }

    private func appendProfile(_ profile: ProfileStatus, to menu: NSMenu) {
        let title = NSMenuItem(title: profile.name, action: nil, keyEquivalent: "")
        title.isEnabled = false
        menu.addItem(title)

        let statusLine = "  \(profile.auth) auth, \(profile.config) config"
        let status = NSMenuItem(title: statusLine, action: nil, keyEquivalent: "")
        status.isEnabled = false
        menu.addItem(status)

        let plan = profile.rateLimits.planType ?? "unknown"
        let planItem = NSMenuItem(title: "  Plan: \(plan)", action: nil, keyEquivalent: "")
        planItem.isEnabled = false
        menu.addItem(planItem)

        appendWindow("Primary", profile.rateLimits.primary, to: menu)
        appendWindow("Secondary", profile.rateLimits.secondary, to: menu)

        if let credits = profile.rateLimits.creditsAvailable {
            let creditsItem = NSMenuItem(title: "  Reset credits: \(credits)", action: nil, keyEquivalent: "")
            creditsItem.isEnabled = false
            menu.addItem(creditsItem)
        }

        if let remoteError = profile.remoteError {
            let error = NSMenuItem(title: "  \(remoteError)", action: nil, keyEquivalent: "")
            error.isEnabled = false
            menu.addItem(error)
        }

        let switchItem = NSMenuItem(title: "Switch to \(profile.name)", action: #selector(switchProfile(_:)), keyEquivalent: "")
        switchItem.representedObject = profile.name
        switchItem.target = self
        menu.addItem(switchItem)
    }

    private func appendWindow(_ label: String, _ window: RateLimitWindow?, to menu: NSMenu) {
        guard let window else {
            let item = NSMenuItem(title: "  \(label): unavailable", action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
            return
        }
        let remaining = window.remainingPercent.map { "\($0)%" } ?? "-"
        let reset = formatReset(window.resetsAt)
        let item = NSMenuItem(title: "  \(label): \(remaining) remaining, resets \(reset)", action: nil, keyEquivalent: "")
        item.isEnabled = false
        menu.addItem(item)
    }

    @objc private func switchProfile(_ sender: NSMenuItem) {
        guard let name = sender.representedObject as? String else {
            return
        }
        statusItem.button?.title = " ..."
        rebuildMenu(message: "Switching to \(name)...")
        DispatchQueue.global(qos: .userInitiated).async {
            let result = Self.runPython(arguments: ["app", name])
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self.rebuildMenu(message: "Switched to \(name).")
                    self.refreshStatus(nil)
                case .failure(let error):
                    self.statusItem.button?.title = "!"
                    self.rebuildMenu(message: error)
                }
            }
        }
    }

    @objc private func quit(_ sender: Any?) {
        NSApp.terminate(nil)
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

    private func formatGeneratedAt(_ value: String) -> String {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: value) {
            return date.formatted(date: .numeric, time: .shortened)
        }
        return value
    }

    private func formatReset(_ value: TimeInterval?) -> String {
        guard let value else {
            return "-"
        }
        let date = Date(timeIntervalSince1970: value)
        return date.formatted(date: .numeric, time: .shortened)
    }
}

let app = NSApplication.shared
let delegate = CodexProfileMenuBarApp()
app.delegate = delegate
app.run()

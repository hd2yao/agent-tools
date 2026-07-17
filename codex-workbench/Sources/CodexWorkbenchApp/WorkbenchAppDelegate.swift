import AppKit
import CodexWorkbenchCore

extension Notification.Name {
    static let workbenchReopenRequested = Notification.Name("WorkbenchReopenRequested")
}

final class WorkbenchAppDelegate: NSObject, NSApplicationDelegate {
    private let launchMode = WorkbenchLaunchPolicy.mode(
        arguments: ProcessInfo.processInfo.arguments
    )

    func applicationWillFinishLaunching(_ notification: Notification) {
        if launchMode == .menuBarOnly {
            NSApp.setActivationPolicy(.accessory)
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard launchMode == .menuBarOnly else { return }
        DispatchQueue.main.async {
            NSApp.windows
                .filter { $0.title == "Codex 观测站" }
                .forEach { $0.orderOut(nil) }
        }
    }

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        NSApp.setActivationPolicy(.regular)
        NotificationCenter.default.post(name: .workbenchReopenRequested, object: nil)
        return false
    }
}

import AppKit
import CodexWorkbenchCore

enum CodexIntegrationService {
    static func openCodex() {
        if let running = NSRunningApplication.runningApplications(
            withBundleIdentifier: CodexIntegration.bundleIdentifier
        ).first {
            running.activate(options: [.activateAllWindows])
            return
        }

        guard let appURL = NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: CodexIntegration.bundleIdentifier
        ) else { return }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.openApplication(
            at: appURL,
            configuration: configuration,
            completionHandler: nil
        )
    }

    static func openThread(_ threadID: String) {
        guard let url = CodexIntegration.threadURL(for: threadID) else { return }
        NSWorkspace.shared.open(url)
    }
}

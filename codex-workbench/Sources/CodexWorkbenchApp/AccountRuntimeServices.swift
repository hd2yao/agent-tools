import AppKit
import CodexWorkbenchCore

enum AccountRuntimeServices {
    static func legacyProfileSwitcherIsRunning() -> Bool {
        AccountRuntimePolicy.legacyProfileSwitcherIsRunning(
            bundleIdentifiers: NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier)
        )
    }
}

public enum AccountAutomationAvailability: Equatable, Sendable {
    case available
    case pausedForLegacyProfileSwitcher
}

public enum AccountRuntimePolicy {
    public static let legacyProfileSwitcherBundleIdentifier = "com.hd2yao.codex-profile-switcher"

    public static func legacyProfileSwitcherIsRunning(
        bundleIdentifiers: [String]
    ) -> Bool {
        bundleIdentifiers.contains(legacyProfileSwitcherBundleIdentifier)
    }

    public static func automationAvailability(
        legacyProfileSwitcherRunning: Bool
    ) -> AccountAutomationAvailability {
        legacyProfileSwitcherRunning ? .pausedForLegacyProfileSwitcher : .available
    }
}

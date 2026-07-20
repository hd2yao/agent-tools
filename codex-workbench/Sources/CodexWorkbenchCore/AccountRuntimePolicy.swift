public enum AccountAutomationAvailability: Equatable, Sendable {
    case available
    case pausedForLegacyProfileSwitcher
    case readOnlyLocalAccount
}

public enum AccountRuntimePolicy {
    public static let legacyProfileSwitcherBundleIdentifier = "com.hd2yao.codex-profile-switcher"

    public static func legacyProfileSwitcherIsRunning(
        bundleIdentifiers: [String]
    ) -> Bool {
        bundleIdentifiers.contains(legacyProfileSwitcherBundleIdentifier)
    }

    public static func automationAvailability(
        accountMode: AccountMode = .managedProfiles,
        legacyProfileSwitcherRunning: Bool
    ) -> AccountAutomationAvailability {
        if accountMode == .localDefault {
            return .readOnlyLocalAccount
        }
        return legacyProfileSwitcherRunning ? .pausedForLegacyProfileSwitcher : .available
    }
}

import CodexWorkbenchCore

func runAccountRuntimePolicyTests(_ runner: inout TestRunner) {
    let legacyBundleID = AccountRuntimePolicy.legacyProfileSwitcherBundleIdentifier

    runner.expect(
        AccountRuntimePolicy.legacyProfileSwitcherIsRunning(
            bundleIdentifiers: ["com.openai.codex", legacyBundleID]
        ),
        "The legacy Profile Switcher process should be detected by its exact bundle identifier"
    )
    runner.expect(
        !AccountRuntimePolicy.legacyProfileSwitcherIsRunning(
            bundleIdentifiers: ["com.openai.codex", "com.hd2yao.codex-workbench"]
        ),
        "Unrelated Codex apps must not trigger the cold-backup conflict"
    )
    runner.expect(
        AccountRuntimePolicy.automationAvailability(legacyProfileSwitcherRunning: true)
            == .pausedForLegacyProfileSwitcher,
        "Account automation must pause while the cold-backup app is running"
    )
    runner.expect(
        AccountRuntimePolicy.automationAvailability(legacyProfileSwitcherRunning: false)
            == .available,
        "Account automation should stay available when only the workbench is running"
    )
}

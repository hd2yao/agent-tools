import CodexWorkbenchCore
import Foundation

func runWorkbenchDiagnosticsTests(_ runner: inout TestRunner) {
    let duplicate = WorkbenchDiagnosticsBuilder.build(
        WorkbenchDiagnosticInput(
            installedApps: [
                DiagnosticAppInstallation(
                    url: URL(fileURLWithPath: "/Applications/ChatGPT.app"),
                    bundleIdentifier: CodexIntegration.bundleIdentifier,
                    version: "1.2.3",
                    isRunning: true
                ),
                DiagnosticAppInstallation(
                    url: URL(fileURLWithPath: "/Applications/Codex.app"),
                    bundleIdentifier: CodexIntegration.bundleIdentifier,
                    version: "1.2.2",
                    isRunning: false
                ),
            ],
            selectedAppURL: URL(fileURLWithPath: "/Applications/ChatGPT.app"),
            backendAvailable: true,
            accountMode: .managedProfiles,
            managedProfileCount: 2,
            recentFailureStage: "verification_mismatch"
        )
    )
    runner.expect(
        duplicate.findings.contains { $0.id == "duplicate-codex-apps" && $0.level == .warning },
        "Duplicate Codex apps must be called out as a warning"
    )
    runner.expect(
        duplicate.findings.contains { $0.id == "account-managed-profiles" },
        "Managed profile mode should be explicit"
    )
    runner.expect(
        duplicate.findings.contains { $0.id == "recent-account-failure" },
        "A recent safe failure stage should remain actionable"
    )
    runner.expect(
        duplicate.revealTargets.count == 2,
        "Every discovered Codex app should be available as a vetted Finder target"
    )
    runner.expect(
        !duplicate.copyableSummary.contains("auth.json"),
        "Diagnostic summary must not expose auth file names"
    )
    runner.expect(
        !duplicate.copyableSummary.lowercased().contains("token"),
        "Diagnostic summary must remain redacted"
    )
    runner.expect(
        !duplicate.copyableSummary.contains("/Applications/"),
        "Diagnostic summary must not expose full application paths"
    )

    let single = WorkbenchDiagnosticsBuilder.build(
        WorkbenchDiagnosticInput(
            installedApps: [
                DiagnosticAppInstallation(
                    url: URL(fileURLWithPath: "/Applications/Codex.app"),
                    bundleIdentifier: CodexIntegration.bundleIdentifier,
                    version: "1.2.3",
                    isRunning: false
                )
            ],
            selectedAppURL: URL(fileURLWithPath: "/Applications/Codex.app"),
            backendAvailable: true,
            accountMode: .localDefault,
            managedProfileCount: 0
        )
    )
    runner.expect(
        single.findings.contains { $0.id == "codex-app-ready" && $0.level == .info },
        "A single installation should be reported as ready"
    )
    runner.expect(
        single.findings.contains { $0.id == "account-local-default" },
        "Local default account mode should be explicit"
    )

    let missing = WorkbenchDiagnosticsBuilder.build(
        WorkbenchDiagnosticInput(
            installedApps: [],
            selectedAppURL: nil,
            backendAvailable: false,
            accountMode: .unavailable,
            managedProfileCount: 0
        )
    )
    runner.expect(
        missing.findings.contains { $0.id == "codex-app-missing" && $0.level == .error },
        "A missing Codex app should be actionable"
    )
    runner.expect(
        missing.findings.contains { $0.id == "account-backend-missing" && $0.level == .error },
        "A missing bundled backend should be actionable"
    )
    runner.expect(
        missing.findings.contains { $0.id == "account-unavailable" && $0.level == .error },
        "An unavailable account source should remain explicit"
    )
}

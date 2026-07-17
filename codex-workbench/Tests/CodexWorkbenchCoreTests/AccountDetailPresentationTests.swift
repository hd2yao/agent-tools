import CodexWorkbenchCore
import Foundation

func runAccountDetailPresentationTests(_ runner: inout TestRunner) {
    let master = AccountProfile(
        name: "hd-master",
        auth: "present",
        config: "present",
        rateLimits: AccountRateLimits(primary: AccountQuotaWindow(remainingPercent: 87)),
        resetCreditDetails: AccountResetCreditDetails(
            availableCount: 2,
            credits: [
                AccountResetCreditCard(id: "later", used: false, expiresAt: 3_000),
                AccountResetCreditCard(id: "used", used: true, expiresAt: 1_500),
                AccountResetCreditCard(id: "earlier", used: false, expiresAt: 2_000),
            ]
        )
    )
    let blackwell = AccountProfile(
        name: "hd-sarah-blackwell",
        auth: "present",
        config: "present",
        rateLimits: AccountRateLimits(primary: AccountQuotaWindow(remainingPercent: 99))
    )
    let role = AccountRole(profile: "hd-sarah-blackwell", source: "recent-task", confidence: .inferred)
    let payload = AccountDashboardPayload(
        generatedAt: Date(timeIntervalSince1970: 1_000),
        activeProfile: "hd-master",
        desktopStatus: AccountDesktopStatus(
            running: true,
            managed: true,
            state: "managed_default_home",
            message: nil,
            activeProfile: "hd-master"
        ),
        profileRoles: AccountProfileRoles(
            task: role,
            desktop: AccountRole(profile: "hd-master", source: "desktop", confidence: .confirmed),
            attribution: role,
            taskMatchesDesktop: false
        ),
        profiles: [blackwell, master]
    )

    let details = AccountPresentationBuilder.details(payload: payload)
    runner.expect(
        details.currentProfile?.name == "hd-master",
        "Account details must use the actual logged-in account, never the recent task role"
    )
    runner.expect(
        details.otherProfiles.map(\.name) == ["hd-sarah-blackwell"],
        "The remaining managed accounts should be offered as switch targets"
    )
    runner.expect(
        details.currentResetCards.map(\.id) == ["earlier", "later", "used"],
        "Available reset cards should be ordered by expiry before used cards"
    )

    let unknown = AccountPresentationBuilder.details(payload: nil)
    runner.expect(unknown.currentProfile == nil, "Missing payload must not invent a current account")
    runner.expect(unknown.otherProfiles.isEmpty, "Missing payload must not invent switch targets")
}

import CodexWorkbenchCore
import Foundation

final class AutomaticResetPreferenceStore {
    static let legacySuiteName = AccountRuntimePolicy.legacyProfileSwitcherBundleIdentifier

    private let defaults: UserDefaults

    init(defaults: UserDefaults? = UserDefaults(suiteName: legacySuiteName)) {
        self.defaults = defaults ?? .standard
    }

    func record(fingerprint: String) -> AutomaticResetRecord {
        let lastAttemptKey = AutomaticResetStorageKeys.lastAttempt(fingerprint: fingerprint)
        let lastAttempt = defaults.object(forKey: lastAttemptKey) == nil
            ? nil
            : defaults.double(forKey: lastAttemptKey)
        return AutomaticResetRecord(
            outcome: defaults.string(
                forKey: AutomaticResetStorageKeys.outcome(fingerprint: fingerprint)
            ),
            lastAttemptAt: lastAttempt,
            idempotencyKey: defaults.string(
                forKey: AutomaticResetStorageKeys.idempotency(fingerprint: fingerprint)
            )
        )
    }

    func begin(attempt: AutomaticResetAttempt, now: TimeInterval) {
        defaults.set(
            "codex-workbench",
            forKey: AutomaticResetStorageKeys.actor(fingerprint: attempt.fingerprint)
        )
        defaults.set(
            attempt.idempotencyKey,
            forKey: AutomaticResetStorageKeys.idempotency(fingerprint: attempt.fingerprint)
        )
        defaults.set(
            now,
            forKey: AutomaticResetStorageKeys.lastAttempt(fingerprint: attempt.fingerprint)
        )
    }

    func finish(attempt: AutomaticResetAttempt, outcome: String) {
        defaults.set(
            outcome,
            forKey: AutomaticResetStorageKeys.outcome(fingerprint: attempt.fingerprint)
        )
    }
}

@MainActor
final class AutomaticResetCoordinator {
    private let store: AutomaticResetPreferenceStore
    private let notifications: ResetCreditNotificationService
    private var inFlight = Set<String>()

    init(
        store: AutomaticResetPreferenceStore = AutomaticResetPreferenceStore(),
        notifications: ResetCreditNotificationService = ResetCreditNotificationService()
    ) {
        self.store = store
        self.notifications = notifications
    }

    func start() {
        notifications.requestAuthorization()
    }

    func process(
        payload: AccountDashboardPayload,
        gateway: AccountGateway?,
        availability: AccountAutomationAvailability,
        onTerminalOutcome: @escaping @MainActor (AutomaticResetAttempt, AccountResetCreditConsumeResult) -> Void
    ) {
        guard availability == .available else {
            notifications.clearScheduledReminders()
            return
        }
        notifications.sync(payload: payload)
        guard let gateway else { return }
        let now = Date().timeIntervalSince1970

        for profile in payload.profiles {
            guard let fingerprint = AutomaticResetPolicy.fingerprint(profile: profile, now: now) else {
                continue
            }
            let decision = AutomaticResetPolicy.decision(
                profile: profile,
                now: now,
                record: store.record(fingerprint: fingerprint),
                isInFlight: inFlight.contains(fingerprint),
                automationAvailability: availability,
                newIdempotencyKey: UUID().uuidString
            )
            guard case .consume(let attempt) = decision else { continue }
            store.begin(attempt: attempt, now: now)
            inFlight.insert(fingerprint)

            Task {
                let result = await Task.detached(priority: .userInitiated) {
                    try? gateway.consumeResetCredit(
                        profile: attempt.profile,
                        idempotencyKey: attempt.idempotencyKey
                    )
                }.value
                inFlight.remove(fingerprint)
                guard
                    let result,
                    result.ok,
                    let outcome = result.outcome,
                    AutomaticResetPolicy.terminalOutcomes.contains(outcome)
                else {
                    return
                }
                store.finish(attempt: attempt, outcome: outcome)
                if outcome == "reset" || outcome == "alreadyRedeemed" {
                    notifications.notifyAutomaticReset(profile: attempt.profile, outcome: outcome)
                }
                onTerminalOutcome(attempt, result)
            }
        }
    }
}

import Foundation

public enum AccountOperationEventFactory {
    public static func switchSucceeded(
        from previousProfile: String?,
        to profile: String,
        at date: Date = Date()
    ) -> OperationEvent {
        OperationEvent(
            schemaVersion: 1,
            id: StableEventID.make(parts: [
                "account-switch",
                "success",
                profile,
                timestamp(date),
            ]),
            occurredAt: date,
            recordedAt: date,
            category: .account,
            action: "account_switched",
            title: "已切换 Codex 桌面账号",
            summary: "工作台已切换到 \(profile)，并验证实际登录状态。",
            status: .success,
            importance: .critical,
            certainty: .confirmed,
            actor: workbenchActor,
            account: EventAccount(profile: profile),
            sourceChain: [workbenchActor, accountEngineActor],
            before: previousProfile.map { .object(["desktop_profile": .string($0)]) },
            after: .object(["desktop_profile": .string(profile)]),
            evidence: [EventEvidence(kind: "app_action", label: "账号切换并验证完成")]
        )
    }

    public static func switchFailed(
        expected: String,
        actual: String?,
        reason: String,
        at date: Date = Date()
    ) -> OperationEvent {
        OperationEvent(
            schemaVersion: 1,
            id: StableEventID.make(parts: [
                "account-switch",
                "failure",
                expected,
                reason,
                timestamp(date),
            ]),
            occurredAt: date,
            recordedAt: date,
            category: .account,
            action: "account_switch_failed",
            title: "Codex 桌面账号切换未完成",
            summary: "账号切换未通过验证：目标 \(expected)，实际 \(actual ?? "未知")。",
            status: .failure,
            importance: .critical,
            certainty: .confirmed,
            actor: workbenchActor,
            account: EventAccount(profile: expected),
            sourceChain: [workbenchActor, accountEngineActor],
            after: actual.map { .object(["actual_profile": .string($0)]) },
            evidence: [EventEvidence(kind: "app_action", label: failureEvidenceLabel(reason))]
        )
    }

    private static let workbenchActor = EventActor(
        type: .app,
        id: "codex-workbench",
        label: "Codex 观测站"
    )

    private static let accountEngineActor = EventActor(
        type: .system,
        id: "codex-profile-switcher",
        label: "Profile Switcher 账号引擎"
    )

    private static func failureEvidenceLabel(_ reason: String) -> String {
        switch reason {
        case "switch_command_failed": "账号切换命令失败"
        case "verification_unavailable": "无法读取切换后状态"
        case "verification_mismatch": "切换后账号不匹配"
        case "unmanaged_login": "切换后账号未被工作台接管"
        default: "账号切换未通过验证"
        }
    }

    private static func timestamp(_ date: Date) -> String {
        String(format: "%.6f", date.timeIntervalSince1970)
    }
}

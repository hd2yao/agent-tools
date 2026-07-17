import CodexWorkbenchCore
import Foundation

func runAccountOperationEventFactoryTests(_ runner: inout TestRunner) {
    let at = Date(timeIntervalSince1970: 2_000)
    let success = AccountOperationEventFactory.switchSucceeded(
        from: "hd-master",
        to: "hd-sarah-blackwell",
        at: at
    )
    runner.expect(success.action == "account_switched", "Verified switch should use the success action")
    runner.expect(success.status == .success, "Verified switch should be a success")
    runner.expect(success.account?.profile == "hd-sarah-blackwell", "Switch event should retain the target account")
    runner.expect(success.actor.id == "codex-workbench", "Switch event should be owned by the workbench")
    runner.expect(
        success.before == .object(["desktop_profile": .string("hd-master")])
            && success.after == .object(["desktop_profile": .string("hd-sarah-blackwell")]),
        "Verified switches should retain before and after accounts"
    )
    runner.expect(
        success.sourceChain.map(\.id) == ["codex-workbench", "codex-profile-switcher"],
        "Switch evidence should identify the workbench and the mature account engine"
    )

    let failure = AccountOperationEventFactory.switchFailed(
        expected: "hd-sarah-blackwell",
        actual: "hd-master",
        reason: "verification_mismatch",
        at: at
    )
    runner.expect(failure.action == "account_switch_failed", "Failed verification should use a failure action")
    runner.expect(failure.status == .failure, "Failed verification should be a failure")
    runner.expect(
        failure.summary.contains("目标 hd-sarah-blackwell，实际 hd-master"),
        "Failure should explain the target and actual account"
    )
    runner.expect(
        failure.after == .object(["actual_profile": .string("hd-master")]),
        "Failure evidence should retain the actual account without credentials"
    )
}

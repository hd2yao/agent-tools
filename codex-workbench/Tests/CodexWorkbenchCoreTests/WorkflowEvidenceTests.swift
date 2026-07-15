import CodexWorkbenchCore
import Foundation

func runWorkflowEvidenceTests(_ runner: inout TestRunner) {
    let now = Date(timeIntervalSince1970: 1_000)
    let ruleV1 = WorkflowFileFingerprint(
        path: "/Users/dysania/.codex/AGENTS.md",
        kind: .rule,
        label: "Codex 全局规则",
        modifiedAt: Date(timeIntervalSince1970: 900),
        fingerprint: "v1"
    )
    let ruleV2 = WorkflowFileFingerprint(
        path: ruleV1.path,
        kind: .rule,
        label: ruleV1.label,
        modifiedAt: now,
        fingerprint: "v2"
    )
    let skill = WorkflowFileFingerprint(
        path: "/Users/dysania/.codex/skills/example/SKILL.md",
        kind: .skill,
        label: "example",
        modifiedAt: now,
        fingerprint: "skill-v1"
    )

    runner.expect(
        WorkflowChangeEventFactory().events(previous: nil, current: [ruleV1], observedAt: now).isEmpty,
        "The first workflow scan should establish a baseline without replaying every installed skill"
    )
    let changed = WorkflowChangeEventFactory().events(
        previous: [ruleV1.path: ruleV1],
        current: [ruleV2, skill],
        observedAt: now
    )
    runner.expect(changed.count == 2, "A modified rule and added skill should each create an event")
    runner.expect(
        changed.contains { $0.action == "workflow_rule_updated" && $0.importance == .important },
        "Global rule updates should be important"
    )
    runner.expect(
        changed.contains { $0.action == "skill_added" && $0.actor.type == .skill },
        "New skills should be attributed to the skill layer"
    )

    runner.expect(
        WorkflowFileClassifier.classify(path: "/Users/dysania/.codex/auth.json") == nil,
        "Authentication files must never enter workflow monitoring"
    )
    runner.expect(
        WorkflowFileClassifier.classify(path: "/Users/dysania/.codex/hooks/__pycache__/hook.pyc") == nil,
        "Generated caches must not create workflow events"
    )
    runner.expect(
        WorkflowFileClassifier.classify(path: "/Users/dysania/.codex/hooks/context-summary-card.py")?.kind == .hook,
        "Hook source files should be tracked"
    )
    runner.expect(
        WorkflowFileClassifier.classify(path: "/Users/dysania/.codex/automations/codex/automation.toml")?.kind == .automation,
        "Automation definitions should be tracked"
    )

    let digest = DailyDigestEvidence(
        day: "2026-07-15",
        generatedAt: now,
        sourcePath: "/Users/dysania/.codex/task-ledger/digests/daily/2026-07-15.md"
    )
    let digestEvent = DailyDigestEventFactory().event(from: digest, recordedAt: now)
    runner.expect(digestEvent.action == "daily_digest_generated", "Daily digest should have an explicit action")
    runner.expect(digestEvent.importance == .important, "Daily digest should be more prominent than context compression")
    runner.expect(digestEvent.actor.type == .automation, "Daily digest should be attributed to automation")
}

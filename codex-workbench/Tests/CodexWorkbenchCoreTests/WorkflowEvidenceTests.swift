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

    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("codex-workflow-semantic-\(UUID().uuidString)", isDirectory: true)
    let automationURL = temporaryDirectory
        .appendingPathComponent("automations/codex/automation.toml")
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }
    try? FileManager.default.createDirectory(
        at: automationURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )

    let oldAutomation = """
    version = 1
    id = "codex"
    name = "Codex 每日任务摘要与仓库收尾"
    prompt = "DailyDigest\\ngh pr merge"
    status = "ACTIVE"
    rrule = "RRULE:FREQ=DAILY"
    target_thread_id = "thread-target"
    """
    try? oldAutomation.write(to: automationURL, atomically: true, encoding: .utf8)
    let oldSnapshot = WorkflowFileCollector().collect(roots: [automationURL]).first

    let newAutomation = """
    version = 1
    id = "codex"
    name = "Codex 每日任务摘要与仓库收尾"
    prompt = "DailyDigest\\nclear-activity\\nrepository-action-budget.py\\ngit worktree remove\\n--duration-seconds\\nprivate marker must never persist"
    status = "ACTIVE"
    rrule = "RRULE:FREQ=DAILY"
    target_thread_id = "thread-target"
    """
    try? newAutomation.write(to: automationURL, atomically: true, encoding: .utf8)
    let newSnapshot = WorkflowFileCollector().collect(roots: [automationURL]).first

    runner.expect(oldSnapshot?.semanticSnapshot != nil, "Automation collection should retain a safe semantic snapshot")
    runner.expect(
        newSnapshot?.semanticSnapshot?.capabilities.contains("动态仓库操作预算") == true,
        "Automation snapshots should derive stable capability labels"
    )
    if let oldSnapshot, let newSnapshot {
        let semanticEvents = WorkflowChangeEventFactory().events(
            previous: [oldSnapshot.path: oldSnapshot],
            current: [newSnapshot],
            observedAt: now
        )
        let event = semanticEvents.first
        runner.expect(
            event?.summary.contains("动态仓库操作预算") == true,
            "Automation list summaries should explain a concrete change"
        )
        runner.expect(
            event?.changes?.contains { $0.summary == "动态仓库操作预算" } == true,
            "Automation details should expose structured capability changes"
        )
        runner.expect(event?.scope == .globalWorkflow, "Automation changes should expose global workflow scope")
        runner.expect(
            event?.relatedThreads?.contains { $0.role == .deliveryTarget && $0.id == "thread-target" } == true,
            "Automation target threads should be distinct from modification-source threads"
        )
        let encoded = try? LedgerWriter.encoder().encode(event)
        let encodedText = encoded.map { String(decoding: $0, as: UTF8.self) } ?? ""
        runner.expect(
            encodedText.contains("private marker must never persist") == false,
            "Full automation prompts must never enter the operation ledger"
        )
    }

    let skillURL = temporaryDirectory
        .appendingPathComponent("skills/task-continuity/SKILL.md")
    try? FileManager.default.createDirectory(
        at: skillURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    let oldSkillContent = """
    ---
    name: task-continuity
    description: 管理 Codex 待办、每日摘要和仓库收尾。
    ---

    # 任务连续性

    使用 task-ledger.py 与 repository-closure-audit.py。
    private skill body marker
    """
    try? oldSkillContent.write(to: skillURL, atomically: true, encoding: .utf8)
    let oldSkillSnapshot = WorkflowFileCollector().collect(roots: [skillURL]).first

    let newSkillContent = """
    ---
    name: task-continuity
    description: 管理 Codex 待办、每日摘要、周期任务健康和仓库收尾。
    ---

    # 任务连续性

    使用 task-ledger.py、repository-closure-audit.py 与 recurring-task-audit.py。
    private skill body marker
    """
    try? newSkillContent.write(to: skillURL, atomically: true, encoding: .utf8)
    let newSkillSnapshot = WorkflowFileCollector().collect(roots: [skillURL]).first

    runner.expect(
        oldSkillSnapshot?.semanticSnapshot?.purpose == "管理 Codex 待办、每日摘要和仓库收尾。",
        "Skill snapshots should retain the public purpose instead of only a fingerprint"
    )
    runner.expect(
        newSkillSnapshot?.semanticSnapshot?.capabilities.contains("周期任务健康审计") == true,
        "Skill snapshots should derive readable workflow capabilities"
    )
    if let oldSkillSnapshot, let newSkillSnapshot {
        let event = WorkflowChangeEventFactory().events(
            previous: [oldSkillSnapshot.path: oldSkillSnapshot],
            current: [newSkillSnapshot],
            observedAt: now
        ).first
        runner.expect(
            event?.changes?.contains { $0.label == "新增能力" && $0.summary == "周期任务健康审计" } == true,
            "Skill updates should explain newly added capabilities"
        )
        runner.expect(
            event?.summary.contains("周期任务健康审计") == true,
            "Skill list summaries should say what changed"
        )
        let encoded = try? LedgerWriter.encoder().encode(event)
        let encodedText = encoded.map { String(decoding: $0, as: UTF8.self) } ?? ""
        runner.expect(
            encodedText.contains("private skill body marker") == false,
            "Skill bodies must never enter the operation ledger"
        )

        let legacy = WorkflowFileFingerprint(
            path: oldSkillSnapshot.path,
            kind: .skill,
            label: oldSkillSnapshot.label,
            modifiedAt: now,
            fingerprint: "legacy-skill",
            semanticSnapshot: nil
        )
        let fallback = WorkflowChangeEventFactory().events(
            previous: [legacy.path: legacy],
            current: [newSkillSnapshot],
            observedAt: now
        ).first
        runner.expect(
            fallback?.changes?.contains { $0.label == "更新后职责" } == true,
            "Legacy workflow updates should explain the confirmed current responsibility"
        )
        runner.expect(
            fallback?.changes?.contains { $0.label == "证据边界" } == true,
            "Legacy workflow updates must admit that the old semantic snapshot is missing"
        )
    }

    let hookURL = temporaryDirectory.appendingPathComponent("hooks/recurring-task-audit.py")
    try? FileManager.default.createDirectory(
        at: hookURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    let hookContent = """
    \"\"\"审计项目声明的周期任务是否按计划产生新鲜成功证据。\"\"\"

    MANIFEST = ".codex/continuity.json"
    private hook body marker
    """
    try? hookContent.write(to: hookURL, atomically: true, encoding: .utf8)
    let hookSnapshot = WorkflowFileCollector().collect(roots: [hookURL]).first
    runner.expect(
        hookSnapshot?.semanticSnapshot?.purpose == "审计项目声明的周期任务是否按计划产生新鲜成功证据。",
        "Hook snapshots should retain a concise module responsibility"
    )
    runner.expect(
        hookSnapshot?.semanticSnapshot?.capabilities.contains("周期任务健康审计") == true,
        "Hook snapshots should expose readable capabilities"
    )
    if let hookSnapshot {
        let hookEvent = WorkflowChangeEventFactory().events(
            previous: [:],
            current: [hookSnapshot],
            observedAt: now
        ).first
        runner.expect(
            hookEvent?.changes?.contains { $0.label == "用途" } == true,
            "New hooks should explain their purpose"
        )
        runner.expect(
            hookEvent?.summary.contains("周期任务") == true,
            "New hook list summaries should describe what the hook does"
        )
    }
}

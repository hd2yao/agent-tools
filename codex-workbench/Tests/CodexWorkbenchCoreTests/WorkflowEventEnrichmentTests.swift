import CodexWorkbenchCore
import Foundation

func runWorkflowEventEnrichmentTests(_ runner: inout TestRunner) {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("codex-workflow-enrichment-\(UUID().uuidString)", isDirectory: true)
    let rolloutURL = temporaryDirectory.appendingPathComponent("rollout-source-thread.jsonl")
    let ledgerURL = temporaryDirectory.appendingPathComponent("events.jsonl")
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }
    try? FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)

    let oldAutomation = """
    version = 1
    id = "codex"
    name = "Codex 每日任务摘要与仓库收尾"
    prompt = "DailyDigest\\ngh pr merge"
    status = "ACTIVE"
    rrule = "DTSTART:20260708T000000Z\\nRRULE:FREQ=DAILY"
    target_thread_id = "thread-target"
    """
    let updateInput = """
    const prompt = `DailyDigest
    clear-activity
    repository-action-budget.py
    git worktree remove
    --duration-seconds`;
    const result = await tools.codex_app__automation_update({
      id:"codex",
      mode:"update",
      prompt,
      rrule:"DTSTART:20260708T000000Z\\nRRULE:FREQ=DAILY",
      targetThreadId:"thread-target"
    });
    """
    let sessionLines = [
        sessionLine(
            timestamp: "1970-01-01T00:03:10.000Z",
            payload: [
                "type": "custom_tool_call_output",
                "output": [["type": "input_text", "text": oldAutomation]],
            ]
        ),
        sessionLine(
            timestamp: "1970-01-01T00:03:20.000Z",
            payload: [
                "type": "custom_tool_call",
                "name": "exec",
                "input": updateInput,
            ]
        ),
    ]
    try? sessionLines.joined(separator: "\n").write(
        to: rolloutURL,
        atomically: true,
        encoding: .utf8
    )

    let sourceThread = CodexThreadMetadata(
        id: "thread-source",
        rawTitle: "修复每日摘要自动化",
        projectPath: "/Users/dysania/program/codex-workflow-skills",
        createdAt: Date(timeIntervalSince1970: 100),
        updatedAt: Date(timeIntervalSince1970: 210),
        sourceThreadID: nil,
        rolloutPath: rolloutURL.path
    )
    let targetThread = CodexThreadMetadata(
        id: "thread-target",
        rawTitle: "Codex 摘要归档",
        projectPath: "/Users/dysania/Documents/Codex/codex-digest-archive",
        createdAt: Date(timeIntervalSince1970: 50),
        updatedAt: Date(timeIntervalSince1970: 190),
        sourceThreadID: nil,
        rolloutPath: nil
    )
    let catalog = CodexMetadataCatalog(records: [sourceThread, targetThread])
    let legacyEvent = OperationEvent(
        schemaVersion: 1,
        id: "evt-automation",
        occurredAt: Date(timeIntervalSince1970: 200),
        recordedAt: Date(timeIntervalSince1970: 205),
        category: .automation,
        action: "automation_updated",
        title: "Automation已更新",
        summary: "codex 的全局工作流定义已更新。",
        status: .success,
        importance: .important,
        certainty: .confirmed,
        actor: EventActor(type: .automation, id: "workflow-file-monitor", label: "codex"),
        before: .object(["fingerprint": .string("v1")]),
        after: .object(["fingerprint": .string("v2")]),
        evidence: [EventEvidence(
            kind: "file_fingerprint",
            label: "受控工作流文件指纹",
            path: "/Users/dysania/.codex/automations/codex/automation.toml"
        )]
    )

    let revisions = WorkflowEventHistoryEnricher().revisions(
        events: [legacyEvent],
        catalog: catalog,
        recordedAt: Date(timeIntervalSince1970: 220)
    )
    runner.expect(revisions.count == 1, "A legacy automation event with exact session evidence should be enriched once")
    let revision = revisions.first
    runner.expect(revision?.thread?.id == "thread-source", "Enrichment should retain the modification-source thread")
    runner.expect(revision?.project?.name == "codex-workflow-skills", "Source project should come from thread metadata")
    runner.expect(
        revision?.relatedThreads?.contains { $0.role == .modificationSource && $0.title == "修复每日摘要自动化" } == true,
        "Modification source should have an explicit role and title"
    )
    runner.expect(
        revision?.relatedThreads?.contains { $0.role == .deliveryTarget && $0.title == "Codex 摘要归档" } == true,
        "Delivery target should remain distinct and resolve its title"
    )
    runner.expect(
        revision?.changes?.contains { $0.summary == "前一日工作采集" } == true,
        "Historic enrichment should recover a safe human-readable change summary"
    )
    runner.expect(
        revision?.summary.contains("动态仓库操作预算") == true,
        "Historic list summaries should mention concrete changes"
    )
    runner.expect(
        revision?.changes?.contains { ["名称", "状态", "执行计划"].contains($0.label) } == false,
        "Fields omitted from a partial update call should inherit their previous values"
    )
    if let revision {
        runner.expect(
            WorkflowEventHistoryEnricher().revisions(
                events: [revision],
                catalog: catalog,
                recordedAt: Date(timeIntervalSince1970: 230)
            ).isEmpty,
            "An already-correct semantic revision should not be appended again"
        )
        let staleRevision = OperationEvent(
            schemaVersion: revision.schemaVersion,
            id: revision.id,
            occurredAt: revision.occurredAt,
            recordedAt: revision.recordedAt,
            category: revision.category,
            action: revision.action,
            title: revision.title,
            summary: "错误地把换行转义识别为执行计划变化。",
            status: revision.status,
            importance: revision.importance,
            certainty: revision.certainty,
            actor: revision.actor,
            thread: revision.thread,
            project: revision.project,
            account: revision.account,
            scope: revision.scope,
            changes: [
                EventChange(
                    label: "执行计划",
                    summary: "换行转义差异",
                    before: "DTSTART:20260708T000000Z\nRRULE:FREQ=DAILY",
                    after: "DTSTART:20260708T000000Z\\nRRULE:FREQ=DAILY"
                ),
            ],
            relatedThreads: revision.relatedThreads,
            sourceChain: revision.sourceChain,
            before: revision.before,
            after: revision.after,
            evidence: revision.evidence
        )
        let corrected = WorkflowEventHistoryEnricher().revisions(
            events: [staleRevision],
            catalog: catalog,
            recordedAt: Date(timeIntervalSince1970: 230)
        )
        runner.expect(corrected.count == 1, "A stale semantic revision should receive one corrected revision")
        runner.expect(
            corrected.first?.changes?.contains { $0.label == "执行计划" } == false,
            "The corrected revision should remove the false schedule change"
        )
    }

    _ = LedgerWriter().append(events: [legacyEvent], to: ledgerURL)
    let firstRevision = LedgerWriter().appendRevisions(events: revisions, to: ledgerURL)
    let repeatedRevision = LedgerWriter().appendRevisions(events: revisions, to: ledgerURL)
    runner.expect(firstRevision.appendedCount == 1, "An enhanced revision should append without destroying history")
    runner.expect(repeatedRevision.appendedCount == 0, "Appending the same enhanced revision should be idempotent")
    let loaded = LedgerRepository().load(from: ledgerURL)
    runner.expect(loaded.events.count == 1, "Repository should collapse base and enhanced rows by stable id")
    runner.expect(loaded.events.first?.changes?.isEmpty == false, "The latest enhanced revision should win")

    let ambiguousRolloutURL = temporaryDirectory.appendingPathComponent("rollout-ambiguous.jsonl")
    try? sessionLines.joined(separator: "\n").write(
        to: ambiguousRolloutURL,
        atomically: true,
        encoding: .utf8
    )
    let ambiguousThread = CodexThreadMetadata(
        id: "thread-ambiguous",
        rawTitle: "另一个候选对话",
        projectPath: "/Users/dysania/program/tools",
        createdAt: Date(timeIntervalSince1970: 100),
        updatedAt: Date(timeIntervalSince1970: 210),
        sourceThreadID: nil,
        rolloutPath: ambiguousRolloutURL.path
    )
    let ambiguousCatalog = CodexMetadataCatalog(records: [sourceThread, ambiguousThread, targetThread])
    runner.expect(
        WorkflowEventHistoryEnricher().revisions(
            events: [legacyEvent],
            catalog: ambiguousCatalog,
            recordedAt: Date(timeIntervalSince1970: 220)
        ).isEmpty,
        "Multiple exact session matches must degrade instead of inventing a source conversation"
    )

    let variableRolloutURL = temporaryDirectory.appendingPathComponent("rollout-variable-update.jsonl")
    let variableInput = """
    const cfgResult = await tools.exec_command({
      cmd:"read /Users/dysania/.codex/automations/codex/automation.toml"
    });
    const cfg = JSON.parse(cfgResult.output);
    const updatedPrompt = cfg.prompt.replace("list_threads(limit=100)", "list_threads(limit=50)");
    const result = await tools.codex_app__automation_update({
      id:cfg.id,
      mode:"update",
      prompt:updatedPrompt,
      status:cfg.status
    });
    """
    let variableLines = [sessionLine(
        timestamp: "1970-01-01T00:03:20.000Z",
        payload: [
            "type": "custom_tool_call",
            "name": "exec",
            "input": variableInput,
        ]
    )]
    try? variableLines.joined(separator: "\n").write(
        to: variableRolloutURL,
        atomically: true,
        encoding: .utf8
    )
    let variableThread = CodexThreadMetadata(
        id: "thread-variable-source",
        rawTitle: "缩小每日任务扫描范围",
        projectPath: "/Users/dysania/program/codex-workflow-skills",
        createdAt: Date(timeIntervalSince1970: 100),
        updatedAt: Date(timeIntervalSince1970: 210),
        sourceThreadID: nil,
        rolloutPath: variableRolloutURL.path
    )
    let variableRevision = WorkflowEventHistoryEnricher().revisions(
        events: [legacyEvent],
        catalog: CodexMetadataCatalog(records: [variableThread]),
        recordedAt: Date(timeIntervalSince1970: 220)
    ).first
    runner.expect(
        variableRevision?.thread?.id == "thread-variable-source",
        "Variable-style automation updates should still resolve their source thread"
    )
    runner.expect(
        variableRevision?.changes?.contains {
            $0.label == "任务扫描范围"
                && $0.before == "100"
                && $0.after == "50"
        } == true,
        "Replacement-style automation updates should explain the concrete old and new values"
    )

    let reorderedInput = """
    const cfgResult = await tools.exec_command({
      cmd:"read /Users/dysania/.codex/automations/codex/automation.toml"
    });
    const cfg = JSON.parse(cfgResult.output);
    const oldBlock = `先运行 clear-activity 清理旧记录，再使用 list_threads(limit=50) 读取候选任务。`;
    const newBlock = `先使用 list_threads(limit=50) 读取候选任务；读取成功后再运行 clear-activity 重建，读取失败时保留现有记录。`;
    const updatedPrompt = cfg.prompt.replace(oldBlock, newBlock);
    const result = await tools.codex_app__automation_update({
      id:cfg.id,
      mode:"update",
      prompt:updatedPrompt,
      status:cfg.status
    });
    """
    let reorderedLine = sessionLine(
        timestamp: "1970-01-01T00:04:00.000Z",
        payload: [
            "type": "custom_tool_call",
            "name": "exec",
            "input": reorderedInput,
        ]
    )
    try? (variableLines + [reorderedLine]).joined(separator: "\n").write(
        to: variableRolloutURL,
        atomically: true,
        encoding: .utf8
    )
    let reorderedEvidence = AutomationSessionEvidenceCollector().evidence(
        automationID: "codex",
        occurredAt: Date(timeIntervalSince1970: 240),
        catalog: CodexMetadataCatalog(records: [variableThread])
    ).first
    runner.expect(
        reorderedEvidence?.directChanges.contains {
            $0.label == "活动记录重建顺序"
                && $0.summary.contains("读取失败时保留")
        } == true,
        "Named replacement blocks should explain the safer read-before-clear order"
    )

    let skillURL = temporaryDirectory.appendingPathComponent("skills/task-continuity/SKILL.md")
    try? FileManager.default.createDirectory(
        at: skillURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try? """
    ---
    name: task-continuity
    description: 管理每日任务摘要并审计周期任务运行状态。
    ---
    recurring-task-audit.py
    """.write(to: skillURL, atomically: true, encoding: .utf8)
    let currentSkill = WorkflowFileCollector().collect(roots: [skillURL]).first
    let legacySkill = OperationEvent(
        schemaVersion: 1,
        id: "evt-skill-legacy",
        occurredAt: Date(timeIntervalSince1970: 200),
        recordedAt: Date(timeIntervalSince1970: 205),
        category: .skill,
        action: "skill_updated",
        title: "Skill已更新",
        summary: "task-continuity 的全局工作流定义已更新。",
        status: .success,
        importance: .important,
        certainty: .confirmed,
        actor: EventActor(type: .skill, id: "workflow-file-monitor", label: "task-continuity"),
        before: .object(["fingerprint": .string("skill-v1")]),
        after: .object(["fingerprint": .string("skill-v2")]),
        evidence: [EventEvidence(kind: "file_fingerprint", label: "受控工作流文件指纹", path: skillURL.path)]
    )
    if let currentSkill {
        let fallbackRevision = WorkflowEventHistoryEnricher().revisions(
            events: [legacySkill],
            catalog: CodexMetadataCatalog(),
            currentWorkflowFiles: [currentSkill],
            recordedAt: Date(timeIntervalSince1970: 220)
        ).first
        runner.expect(
            fallbackRevision?.changes?.contains { $0.label == "更新后职责" } == true,
            "Existing generic Skill events should be backfilled from the current safe snapshot"
        )
        runner.expect(
            fallbackRevision?.changes?.contains { $0.label == "证据边界" } == true,
            "Historic Skill backfill should not pretend the current snapshot is an exact diff"
        )
    }

    let hookURL = temporaryDirectory.appendingPathComponent("hooks/recurring-task-audit.py")
    try? FileManager.default.createDirectory(
        at: hookURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try? """
    \"\"\"审计项目声明的周期任务是否按计划产生新鲜成功证据。\"\"\"
    MANIFEST = ".codex/continuity.json"
    """.write(to: hookURL, atomically: true, encoding: .utf8)
    let currentHook = WorkflowFileCollector().collect(roots: [hookURL]).first
    let legacyHookAdded = OperationEvent(
        schemaVersion: 1,
        id: "evt-hook-added-legacy",
        occurredAt: Date(timeIntervalSince1970: 200),
        recordedAt: Date(timeIntervalSince1970: 205),
        category: .hook,
        action: "hook_added",
        title: "Hook已新增",
        summary: "recurring-task-audit 的全局工作流定义已新增。",
        status: .success,
        importance: .important,
        certainty: .confirmed,
        actor: EventActor(type: .hook, id: "workflow-file-monitor", label: "recurring-task-audit"),
        after: .object(["fingerprint": .string("hook-v1")]),
        evidence: [EventEvidence(kind: "file_fingerprint", label: "受控工作流文件指纹", path: hookURL.path)]
    )
    if let currentHook {
        let addedRevision = WorkflowEventHistoryEnricher().revisions(
            events: [legacyHookAdded],
            catalog: CodexMetadataCatalog(),
            currentWorkflowFiles: [currentHook],
            recordedAt: Date(timeIntervalSince1970: 220)
        ).first
        runner.expect(
            addedRevision?.changes?.contains { $0.label == "用途" } == true,
            "Historic added Hook events should explain what the new hook does"
        )
        runner.expect(
            addedRevision?.changes?.contains { $0.label == "证据边界" } == false,
            "A confirmed added file should not be described as a missing-old-snapshot update"
        )
    }
}

private func sessionLine(timestamp: String, payload: [String: Any]) -> String {
    let object: [String: Any] = [
        "timestamp": timestamp,
        "type": "response_item",
        "payload": payload,
    ]
    let data = try! JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    return String(decoding: data, as: UTF8.self)
}

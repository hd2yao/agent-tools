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
    rrule = "RRULE:FREQ=DAILY"
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

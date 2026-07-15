import CodexWorkbenchCore
import Foundation

func runEvidenceReconcilerTests(_ runner: inout TestRunner) {
    let keyParts = ["context-card", "019f6067-342c-7b22-a9fc-cd50ded08d86", "2026-07-14T21:35:15+08:00"]
    runner.expect(
        StableEventID.make(parts: keyParts) == StableEventID.make(parts: keyParts),
        "Stable ids should be deterministic across scans"
    )
    runner.expect(
        StableEventID.make(parts: keyParts) != StableEventID.make(parts: keyParts + ["different"]),
        "Different evidence should not collapse into one event"
    )

    let cardMarkdown = """
    # Codex 上下文摘要卡片

    - 生成时间: 2026-07-14T21:35:15+08:00
    - 触发事件: PreCompact (auto)
    - 会话 ID: `019f6067-342c-7b22-a9fc-cd50ded08d86`
    - 项目路径: `/Users/dysania/program/tools`
    - 卡片路径: `/Users/dysania/.codex/context-cards/card.md`
    """
    let card = ContextCardEvidence.parse(
        markdown: cardMarkdown,
        sourcePath: "/Users/dysania/.codex/context-cards/card.md"
    )
    runner.expect(card != nil, "A real context card header should parse")

    let preferences: [String: JSONValue] = [
        "automatic-reset.last-attempt.hd-master.rate_limit_reached.1784515205": .number(1_784_027_580.6553841),
        "automatic-reset.outcome.hd-master.rate_limit_reached.1784515205": .string("reset"),
        "automatic-reset.idempotency.hd-master.rate_limit_reached.1784515205": .string("secret-idempotency-key"),
    ]
    let resets = AutomaticResetEvidence.parse(preferences: preferences)
    runner.expect(resets.count == 1, "A reset outcome and attempt should form one evidence item")
    runner.expect(resets.first?.profile == "hd-master", "Profile should parse from the reset key")
    runner.expect(resets.first?.outcome == "reset", "Reset outcome should parse")

    let taskLine = #"{"at":"2026-07-07T08:20:24Z","event":"update","task":{"id":"task_1","title":"线程关联项目工具","status":"done","project":{"name":"agent-tools","path":"/Users/dysania/program/tools/agent-tools"},"source":{"thread_id":"019f4613-1b48-7d00-a66f-788db5765f21","session_id":"019f4613-1b48-7d00-a66f-788db5765f21"}}}"#
    let taskRecord = LifecycleLedgerRecord.parse(line: taskLine, kind: .task)
    runner.expect(taskRecord?.item.title == "线程关联项目工具", "Task ledger title should parse")
    runner.expect(taskRecord?.item.threadID == "019f4613-1b48-7d00-a66f-788db5765f21", "Task thread should parse")

    let threadCatalog = CodexMetadataCatalog(records: [
        CodexThreadMetadata(
            id: "019f6067-342c-7b22-a9fc-cd50ded08d86",
            rawTitle: "Add 操作时间轴日志",
            projectPath: "/Users/dysania/program/tools",
            createdAt: Date(timeIntervalSince1970: 1_784_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_784_036_000),
            sourceThreadID: nil
        ),
    ])
    let snapshot = EvidenceSnapshot(
        contextCards: card.map { [$0] } ?? [],
        automaticResets: resets,
        lifecycleRecords: taskRecord.map { [$0] } ?? [],
        threadCatalog: threadCatalog
    )
    let recordedAt = Date(timeIntervalSince1970: 1_784_036_000)
    let events = EvidenceReconciler().events(from: snapshot, recordedAt: recordedAt)
    runner.expect(events.count == 3, "Context, reset, and task evidence should produce three events")

    let contextEvent = events.first { $0.action == "context_compacted" }
    runner.expect(contextEvent?.category == .context, "Context card should become a context event")
    runner.expect(contextEvent?.actor.type == .hook, "PreCompact should be attributed to a hook")
    runner.expect(contextEvent?.certainty == .confirmed, "Card metadata is confirmed evidence")
    runner.expect(contextEvent?.thread?.id == "019f6067-342c-7b22-a9fc-cd50ded08d86", "Context event should retain thread id")
    runner.expect(contextEvent?.thread?.title == "Add 操作时间轴日志", "Context event should resolve conversation title")
    runner.expect(contextEvent?.importance == .routine, "Context compaction should be a routine event")

    let resetEvent = events.first { $0.action == "reset_credit_consumed" }
    runner.expect(resetEvent?.category == .quota, "Reset outcome should become a quota event")
    runner.expect(resetEvent?.actor.id == "codex-profile-switcher", "Reset should be attributed to Profile Switcher")
    runner.expect(resetEvent?.account?.profile == "hd-master", "Reset event should retain profile")
    runner.expect(resetEvent?.occurredAt.timeIntervalSince1970 == 1_784_027_580.6553841, "Reset should retain exact attempt time")

    let taskEvent = events.first { $0.action == "task_updated" }
    runner.expect(taskEvent?.thread?.relation == .source, "Lifecycle event should point to its source thread")
    runner.expect(taskEvent?.project?.name == "agent-tools", "Lifecycle event should retain project")

    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("codex-workbench-tests-\(UUID().uuidString)", isDirectory: true)
    let ledgerURL = temporaryDirectory.appendingPathComponent("events.jsonl")
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }
    let firstWrite = LedgerWriter().append(events: events, to: ledgerURL)
    let secondWrite = LedgerWriter().append(events: events, to: ledgerURL)
    runner.expect(firstWrite.appendedCount == 3, "First reconciliation should append every event")
    runner.expect(secondWrite.appendedCount == 0, "Second reconciliation should deduplicate stable ids")
    let persisted = LedgerRepository().load(from: ledgerURL)
    runner.expect(persisted.events.count == 3, "Persisted JSONL should remain decodable")
    let rawLedger = (try? String(contentsOf: ledgerURL, encoding: .utf8)) ?? ""
    runner.expect(rawLedger.contains("schema_version"), "Persisted ledger should use snake_case")
    runner.expect(rawLedger.contains("secret-idempotency-key") == false, "Idempotency values must never reach the ledger")

    let fixtureRoot = temporaryDirectory.appendingPathComponent("evidence", isDirectory: true)
    let cardsDirectory = fixtureRoot.appendingPathComponent("context-cards", isDirectory: true)
    let taskLedgerURL = fixtureRoot.appendingPathComponent("task-ledger/tasks.jsonl")
    let workLedgerURL = fixtureRoot.appendingPathComponent("work-ledger/work.jsonl")
    try? FileManager.default.createDirectory(at: cardsDirectory, withIntermediateDirectories: true)
    try? FileManager.default.createDirectory(at: taskLedgerURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    try? FileManager.default.createDirectory(at: workLedgerURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    try? cardMarkdown.write(
        to: cardsDirectory.appendingPathComponent("card.md"),
        atomically: true,
        encoding: .utf8
    )
    try? (taskLine + "\n").write(to: taskLedgerURL, atomically: true, encoding: .utf8)
    try? "".write(to: workLedgerURL, atomically: true, encoding: .utf8)
    let fixtureSnapshot = LocalEvidenceReader().read(
        paths: LocalEvidencePaths(
            contextCardsDirectory: cardsDirectory,
            taskLedgerURL: taskLedgerURL,
            workLedgerURL: workLedgerURL
        ),
        resetPreferences: preferences
    )
    runner.expect(fixtureSnapshot.contextCards.count == 1, "Reader should discover context card files")
    runner.expect(fixtureSnapshot.lifecycleRecords.count == 1, "Reader should discover lifecycle ledgers")
    runner.expect(fixtureSnapshot.automaticResets.count == 1, "Reader should accept an injectable reset source")
}

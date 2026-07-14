import CodexWorkbenchCore
import Foundation

func runActivityFilterTests(_ runner: inout TestRunner) {
    let event = OperationEvent(
        schemaVersion: 1,
        id: "evt-1",
        occurredAt: Date(timeIntervalSince1970: 1_721_040_780),
        recordedAt: Date(timeIntervalSince1970: 1_721_040_781),
        category: .context,
        action: "context_compacted",
        title: "上下文已压缩",
        summary: "已生成中文摘要卡片",
        status: .success,
        importance: .important,
        certainty: .confirmed,
        actor: EventActor(type: .hook, id: "pre-compact", label: "PreCompact Hook"),
        thread: EventThread(
            id: "6a5620e6-c00c-83ec-869b-19d5f8de738b",
            title: "系统日志时间轴设计",
            relation: .triggeredBy
        )
    )

    runner.expect(ActivityFilter(query: "时间轴").matches(event), "Query should search thread title")
    runner.expect(ActivityFilter(query: "PreCompact").matches(event), "Query should search actor label")
    runner.expect(ActivityFilter(query: "没有这个词").matches(event) == false, "Unknown query should not match")
    runner.expect(
        ActivityFilter(importances: [.critical]).matches(event) == false,
        "Importance filter should exclude unmatched events"
    )
    runner.expect(ActivityFilter(actorTypes: [.hook]).matches(event), "Actor filter should match")
    runner.expect(ActivityFilter(statuses: [.failure]).matches(event) == false, "Status filter should exclude")

    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 8 * 3_600)!
    let nextDay = OperationEvent(
        schemaVersion: 1,
        id: "evt-2",
        occurredAt: event.occurredAt.addingTimeInterval(86_400),
        recordedAt: event.recordedAt.addingTimeInterval(86_400),
        category: .thread,
        action: "thread_created",
        title: "已创建任务",
        summary: "",
        status: .success,
        importance: .important,
        certainty: .confirmed,
        actor: EventActor(type: .app, id: "codex", label: "Codex")
    )
    let sections = ActivityGrouper.sections(for: [event, nextDay], calendar: calendar)
    runner.expect(sections.count == 2, "Events on different local dates should form separate sections")
    runner.expect(sections.first?.events.first?.id == "evt-2", "Newest date section should come first")

    let confirmedContext = OperationEvent(
        schemaVersion: 1,
        id: "evt-context",
        occurredAt: event.occurredAt,
        recordedAt: event.recordedAt,
        category: .context,
        action: "context_compacted",
        title: "上下文已压缩",
        summary: "",
        status: .success,
        importance: .critical,
        certainty: .confirmed,
        actor: event.actor
    )
    let consumedQuota = OperationEvent(
        schemaVersion: 1,
        id: "evt-quota",
        occurredAt: event.occurredAt,
        recordedAt: event.recordedAt,
        category: .quota,
        action: "reset_credit_consumed",
        title: "已使用额度重置",
        summary: "",
        status: .success,
        importance: .critical,
        certainty: .confirmed,
        actor: event.actor
    )
    runner.expect(
        ActivityInsights.requiresAttention(confirmedContext) == false,
        "Successful context maintenance should not inflate attention count"
    )
    runner.expect(
        ActivityInsights.requiresAttention(consumedQuota),
        "Confirmed resource consumption should require attention"
    )
}

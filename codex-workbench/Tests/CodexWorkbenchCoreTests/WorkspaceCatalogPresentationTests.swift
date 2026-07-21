import CodexWorkbenchCore
import Foundation

func runWorkspaceCatalogPresentationTests(_ runner: inout TestRunner) {
    let source = CodexThreadMetadata(
        id: "source-thread",
        rawTitle: "设计账号工作台",
        projectPath: "/work/tools",
        createdAt: Date(timeIntervalSince1970: 100),
        updatedAt: Date(timeIntervalSince1970: 200),
        sourceThreadID: nil
    )
    let continued = CodexThreadMetadata(
        id: "continued-thread",
        rawTitle: "接续：账号工作台",
        projectPath: "/work/tools",
        createdAt: Date(timeIntervalSince1970: 300),
        updatedAt: Date(timeIntervalSince1970: 600),
        sourceThreadID: "source-thread"
    )
    let newest = CodexThreadMetadata(
        id: "newest-thread",
        rawTitle: "整理项目文档",
        projectPath: "/work/documents",
        createdAt: Date(timeIntervalSince1970: 400),
        updatedAt: Date(timeIntervalSince1970: 800),
        sourceThreadID: nil
    )
    let card = ContextCardEvidence(
        generatedAt: Date(timeIntervalSince1970: 700),
        trigger: "PreCompact",
        threadID: "continued-thread",
        projectPath: "/work/tools",
        sourcePath: "/safe/context-card.md",
        summary: ContextCardSummary(topic: "工作台产品化")
    )
    let hook = WorkflowFileFingerprint(
        path: "/safe/hooks/context-summary.py",
        kind: .hook,
        label: "context-summary",
        modifiedAt: Date(timeIntervalSince1970: 900),
        fingerprint: "hook-v1",
        semanticSnapshot: WorkflowSemanticSnapshot(
            name: "上下文摘要 Hook",
            status: "enabled",
            purpose: "在压缩前生成摘要"
        )
    )
    let automation = WorkflowFileFingerprint(
        path: "/safe/automations/weekly/automation.toml",
        kind: .automation,
        label: "weekly",
        modifiedAt: Date(timeIntervalSince1970: 950),
        fingerprint: "automation-v1",
        semanticSnapshot: WorkflowSemanticSnapshot(
            name: "每周回顾",
            status: "active",
            schedule: "MON 09:00"
        )
    )
    let unrelated = WorkflowFileFingerprint(
        path: "/safe/skills/review/SKILL.md",
        kind: .skill,
        label: "review",
        modifiedAt: Date(timeIntervalSince1970: 960),
        fingerprint: "skill-v1"
    )

    let presentation = WorkspaceCatalogPresentationBuilder.build(
        catalog: CodexMetadataCatalog(records: [source, continued, newest]),
        contextCards: [card],
        workflowFiles: [hook, automation, unrelated]
    )

    runner.expect(
        presentation.recentThreads.map(\.id)
            == ["newest-thread", "continued-thread", "source-thread"],
        "Recent tasks should be sorted by updated time"
    )
    runner.expect(
        presentation.projects.map(\.name) == ["documents", "tools"],
        "Projects should be grouped and sorted by their latest task"
    )
    runner.expect(
        presentation.projects.last?.threads.map(\.id)
            == ["continued-thread", "source-thread"],
        "Tasks inside a project should remain newest first"
    )
    let continuedItem = presentation.recentThreads.first { $0.id == "continued-thread" }
    runner.expect(
        continuedItem?.sourceThreadID == "source-thread"
            && continuedItem?.sourceThreadTitle == "设计账号工作台",
        "Continuation tasks should identify their source task"
    )
    runner.expect(
        continuedItem?.hasContextSummary == true
            && continuedItem?.contextTopic == "工作台产品化",
        "Only a real context card should produce a summary marker"
    )
    runner.expect(
        presentation.recentThreads.first { $0.id == "newest-thread" }?.hasContextSummary == false,
        "A missing context card must not invent a health or summary state"
    )
    runner.expect(presentation.contextSummaryCount == 1, "Summary coverage should be a factual count")
    runner.expect(
        presentation.workflows.hooks.first?.name == "上下文摘要 Hook"
            && presentation.workflows.hooks.first?.status == "enabled",
        "Hooks should expose real semantic names and statuses"
    )
    runner.expect(
        presentation.workflows.automations.first?.name == "每周回顾"
            && presentation.workflows.automations.first?.status == "active"
            && presentation.workflows.automations.first?.schedule == "MON 09:00",
        "Automations should expose their real status and schedule"
    )
    runner.expect(
        presentation.workflows.hooks.count == 1
            && presentation.workflows.automations.count == 1,
        "Skills and other workflow files must not leak into hook and automation sections"
    )
}

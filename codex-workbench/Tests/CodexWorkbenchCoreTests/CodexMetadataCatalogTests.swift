import CodexWorkbenchCore
import Foundation

func runCodexMetadataCatalogTests(_ runner: inout TestRunner) {
    let source = CodexThreadMetadata(
        id: "thread-source",
        rawTitle: "系统日志时间轴设计",
        projectPath: "/Users/dysania/program/tools",
        createdAt: Date(timeIntervalSince1970: 100),
        updatedAt: Date(timeIntervalSince1970: 200),
        sourceThreadID: nil
    )
    let continued = CodexThreadMetadata(
        id: "thread-target",
        rawTitle: """
        <codex_delegation>
        <source_thread_id>thread-source</source_thread_id>
        <input># 接续：系统日志时间轴

        请基于 continuation pack 继续。
        </input>
        </codex_delegation>
        """,
        projectPath: "/Users/dysania/program/tools",
        createdAt: Date(timeIntervalSince1970: 300),
        updatedAt: Date(timeIntervalSince1970: 400),
        sourceThreadID: "thread-source"
    )
    let ordinary = CodexThreadMetadata(
        id: "thread-ordinary",
        rawTitle: "在现有项目中新建普通对话",
        projectPath: "/Users/dysania/program/tools",
        createdAt: Date(timeIntervalSince1970: 500),
        updatedAt: Date(timeIntervalSince1970: 600),
        sourceThreadID: nil
    )
    let newProject = CodexThreadMetadata(
        id: "thread-new-project",
        rawTitle: "设计菜谱库存系统",
        projectPath: "/Users/dysania/program/env",
        createdAt: Date(timeIntervalSince1970: 700),
        updatedAt: Date(timeIntervalSince1970: 800),
        sourceThreadID: nil
    )
    let catalog = CodexMetadataCatalog(records: [source, continued, ordinary, newProject])

    runner.expect(
        catalog.thread(id: "thread-target")?.title == "接续：系统日志时间轴",
        "Structured delegation titles should collapse to a useful conversation name"
    )
    runner.expect(
        catalog.thread(id: "thread-new-project")?.projectName == "env",
        "Project name should come from the normalized workspace path"
    )

    let baselineProjects = ProjectSpaceEventFactory().events(
        previousProjectPaths: nil,
        current: catalog,
        observedAt: Date(timeIntervalSince1970: 900)
    )
    runner.expect(baselineProjects.isEmpty, "The first project scan should establish a baseline without history spam")

    let projectEvents = ProjectSpaceEventFactory().events(
        previousProjectPaths: ["/Users/dysania/program/tools"],
        current: catalog,
        observedAt: Date(timeIntervalSince1970: 900)
    )
    runner.expect(projectEvents.count == 1, "Only a newly observed project path should create a project event")
    runner.expect(projectEvents.first?.action == "project_space_discovered", "New project event should use a stable action")
    runner.expect(projectEvents.first?.project?.name == "env", "New project event should retain project identity")
    runner.expect(projectEvents.first?.importance == .important, "New project spaces should be important")

    let baselineContinuations = ThreadContinuationEventFactory().events(
        previousThreadIDs: nil,
        current: catalog,
        observedAt: Date(timeIntervalSince1970: 900)
    )
    runner.expect(baselineContinuations.isEmpty, "The first thread scan should not replay historical continuations")

    let continuationEvents = ThreadContinuationEventFactory().events(
        previousThreadIDs: ["thread-source"],
        current: catalog,
        observedAt: Date(timeIntervalSince1970: 900)
    )
    runner.expect(continuationEvents.count == 1, "Only a new thread with a source thread should be logged")
    runner.expect(continuationEvents.first?.action == "thread_continued", "Continuation should use an explicit action")
    runner.expect(continuationEvents.first?.thread?.title == "接续：系统日志时间轴", "Continuation should expose target conversation title")
    runner.expect(
        continuationEvents.first?.summary.contains("系统日志时间轴设计") == true,
        "Continuation summary should expose the source conversation name"
    )

    let ordinaryOnly = CodexMetadataCatalog(records: [source, ordinary])
    let ordinaryEvents = ThreadContinuationEventFactory().events(
        previousThreadIDs: ["thread-source"],
        current: ordinaryOnly,
        observedAt: Date(timeIntervalSince1970: 900)
    )
    runner.expect(ordinaryEvents.isEmpty, "An ordinary new conversation in an existing project should not be logged")
}

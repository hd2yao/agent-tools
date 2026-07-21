import Foundation

public struct WorkspaceThreadPresentation: Equatable, Sendable {
    public let id: String
    public let title: String
    public let projectName: String
    public let projectPath: String
    public let updatedAt: Date
    public let sourceThreadID: String?
    public let sourceThreadTitle: String?
    public let hasContextSummary: Bool
    public let contextTopic: String?

    public init(
        id: String,
        title: String,
        projectName: String,
        projectPath: String,
        updatedAt: Date,
        sourceThreadID: String?,
        sourceThreadTitle: String?,
        hasContextSummary: Bool,
        contextTopic: String?
    ) {
        self.id = id
        self.title = title
        self.projectName = projectName
        self.projectPath = projectPath
        self.updatedAt = updatedAt
        self.sourceThreadID = sourceThreadID
        self.sourceThreadTitle = sourceThreadTitle
        self.hasContextSummary = hasContextSummary
        self.contextTopic = contextTopic
    }
}

public struct WorkspaceProjectPresentation: Equatable, Sendable {
    public let name: String
    public let path: String
    public let updatedAt: Date
    public let threads: [WorkspaceThreadPresentation]

    public init(
        name: String,
        path: String,
        updatedAt: Date,
        threads: [WorkspaceThreadPresentation]
    ) {
        self.name = name
        self.path = path
        self.updatedAt = updatedAt
        self.threads = threads
    }
}

public struct WorkflowItemPresentation: Equatable, Sendable {
    public let id: String
    public let name: String
    public let status: String?
    public let schedule: String?
    public let purpose: String?
    public let modifiedAt: Date

    public init(
        id: String,
        name: String,
        status: String?,
        schedule: String?,
        purpose: String?,
        modifiedAt: Date
    ) {
        self.id = id
        self.name = name
        self.status = status
        self.schedule = schedule
        self.purpose = purpose
        self.modifiedAt = modifiedAt
    }
}

public struct WorkflowCatalogPresentation: Equatable, Sendable {
    public let hooks: [WorkflowItemPresentation]
    public let automations: [WorkflowItemPresentation]

    public init(
        hooks: [WorkflowItemPresentation],
        automations: [WorkflowItemPresentation]
    ) {
        self.hooks = hooks
        self.automations = automations
    }
}

public struct WorkspaceCatalogPresentation: Equatable, Sendable {
    public let projects: [WorkspaceProjectPresentation]
    public let recentThreads: [WorkspaceThreadPresentation]
    public let contextSummaryCount: Int
    public let workflows: WorkflowCatalogPresentation

    public init(
        projects: [WorkspaceProjectPresentation],
        recentThreads: [WorkspaceThreadPresentation],
        contextSummaryCount: Int,
        workflows: WorkflowCatalogPresentation
    ) {
        self.projects = projects
        self.recentThreads = recentThreads
        self.contextSummaryCount = contextSummaryCount
        self.workflows = workflows
    }
}

public enum WorkspaceCatalogPresentationBuilder {
    public static func build(
        catalog: CodexMetadataCatalog,
        contextCards: [ContextCardEvidence],
        workflowFiles: [WorkflowFileFingerprint]
    ) -> WorkspaceCatalogPresentation {
        let latestCardByThread = latestCardsByThread(contextCards)
        let recentThreads = catalog.records.map { thread in
            let card = latestCardByThread[thread.id]
            return WorkspaceThreadPresentation(
                id: thread.id,
                title: thread.title,
                projectName: thread.projectName,
                projectPath: thread.projectPath,
                updatedAt: thread.updatedAt,
                sourceThreadID: thread.sourceThreadID,
                sourceThreadTitle: thread.sourceThreadID.flatMap { catalog.thread(id: $0)?.title },
                hasContextSummary: card != nil,
                contextTopic: card?.summary.topic
            )
        }

        let grouped = Dictionary(grouping: recentThreads, by: \.projectPath)
        let projects = grouped.map { path, threads in
            let sorted = threads.sorted { $0.updatedAt > $1.updatedAt }
            return WorkspaceProjectPresentation(
                name: sorted.first?.projectName
                    ?? URL(fileURLWithPath: path).lastPathComponent,
                path: path,
                updatedAt: sorted.first?.updatedAt ?? .distantPast,
                threads: sorted
            )
        }.sorted {
            if $0.updatedAt != $1.updatedAt { return $0.updatedAt > $1.updatedAt }
            return $0.path < $1.path
        }

        return WorkspaceCatalogPresentation(
            projects: projects,
            recentThreads: recentThreads,
            contextSummaryCount: latestCardByThread.count,
            workflows: WorkflowCatalogPresentation(
                hooks: workflowItems(kind: .hook, files: workflowFiles),
                automations: workflowItems(kind: .automation, files: workflowFiles)
            )
        )
    }

    private static func latestCardsByThread(
        _ cards: [ContextCardEvidence]
    ) -> [String: ContextCardEvidence] {
        var result: [String: ContextCardEvidence] = [:]
        for card in cards {
            if let existing = result[card.threadID], existing.generatedAt >= card.generatedAt {
                continue
            }
            result[card.threadID] = card
        }
        return result
    }

    private static func workflowItems(
        kind: WorkflowFileKind,
        files: [WorkflowFileFingerprint]
    ) -> [WorkflowItemPresentation] {
        files.filter { $0.kind == kind }.map { file in
            WorkflowItemPresentation(
                id: file.path,
                name: file.semanticSnapshot?.name ?? file.label,
                status: file.semanticSnapshot?.status,
                schedule: file.semanticSnapshot?.schedule,
                purpose: file.semanticSnapshot?.purpose,
                modifiedAt: file.modifiedAt
            )
        }.sorted {
            if $0.modifiedAt != $1.modifiedAt { return $0.modifiedAt > $1.modifiedAt }
            return $0.name < $1.name
        }
    }
}

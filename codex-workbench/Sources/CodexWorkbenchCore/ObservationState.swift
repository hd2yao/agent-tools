import Foundation

public struct ObservationState: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let updatedAt: Date
    public let projectPaths: Set<String>
    public let threadIDs: Set<String>
    public let workflowFiles: [String: WorkflowFileFingerprint]
    public let quotaByProfile: [String: QuotaObservation]

    public init(
        schemaVersion: Int = 1,
        updatedAt: Date,
        projectPaths: Set<String>,
        threadIDs: Set<String>,
        workflowFiles: [String: WorkflowFileFingerprint],
        quotaByProfile: [String: QuotaObservation]
    ) {
        self.schemaVersion = schemaVersion
        self.updatedAt = updatedAt
        self.projectPaths = projectPaths
        self.threadIDs = threadIDs
        self.workflowFiles = workflowFiles
        self.quotaByProfile = quotaByProfile
    }
}

public struct ObservationStateStore: Sendable {
    public init() {}

    public func load(from fileURL: URL) -> ObservationState? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? LedgerRepository.decoder().decode(ObservationState.self, from: data)
    }

    @discardableResult
    public func save(_ state: ObservationState, to fileURL: URL) -> Bool {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let encoder = LedgerWriter.encoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            try encoder.encode(state).write(to: fileURL, options: [.atomic])
            return true
        } catch {
            return false
        }
    }
}

public struct ObservationReconciliation: Equatable, Sendable {
    public let events: [OperationEvent]
    public let state: ObservationState

    public init(events: [OperationEvent], state: ObservationState) {
        self.events = events
        self.state = state
    }
}

public struct ObservationStateReconciler: Sendable {
    public init() {}

    public func reconcile(
        previous: ObservationState?,
        evidence: EvidenceSnapshot,
        accountPayload: AccountDashboardPayload?,
        existingEvents: [OperationEvent],
        observedAt: Date
    ) -> ObservationReconciliation {
        var events: [OperationEvent] = []

        events += ProjectSpaceEventFactory().events(
            previousProjectPaths: previous?.projectPaths,
            current: evidence.threadCatalog,
            observedAt: observedAt
        )
        events += ThreadContinuationEventFactory().events(
            previousThreadIDs: previous?.threadIDs,
            current: evidence.threadCatalog,
            observedAt: observedAt
        )
        events += WorkflowChangeEventFactory().events(
            previous: previous?.workflowFiles,
            current: evidence.workflowFiles,
            observedAt: observedAt
        )

        var quotaByProfile = previous?.quotaByProfile ?? [:]
        if let accountPayload {
            for observation in Self.quotaObservations(from: accountPayload) {
                if let old = quotaByProfile[observation.profile] {
                    events += QuotaEventFactory().events(
                        previous: old,
                        current: observation,
                        localResetEvents: existingEvents
                    )
                }
                quotaByProfile[observation.profile] = observation
            }
        }

        let hasThreadSnapshot = !evidence.threadCatalog.records.isEmpty
        let hasWorkflowSnapshot = !evidence.workflowFiles.isEmpty
        let state = ObservationState(
            updatedAt: observedAt,
            projectPaths: hasThreadSnapshot
                ? evidence.threadCatalog.projectPaths
                : (previous?.projectPaths ?? []),
            threadIDs: hasThreadSnapshot
                ? evidence.threadCatalog.threadIDs
                : (previous?.threadIDs ?? []),
            workflowFiles: hasWorkflowSnapshot
                ? Dictionary(uniqueKeysWithValues: evidence.workflowFiles.map { ($0.path, $0) })
                : (previous?.workflowFiles ?? [:]),
            quotaByProfile: quotaByProfile
        )
        return ObservationReconciliation(
            events: events.sorted { $0.occurredAt > $1.occurredAt },
            state: state
        )
    }

    public static func quotaObservations(
        from payload: AccountDashboardPayload
    ) -> [QuotaObservation] {
        payload.profiles.compactMap { profile in
            let remaining = profile.rateLimits.primary?.remainingPercent
            let resetsAt = profile.rateLimits.primary?.resetsAtDate
            let resetCredits = profile.resetCreditDetails?.availableCount
                ?? profile.rateLimits.resetCredits?.availableCount
            let reachedType = profile.rateLimits.reachedType
            guard
                remaining != nil
                    || resetsAt != nil
                    || resetCredits != nil
                    || reachedType != nil
            else {
                return nil
            }
            return QuotaObservation(
                profile: profile.name,
                observedAt: payload.generatedAt,
                remainingPercent: remaining,
                resetsAt: resetsAt,
                resetCredits: resetCredits,
                reachedType: reachedType
            )
        }
    }
}

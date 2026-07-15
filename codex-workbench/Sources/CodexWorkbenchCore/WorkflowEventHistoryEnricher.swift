import Foundation

public struct AutomationUpdateEvidence: Equatable, Sendable {
    public let sourceThread: CodexThreadMetadata
    public let targetThreadID: String?
    public let previousSnapshot: WorkflowSemanticSnapshot?
    public let currentSnapshot: WorkflowSemanticSnapshot
    public let evidencePath: String

    public init(
        sourceThread: CodexThreadMetadata,
        targetThreadID: String?,
        previousSnapshot: WorkflowSemanticSnapshot?,
        currentSnapshot: WorkflowSemanticSnapshot,
        evidencePath: String
    ) {
        self.sourceThread = sourceThread
        self.targetThreadID = targetThreadID
        self.previousSnapshot = previousSnapshot
        self.currentSnapshot = currentSnapshot
        self.evidencePath = evidencePath
    }
}

public struct AutomationSessionEvidenceCollector: Sendable {
    public let correlationWindow: TimeInterval

    public init(correlationWindow: TimeInterval = 3) {
        self.correlationWindow = correlationWindow
    }

    public func evidence(
        automationID: String,
        occurredAt: Date,
        catalog: CodexMetadataCatalog
    ) -> [AutomationUpdateEvidence] {
        catalog.records.compactMap { thread in
            guard
                thread.createdAt <= occurredAt.addingTimeInterval(correlationWindow),
                thread.updatedAt >= occurredAt.addingTimeInterval(-60),
                thread.updatedAt <= occurredAt.addingTimeInterval(86_400),
                let rolloutPath = thread.rolloutPath
            else {
                return nil
            }
            return evidence(
                automationID: automationID,
                occurredAt: occurredAt,
                thread: thread,
                rolloutURL: URL(fileURLWithPath: rolloutPath)
            )
        }
    }

    private func evidence(
        automationID: String,
        occurredAt: Date,
        thread: CodexThreadMetadata,
        rolloutURL: URL
    ) -> AutomationUpdateEvidence? {
        guard let text = try? String(contentsOf: rolloutURL, encoding: .utf8) else { return nil }
        var previousSnapshot: WorkflowSemanticSnapshot?
        var matches: [(Date, String, WorkflowSemanticSnapshot?)] = []

        for rawLine in text.split(separator: "\n") {
            guard
                let data = String(rawLine).data(using: .utf8),
                let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let timestampText = object["timestamp"] as? String,
                let timestamp = Self.date(from: timestampText),
                let payload = object["payload"] as? [String: Any],
                let payloadType = payload["type"] as? String
            else {
                continue
            }

            if payloadType == "custom_tool_call_output", timestamp <= occurredAt {
                for candidate in Self.strings(in: payload["output"]) where
                    candidate.contains("id = \"\(automationID)\"") && candidate.contains("prompt =")
                {
                    previousSnapshot = WorkflowSemanticSnapshot.automation(content: candidate)
                }
                continue
            }

            guard
                payloadType == "custom_tool_call",
                abs(timestamp.timeIntervalSince(occurredAt)) <= correlationWindow,
                let input = payload["input"] as? String,
                input.contains("codex_app__automation_update"),
                Self.quotedValue(for: "id", in: input) == automationID,
                Self.quotedValue(for: "mode", in: input) == "update"
            else {
                continue
            }
            matches.append((timestamp, input, previousSnapshot))
        }

        guard matches.count == 1, let match = matches.first else { return nil }
        let input = match.1
        let previous = match.2
        let prompt = Self.templateLiteral(named: "prompt", in: input)
            ?? Self.quotedValue(for: "prompt", in: input)
        let targetThreadID = Self.quotedValue(for: "targetThreadId", in: input)
            ?? previous?.targetThreadID
        let snapshot = WorkflowSemanticSnapshot(
            name: Self.quotedValue(for: "name", in: input) ?? previous?.name,
            status: Self.quotedValue(for: "status", in: input) ?? previous?.status,
            schedule: Self.quotedValue(for: "rrule", in: input) ?? previous?.schedule,
            targetThreadID: targetThreadID,
            capabilities: prompt.map(AutomationCapabilityClassifier.labels(in:))
                ?? previous?.capabilities
                ?? []
        )
        return AutomationUpdateEvidence(
            sourceThread: thread,
            targetThreadID: targetThreadID,
            previousSnapshot: previous,
            currentSnapshot: snapshot,
            evidencePath: rolloutURL.path
        )
    }

    private static func strings(in value: Any?) -> [String] {
        if let string = value as? String { return [string] }
        if let array = value as? [Any] { return array.flatMap(strings(in:)) }
        if let dictionary = value as? [String: Any] {
            return dictionary.values.flatMap(strings(in:))
        }
        return []
    }

    private static func quotedValue(for key: String, in text: String) -> String? {
        capture(pattern: #"\b"# + NSRegularExpression.escapedPattern(for: key) + #"\s*:\s*\"([^\"]*)\""#, in: text)
    }

    private static func templateLiteral(named name: String, in text: String) -> String? {
        capture(
            pattern: #"\b(?:const|let|var)\s+"#
                + NSRegularExpression.escapedPattern(for: name)
                + #"\s*=\s*`([\s\S]*?)`;"#,
            in: text
        )
    }

    private static func capture(pattern: String, in text: String) -> String? {
        guard
            let expression = try? NSRegularExpression(pattern: pattern),
            let match = expression.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
            let range = Range(match.range(at: 1), in: text)
        else {
            return nil
        }
        return String(text[range])
    }

    private static func date(from value: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let standard = ISO8601DateFormatter()
        standard.formatOptions = [.withInternetDateTime]
        return fractional.date(from: value) ?? standard.date(from: value)
    }
}

public struct WorkflowEventHistoryEnricher: Sendable {
    public init() {}

    public func revisions(
        events: [OperationEvent],
        catalog: CodexMetadataCatalog,
        recordedAt: Date
    ) -> [OperationEvent] {
        events.compactMap { event in
            guard
                event.action == "automation_updated",
                event.changes?.isEmpty != false || event.thread == nil,
                let automationID = automationID(from: event),
                let path = event.evidence.first(where: { $0.kind == "file_fingerprint" })?.path
            else {
                return nil
            }
            let matches = AutomationSessionEvidenceCollector().evidence(
                automationID: automationID,
                occurredAt: event.occurredAt,
                catalog: catalog
            )
            guard matches.count == 1, let match = matches.first else { return nil }

            let oldFingerprint = fingerprint(in: event.before) ?? "legacy-before"
            let newFingerprint = fingerprint(in: event.after) ?? "legacy-after"
            let old = WorkflowFileFingerprint(
                path: path,
                kind: .automation,
                label: automationID,
                modifiedAt: event.occurredAt,
                fingerprint: oldFingerprint,
                semanticSnapshot: match.previousSnapshot
            )
            let current = WorkflowFileFingerprint(
                path: path,
                kind: .automation,
                label: automationID,
                modifiedAt: event.occurredAt,
                fingerprint: newFingerprint,
                semanticSnapshot: match.currentSnapshot
            )
            guard let semantic = WorkflowChangeEventFactory().events(
                previous: [path: old],
                current: [current],
                observedAt: recordedAt
            ).first else {
                return nil
            }

            let source = match.sourceThread
            var related = [EventRelatedThread(
                role: .modificationSource,
                id: source.id,
                title: source.title,
                projectName: source.projectName,
                projectPath: source.projectPath
            )]
            if let targetID = match.targetThreadID {
                let target = catalog.thread(id: targetID)
                related.append(EventRelatedThread(
                    role: .deliveryTarget,
                    id: targetID,
                    title: target?.title,
                    projectName: target?.projectName,
                    projectPath: target?.projectPath
                ))
            }
            return OperationEvent(
                schemaVersion: event.schemaVersion,
                id: event.id,
                occurredAt: event.occurredAt,
                recordedAt: recordedAt,
                category: event.category,
                action: event.action,
                title: event.title,
                summary: semantic.summary,
                status: event.status,
                importance: event.importance,
                certainty: .confirmed,
                actor: event.actor,
                thread: EventThread(id: source.id, title: source.title, relation: .triggeredBy),
                project: EventProject(name: source.projectName, path: source.projectPath),
                account: event.account,
                scope: .globalWorkflow,
                changes: semantic.changes,
                relatedThreads: related,
                sourceChain: event.sourceChain + [
                    EventActor(type: .system, id: "structured-automation-update", label: "Automation 更新调用"),
                ],
                before: event.before,
                after: event.after,
                evidence: event.evidence + [
                    EventEvidence(
                        kind: "structured_automation_update",
                        label: "结构化 Automation 更新调用",
                        path: match.evidencePath
                    ),
                ]
            )
        }
    }

    private func automationID(from event: OperationEvent) -> String? {
        if !event.actor.label.isEmpty { return event.actor.label }
        return event.evidence.first?.path.map {
            URL(fileURLWithPath: $0).deletingLastPathComponent().lastPathComponent
        }
    }

    private func fingerprint(in value: JSONValue?) -> String? {
        guard case .object(let object) = value, case .string(let fingerprint) = object["fingerprint"] else {
            return nil
        }
        return fingerprint
    }
}

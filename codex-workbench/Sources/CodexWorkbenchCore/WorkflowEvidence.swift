import Foundation

public enum WorkflowFileKind: String, Codable, Equatable, Sendable {
    case automation
    case configuration
    case hook
    case plugin
    case rule
    case skill
}

public struct WorkflowFileDescriptor: Equatable, Sendable {
    public let kind: WorkflowFileKind
    public let label: String

    public init(kind: WorkflowFileKind, label: String) {
        self.kind = kind
        self.label = label
    }
}

public enum WorkflowFileClassifier {
    public static func classify(path: String) -> WorkflowFileDescriptor? {
        let standardized = URL(fileURLWithPath: path).standardizedFileURL.path
        let lowercased = standardized.lowercased()
        let url = URL(fileURLWithPath: standardized)
        let name = url.lastPathComponent

        guard
            !lowercased.contains("/__pycache__/"),
            !lowercased.hasSuffix(".pyc"),
            !lowercased.contains("/operation-ledger/"),
            !lowercased.contains("/auth.json"),
            !lowercased.contains("token"),
            !lowercased.contains("secret"),
            !lowercased.contains("cookie"),
            !lowercased.contains(".bak")
        else {
            return nil
        }

        if name == "AGENTS.md" {
            return WorkflowFileDescriptor(kind: .rule, label: "Codex 全局规则")
        }
        if lowercased.contains("/skills/"), name == "SKILL.md" {
            return WorkflowFileDescriptor(kind: .skill, label: url.deletingLastPathComponent().lastPathComponent)
        }
        if lowercased.contains("/hooks/"), url.pathExtension == "py" || name == "hooks.json" {
            return WorkflowFileDescriptor(kind: .hook, label: url.deletingPathExtension().lastPathComponent)
        }
        if lowercased.contains("/automations/"), name == "automation.toml" {
            return WorkflowFileDescriptor(kind: .automation, label: url.deletingLastPathComponent().lastPathComponent)
        }
        if lowercased.contains("/plugins/"),
           ["json", "toml", "yaml", "yml"].contains(url.pathExtension.lowercased()) {
            return WorkflowFileDescriptor(kind: .plugin, label: url.deletingPathExtension().lastPathComponent)
        }
        if name == "config.toml" || name == "hooks.json" {
            return WorkflowFileDescriptor(kind: .configuration, label: name)
        }
        return nil
    }
}

public struct WorkflowFileFingerprint: Codable, Equatable, Sendable {
    public let path: String
    public let kind: WorkflowFileKind
    public let label: String
    public let modifiedAt: Date
    public let fingerprint: String

    public init(
        path: String,
        kind: WorkflowFileKind,
        label: String,
        modifiedAt: Date,
        fingerprint: String
    ) {
        self.path = URL(fileURLWithPath: path).standardizedFileURL.path
        self.kind = kind
        self.label = label
        self.modifiedAt = modifiedAt
        self.fingerprint = fingerprint
    }
}

public struct WorkflowFileCollector: Sendable {
    public init() {}

    public func collect(roots: [URL]) -> [WorkflowFileFingerprint] {
        var fingerprints: [String: WorkflowFileFingerprint] = [:]
        for root in roots {
            if let fingerprint = fingerprint(at: root) {
                fingerprints[fingerprint.path] = fingerprint
                continue
            }
            guard let enumerator = FileManager.default.enumerator(
                at: root,
                includingPropertiesForKeys: [.isRegularFileKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else {
                continue
            }
            for case let url as URL in enumerator {
                if let fingerprint = fingerprint(at: url) {
                    fingerprints[fingerprint.path] = fingerprint
                }
            }
        }
        return fingerprints.values.sorted { $0.path < $1.path }
    }

    private func fingerprint(at url: URL) -> WorkflowFileFingerprint? {
        guard
            let descriptor = WorkflowFileClassifier.classify(path: url.path),
            let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .contentModificationDateKey]),
            values.isRegularFile == true,
            let data = try? Data(contentsOf: url, options: [.mappedIfSafe])
        else {
            return nil
        }
        return WorkflowFileFingerprint(
            path: url.path,
            kind: descriptor.kind,
            label: descriptor.label,
            modifiedAt: values.contentModificationDate ?? .distantPast,
            fingerprint: StableEventID.make(parts: ["workflow-file", data.base64EncodedString()])
        )
    }
}

public struct WorkflowChangeEventFactory: Sendable {
    public init() {}

    public func events(
        previous: [String: WorkflowFileFingerprint]?,
        current: [WorkflowFileFingerprint],
        observedAt: Date
    ) -> [OperationEvent] {
        guard let previous else { return [] }
        let currentByPath = Dictionary(uniqueKeysWithValues: current.map { ($0.path, $0) })
        var result: [OperationEvent] = []

        for fingerprint in current {
            if let old = previous[fingerprint.path] {
                guard old.fingerprint != fingerprint.fingerprint else { continue }
                result.append(makeEvent(
                    change: "updated",
                    fingerprint: fingerprint,
                    occurredAt: fingerprint.modifiedAt,
                    recordedAt: observedAt,
                    before: old.fingerprint,
                    after: fingerprint.fingerprint
                ))
            } else {
                result.append(makeEvent(
                    change: "added",
                    fingerprint: fingerprint,
                    occurredAt: fingerprint.modifiedAt,
                    recordedAt: observedAt,
                    before: nil,
                    after: fingerprint.fingerprint
                ))
            }
        }

        for (path, old) in previous where currentByPath[path] == nil {
            result.append(makeEvent(
                change: "deleted",
                fingerprint: old,
                occurredAt: observedAt,
                recordedAt: observedAt,
                before: old.fingerprint,
                after: nil
            ))
        }
        return result.sorted { $0.occurredAt > $1.occurredAt }
    }

    private func makeEvent(
        change: String,
        fingerprint: WorkflowFileFingerprint,
        occurredAt: Date,
        recordedAt: Date,
        before: String?,
        after: String?
    ) -> OperationEvent {
        let noun = noun(for: fingerprint.kind)
        let verb = verb(for: change)
        return OperationEvent(
            schemaVersion: 1,
            id: StableEventID.make(parts: [
                "workflow-file",
                fingerprint.path,
                change,
                after ?? String(format: "%.6f", occurredAt.timeIntervalSince1970),
            ]),
            occurredAt: occurredAt,
            recordedAt: recordedAt,
            category: category(for: fingerprint.kind),
            action: "\(actionPrefix(for: fingerprint.kind))_\(change)",
            title: "\(noun)已\(verb)",
            summary: "\(fingerprint.label) 的全局工作流定义已\(verb)。",
            status: .success,
            importance: .important,
            certainty: .confirmed,
            actor: EventActor(
                type: actorType(for: fingerprint.kind),
                id: "workflow-file-monitor",
                label: fingerprint.label
            ),
            sourceChain: [
                EventActor(type: .system, id: "workflow-file-monitor", label: "工作流文件监视器"),
            ],
            before: before.map { .object(["fingerprint": .string($0)]) },
            after: after.map { .object(["fingerprint": .string($0)]) },
            evidence: [
                EventEvidence(kind: "file_fingerprint", label: "受控工作流文件指纹", path: fingerprint.path),
            ]
        )
    }

    private func actionPrefix(for kind: WorkflowFileKind) -> String {
        switch kind {
        case .rule: "workflow_rule"
        case .configuration: "workflow_config"
        case .skill: "skill"
        case .hook: "hook"
        case .plugin: "plugin"
        case .automation: "automation"
        }
    }

    private func noun(for kind: WorkflowFileKind) -> String {
        switch kind {
        case .rule: "全局规则"
        case .configuration: "Codex 配置"
        case .skill: "Skill"
        case .hook: "Hook"
        case .plugin: "Plugin"
        case .automation: "Automation"
        }
    }

    private func verb(for change: String) -> String {
        switch change {
        case "added": "新增"
        case "deleted": "删除"
        default: "更新"
        }
    }

    private func actorType(for kind: WorkflowFileKind) -> EventActorType {
        switch kind {
        case .skill: .skill
        case .hook: .hook
        case .plugin: .plugin
        case .automation: .automation
        case .rule, .configuration: .system
        }
    }

    private func category(for kind: WorkflowFileKind) -> EventCategory {
        switch kind {
        case .skill: .skill
        case .hook: .hook
        case .plugin: .plugin
        case .automation: .automation
        case .rule, .configuration: .system
        }
    }
}

public struct DailyDigestEvidence: Codable, Equatable, Sendable {
    public let day: String
    public let generatedAt: Date
    public let sourcePath: String

    public init(day: String, generatedAt: Date, sourcePath: String) {
        self.day = day
        self.generatedAt = generatedAt
        self.sourcePath = sourcePath
    }
}

public struct DailyDigestEventFactory: Sendable {
    public init() {}

    public func event(from evidence: DailyDigestEvidence, recordedAt: Date) -> OperationEvent {
        OperationEvent(
            schemaVersion: 1,
            id: StableEventID.make(parts: ["daily-digest", evidence.day]),
            occurredAt: evidence.generatedAt,
            recordedAt: recordedAt,
            category: .automation,
            action: "daily_digest_generated",
            title: "每日摘要已生成",
            summary: "\(evidence.day) 的 Codex 每日摘要已更新。",
            status: .success,
            importance: .important,
            certainty: .confirmed,
            actor: EventActor(type: .automation, id: "daily-digest", label: "DailyDigest"),
            sourceChain: [
                EventActor(type: .automation, id: "daily-digest", label: "DailyDigest"),
                EventActor(type: .hook, id: "task-ledger", label: "任务台账"),
            ],
            evidence: [
                EventEvidence(kind: "daily_digest", label: "每日摘要文件", path: evidence.sourcePath),
            ]
        )
    }
}

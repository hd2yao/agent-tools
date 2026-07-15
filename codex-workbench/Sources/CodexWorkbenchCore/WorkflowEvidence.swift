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
    public let semanticSnapshot: WorkflowSemanticSnapshot?

    public init(
        path: String,
        kind: WorkflowFileKind,
        label: String,
        modifiedAt: Date,
        fingerprint: String,
        semanticSnapshot: WorkflowSemanticSnapshot? = nil
    ) {
        self.path = URL(fileURLWithPath: path).standardizedFileURL.path
        self.kind = kind
        self.label = label
        self.modifiedAt = modifiedAt
        self.fingerprint = fingerprint
        self.semanticSnapshot = semanticSnapshot
    }
}

public struct WorkflowSemanticSnapshot: Codable, Equatable, Sendable {
    public let name: String?
    public let status: String?
    public let schedule: String?
    public let targetThreadID: String?
    public let capabilities: [String]

    public init(
        name: String? = nil,
        status: String? = nil,
        schedule: String? = nil,
        targetThreadID: String? = nil,
        capabilities: [String] = []
    ) {
        self.name = name
        self.status = status
        self.schedule = schedule
        self.targetThreadID = targetThreadID
        self.capabilities = Array(Set(capabilities)).sorted()
    }

    public static func automation(content: String) -> Self {
        let prompt = TOMLScalarReader.string(for: "prompt", in: content) ?? ""
        return Self(
            name: TOMLScalarReader.string(for: "name", in: content),
            status: TOMLScalarReader.string(for: "status", in: content),
            schedule: TOMLScalarReader.string(for: "rrule", in: content),
            targetThreadID: TOMLScalarReader.string(for: "target_thread_id", in: content),
            capabilities: AutomationCapabilityClassifier.labels(in: prompt)
        )
    }
}

enum AutomationCapabilityClassifier {
    private static let rules: [(label: String, markers: [String])] = [
        ("每日摘要生成", ["DailyDigest"]),
        ("前一日工作采集", ["clear-activity", "record-activity"]),
        ("动态仓库操作预算", ["repository-action-budget.py"]),
        ("已合并工作区清理", ["git worktree remove"]),
        ("未集成提交远端保护", ["codex/preserve/"]),
        ("PR 自动集成", ["gh pr merge"]),
        ("临时图片安全清理", ["临时截图", "codex-clipboard"]),
        ("运行指标记录", ["--duration-seconds", "--unsafe-actions"]),
        ("周一工作流复盘", ["retrospect_workflows.py"]),
        ("仓库收尾审计", ["repository-closure-audit.py"]),
    ]

    static func labels(in prompt: String) -> [String] {
        rules.compactMap { rule in
            rule.markers.contains { prompt.localizedCaseInsensitiveContains($0) }
                ? rule.label
                : nil
        }
    }
}

enum TOMLScalarReader {
    static func string(for key: String, in content: String) -> String? {
        for rawLine in content.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard line.hasPrefix("\(key) =") else { continue }
            let rawValue = line.dropFirst(key.count + 2)
                .trimmingCharacters(in: .whitespaces)
            guard !rawValue.isEmpty else { return nil }
            if rawValue.first == "\"",
               let data = rawValue.data(using: .utf8),
               let decoded = try? JSONDecoder().decode(String.self, from: data) {
                return decoded
            }
            return rawValue
        }
        return nil
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
            fingerprint: StableEventID.make(parts: ["workflow-file", data.base64EncodedString()]),
            semanticSnapshot: descriptor.kind == .automation
                ? WorkflowSemanticSnapshot.automation(content: String(decoding: data, as: UTF8.self))
                : nil
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
                    after: fingerprint.fingerprint,
                    previousSemanticSnapshot: old.semanticSnapshot
                ))
            } else {
                result.append(makeEvent(
                    change: "added",
                    fingerprint: fingerprint,
                    occurredAt: fingerprint.modifiedAt,
                    recordedAt: observedAt,
                    before: nil,
                    after: fingerprint.fingerprint,
                    previousSemanticSnapshot: nil
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
                after: nil,
                previousSemanticSnapshot: old.semanticSnapshot
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
        after: String?,
        previousSemanticSnapshot: WorkflowSemanticSnapshot?
    ) -> OperationEvent {
        let noun = noun(for: fingerprint.kind)
        let verb = verb(for: change)
        let eventChanges = changes(
            change: change,
            noun: noun,
            label: fingerprint.label,
            previous: previousSemanticSnapshot,
            current: fingerprint.semanticSnapshot
        )
        let targetThreads = (fingerprint.semanticSnapshot ?? previousSemanticSnapshot)?.targetThreadID.map {
            [EventRelatedThread(role: .deliveryTarget, id: $0)]
        }
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
            summary: summary(label: fingerprint.label, verb: verb, changes: eventChanges),
            status: .success,
            importance: .important,
            certainty: .confirmed,
            actor: EventActor(
                type: actorType(for: fingerprint.kind),
                id: "workflow-file-monitor",
                label: fingerprint.label
            ),
            scope: .globalWorkflow,
            changes: eventChanges,
            relatedThreads: targetThreads,
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

    private func changes(
        change: String,
        noun: String,
        label: String,
        previous: WorkflowSemanticSnapshot?,
        current: WorkflowSemanticSnapshot?
    ) -> [EventChange] {
        guard change == "updated" else {
            return [EventChange(label: "工作流定义", summary: "\(noun)「\(label)」已\(verb(for: change))")]
        }
        guard let previous, let current else {
            return [EventChange(label: "工作流定义", summary: "\(noun)「\(label)」内容已调整")]
        }
        var result: [EventChange] = []
        appendFieldChange(label: "名称", before: previous.name, after: current.name, to: &result)
        appendFieldChange(label: "状态", before: previous.status, after: current.status, to: &result)
        appendFieldChange(label: "执行计划", before: previous.schedule, after: current.schedule, to: &result)
        appendFieldChange(label: "投递目标", before: previous.targetThreadID, after: current.targetThreadID, to: &result)

        let oldCapabilities = Set(previous.capabilities)
        let newCapabilities = Set(current.capabilities)
        for capability in newCapabilities.subtracting(oldCapabilities).sorted() {
            result.append(EventChange(label: "新增能力", summary: capability, after: capability))
        }
        for capability in oldCapabilities.subtracting(newCapabilities).sorted() {
            result.append(EventChange(label: "移除能力", summary: capability, before: capability))
        }
        if result.isEmpty {
            result.append(EventChange(
                label: "工作流指令",
                summary: "Automation 指令内容已调整；未检测到可安全展示的结构变化"
            ))
        }
        return result
    }

    private func appendFieldChange(
        label: String,
        before: String?,
        after: String?,
        to result: inout [EventChange]
    ) {
        guard before != after else { return }
        let summary: String
        if let before, let after {
            summary = "\(label)由「\(before)」改为「\(after)」"
        } else if let after {
            summary = "设置\(label)为「\(after)」"
        } else {
            summary = "移除\(label)「\(before ?? "未知")」"
        }
        result.append(EventChange(label: label, summary: summary, before: before, after: after))
    }

    private func summary(label: String, verb: String, changes: [EventChange]) -> String {
        let readable = changes.prefix(3).map(\.summary).joined(separator: "；")
        return readable.isEmpty
            ? "\(label) 的全局工作流定义已\(verb)。"
            : "\(label)：\(readable)。"
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

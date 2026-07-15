import Foundation

public struct CodexThreadMetadata: Codable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let projectPath: String
    public let createdAt: Date
    public let updatedAt: Date
    public let sourceThreadID: String?

    public init(
        id: String,
        rawTitle: String,
        projectPath: String,
        createdAt: Date,
        updatedAt: Date,
        sourceThreadID: String?
    ) {
        self.id = id
        self.title = Self.normalizedTitle(rawTitle)
        self.projectPath = URL(fileURLWithPath: projectPath).standardizedFileURL.path
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.sourceThreadID = sourceThreadID
    }

    public var projectName: String {
        URL(fileURLWithPath: projectPath).lastPathComponent
    }

    public static func sourceThreadID(from text: String) -> String? {
        let patterns = [
            #"<source_thread_id>\s*([0-9A-Za-z-]+)\s*</source_thread_id>"#,
            #"Source Thread ID:\s*\u{0060}?([0-9A-Za-z-]+)\u{0060}?"#,
        ]
        for pattern in patterns {
            guard
                let expression = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
                let match = expression.firstMatch(
                    in: text,
                    range: NSRange(text.startIndex..., in: text)
                ),
                let range = Range(match.range(at: 1), in: text)
            else {
                continue
            }
            return String(text[range])
        }
        return nil
    }

    public static func normalizedTitle(_ rawTitle: String) -> String {
        var candidate = rawTitle
        if let input = firstCapture(
            pattern: #"<input>([\s\S]*?)</input>"#,
            in: rawTitle
        ) {
            candidate = input
        }

        let lines = candidate
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map {
                String($0)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: #"^#{1,6}\s*"#, with: "", options: .regularExpression)
                    .replacingOccurrences(of: #"^-\s*Title:\s*"#, with: "", options: .regularExpression)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\u{0060}"))
            }
        let preferred = lines.first {
            !$0.isEmpty
                && !$0.hasPrefix("<")
                && !$0.localizedCaseInsensitiveContains("source thread id")
                && $0 != "Codex Thread Continuation Pack"
                && $0 != "请基于 continuation pack 继续。"
        } ?? "未命名对话"
        let collapsed = preferred
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard collapsed.count > 64 else { return collapsed.isEmpty ? "未命名对话" : collapsed }
        return String(collapsed.prefix(61)) + "…"
    }

    private static func firstCapture(pattern: String, in text: String) -> String? {
        guard
            let expression = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
            let match = expression.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
            let range = Range(match.range(at: 1), in: text)
        else {
            return nil
        }
        return String(text[range])
    }
}

public struct CodexMetadataCatalog: Codable, Equatable, Sendable {
    public let records: [CodexThreadMetadata]

    public init(records: [CodexThreadMetadata] = []) {
        var byID: [String: CodexThreadMetadata] = [:]
        for record in records {
            if let existing = byID[record.id], existing.updatedAt > record.updatedAt {
                continue
            }
            byID[record.id] = record
        }
        self.records = byID.values.sorted { $0.updatedAt > $1.updatedAt }
    }

    public func thread(id: String) -> CodexThreadMetadata? {
        records.first { $0.id == id }
    }

    public var projectPaths: Set<String> {
        Set(records.map(\.projectPath))
    }

    public var threadIDs: Set<String> {
        Set(records.map(\.id))
    }
}

public struct CodexMetadataReadResult: Equatable, Sendable {
    public let catalog: CodexMetadataCatalog
    public let warnings: [String]

    public init(catalog: CodexMetadataCatalog, warnings: [String] = []) {
        self.catalog = catalog
        self.warnings = warnings
    }
}

public struct CodexMetadataCatalogReader: Sendable {
    public init() {}

    public func read(databaseURL: URL) -> CodexMetadataReadResult {
        guard FileManager.default.fileExists(atPath: databaseURL.path) else {
            return CodexMetadataReadResult(catalog: CodexMetadataCatalog())
        }

        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
        process.arguments = [
            "-readonly",
            "-json",
            databaseURL.path,
            """
            SELECT id, title, cwd, created_at, updated_at, first_user_message
            FROM threads
            ORDER BY updated_at DESC
            LIMIT 5000;
            """,
        ]
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            return CodexMetadataReadResult(
                catalog: CodexMetadataCatalog(),
                warnings: ["无法启动 Codex 线程目录读取器。"]
            )
        }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            return CodexMetadataReadResult(
                catalog: CodexMetadataCatalog(),
                warnings: ["无法读取 Codex 线程目录。"]
            )
        }
        do {
            let rows = try JSONDecoder().decode([RawThreadRow].self, from: data)
            return CodexMetadataReadResult(
                catalog: CodexMetadataCatalog(records: rows.map {
                    CodexThreadMetadata(
                        id: $0.id,
                        rawTitle: $0.title,
                        projectPath: $0.cwd,
                        createdAt: Date(timeIntervalSince1970: TimeInterval($0.createdAt)),
                        updatedAt: Date(timeIntervalSince1970: TimeInterval($0.updatedAt)),
                        sourceThreadID: CodexThreadMetadata.sourceThreadID(from: $0.firstUserMessage)
                    )
                })
            )
        } catch {
            return CodexMetadataReadResult(
                catalog: CodexMetadataCatalog(),
                warnings: ["Codex 线程目录格式不兼容。"]
            )
        }
    }
}

private struct RawThreadRow: Decodable {
    let id: String
    let title: String
    let cwd: String
    let createdAt: Int64
    let updatedAt: Int64
    let firstUserMessage: String

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case cwd
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case firstUserMessage = "first_user_message"
    }
}

public struct ProjectSpaceEventFactory: Sendable {
    public init() {}

    public func events(
        previousProjectPaths: Set<String>?,
        current: CodexMetadataCatalog,
        observedAt: Date
    ) -> [OperationEvent] {
        guard let previousProjectPaths else { return [] }
        let newPaths = current.projectPaths.subtracting(previousProjectPaths)
        return newPaths.compactMap { path in
            guard let firstThread = current.records
                .filter({ $0.projectPath == path })
                .min(by: { $0.createdAt < $1.createdAt })
            else {
                return nil
            }
            return OperationEvent(
                schemaVersion: 1,
                id: StableEventID.make(parts: [
                    "project-space",
                    path,
                    String(format: "%.6f", firstThread.createdAt.timeIntervalSince1970),
                ]),
                occurredAt: firstThread.createdAt,
                recordedAt: observedAt,
                category: .system,
                action: "project_space_discovered",
                title: "发现新项目空间",
                summary: "Codex 线程目录首次发现项目「\(firstThread.projectName)」。",
                status: .success,
                importance: .important,
                certainty: .inferred,
                actor: EventActor(type: .app, id: "codex-observatory", label: "Codex 观测站"),
                project: EventProject(name: firstThread.projectName, path: path),
                evidence: [
                    EventEvidence(kind: "codex_thread_catalog", label: "Codex 线程项目路径"),
                ]
            )
        }
        .sorted { $0.occurredAt > $1.occurredAt }
    }
}

public struct ThreadContinuationEventFactory: Sendable {
    public init() {}

    public func events(
        previousThreadIDs: Set<String>?,
        current: CodexMetadataCatalog,
        observedAt: Date
    ) -> [OperationEvent] {
        guard let previousThreadIDs else { return [] }
        return current.records.compactMap { target in
            guard
                !previousThreadIDs.contains(target.id),
                let sourceID = target.sourceThreadID
            else {
                return nil
            }
            let sourceTitle = current.thread(id: sourceID)?.title ?? "来源对话"
            return OperationEvent(
                schemaVersion: 1,
                id: StableEventID.make(parts: ["thread-continuation", sourceID, target.id]),
                occurredAt: target.createdAt,
                recordedAt: observedAt,
                category: .thread,
                action: "thread_continued",
                title: "已接续对话",
                summary: "从「\(sourceTitle)」接续到「\(target.title)」。",
                status: .success,
                importance: .important,
                certainty: .confirmed,
                actor: EventActor(type: .skill, id: "codex-thread-bridge", label: "Codex Thread Bridge"),
                thread: EventThread(id: target.id, title: target.title, relation: .target),
                project: EventProject(name: target.projectName, path: target.projectPath),
                sourceChain: [
                    EventActor(type: .skill, id: "codex-thread-bridge", label: "Codex Thread Bridge"),
                    EventActor(type: .system, id: "codex-thread-catalog", label: "Codex 线程目录"),
                ],
                before: .object([
                    "thread_id": .string(sourceID),
                    "thread_title": .string(sourceTitle),
                ]),
                after: .object([
                    "thread_id": .string(target.id),
                    "thread_title": .string(target.title),
                ]),
                evidence: [
                    EventEvidence(kind: "structured_thread_source", label: "结构化来源线程关系"),
                ]
            )
        }
        .sorted { $0.occurredAt > $1.occurredAt }
    }
}

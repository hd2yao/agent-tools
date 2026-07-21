import Foundation

public enum DiagnosticLevel: String, Equatable, Sendable {
    case info
    case warning
    case error
}

public enum DiagnosticAppLocation: String, Equatable, Sendable {
    case systemApplications = "系统 Applications"
    case userApplications = "用户 Applications"
    case other = "其他位置"
}

public struct DiagnosticAppInstallation: Equatable, Sendable {
    public let url: URL
    public let bundleIdentifier: String
    public let version: String?
    public let isRunning: Bool

    public init(
        url: URL,
        bundleIdentifier: String,
        version: String?,
        isRunning: Bool
    ) {
        self.url = url.standardizedFileURL
        self.bundleIdentifier = bundleIdentifier
        self.version = version
        self.isRunning = isRunning
    }

    public var displayName: String {
        url.deletingPathExtension().lastPathComponent
    }

    public var location: DiagnosticAppLocation {
        let path = url.path
        if path.hasPrefix("/Applications/") {
            return .systemApplications
        }
        if path.range(of: #"^/Users/[^/]+/Applications/"#, options: .regularExpression) != nil {
            return .userApplications
        }
        return .other
    }

    public var redactedFingerprint: String {
        var hash: UInt32 = 2_166_136_261
        for byte in url.path.utf8 {
            hash ^= UInt32(byte)
            hash &*= 16_777_619
        }
        return String(format: "%08x", hash)
    }
}

public struct WorkbenchDiagnosticInput: Equatable, Sendable {
    public let installedApps: [DiagnosticAppInstallation]
    public let selectedAppURL: URL?
    public let backendAvailable: Bool
    public let accountMode: AccountMode
    public let managedProfileCount: Int
    public let defaultHomeAvailable: Bool
    public let recentFailureStage: String?

    public init(
        installedApps: [DiagnosticAppInstallation],
        selectedAppURL: URL?,
        backendAvailable: Bool,
        accountMode: AccountMode,
        managedProfileCount: Int,
        defaultHomeAvailable: Bool,
        recentFailureStage: String? = nil
    ) {
        self.installedApps = installedApps
        self.selectedAppURL = selectedAppURL?.standardizedFileURL
        self.backendAvailable = backendAvailable
        self.accountMode = accountMode
        self.managedProfileCount = max(0, managedProfileCount)
        self.defaultHomeAvailable = defaultHomeAvailable
        self.recentFailureStage = recentFailureStage
    }
}

public struct DiagnosticFinding: Equatable, Sendable {
    public let id: String
    public let level: DiagnosticLevel
    public let title: String
    public let detail: String

    public init(id: String, level: DiagnosticLevel, title: String, detail: String) {
        self.id = id
        self.level = level
        self.title = title
        self.detail = detail
    }
}

public struct DiagnosticRevealTarget: Equatable, Sendable {
    public let label: String
    public let url: URL

    public init(label: String, url: URL) {
        self.label = label
        self.url = url
    }
}

public struct WorkbenchDiagnosticSnapshot: Equatable, Sendable {
    public let findings: [DiagnosticFinding]
    public let appSummaries: [String]
    public let revealTargets: [DiagnosticRevealTarget]
    public let copyableSummary: String

    public init(
        findings: [DiagnosticFinding],
        appSummaries: [String],
        revealTargets: [DiagnosticRevealTarget],
        copyableSummary: String
    ) {
        self.findings = findings
        self.appSummaries = appSummaries
        self.revealTargets = revealTargets
        self.copyableSummary = copyableSummary
    }
}

public enum WorkbenchDiagnosticsBuilder {
    public static func build(_ input: WorkbenchDiagnosticInput) -> WorkbenchDiagnosticSnapshot {
        let apps = uniqueApps(input.installedApps)
        var findings: [DiagnosticFinding] = []

        switch apps.count {
        case 0:
            findings.append(
                DiagnosticFinding(
                    id: "codex-app-missing",
                    level: .error,
                    title: "未找到 Codex App",
                    detail: "Launch Services 与常见 Applications 位置均未发现可用安装。"
                )
            )
        case 1:
            findings.append(
                DiagnosticFinding(
                    id: "codex-app-ready",
                    level: .info,
                    title: "Codex App 可用",
                    detail: "当前发现 1 个安装，打开动作将使用系统选择结果。"
                )
            )
        default:
            let selected = selectedAppName(apps: apps, selectedURL: input.selectedAppURL)
            findings.append(
                DiagnosticFinding(
                    id: "duplicate-codex-apps",
                    level: .warning,
                    title: "发现多个 Codex App",
                    detail: "共发现 \(apps.count) 个安装；系统当前选择：\(selected ?? "未知")。"
                )
            )
        }

        findings.append(
            input.backendAvailable
                ? DiagnosticFinding(
                    id: "account-backend-ready",
                    level: .info,
                    title: "账号后端可用",
                    detail: "工作台已找到内置自包含账号后端。"
                )
                : DiagnosticFinding(
                    id: "account-backend-missing",
                    level: .error,
                    title: "账号后端缺失",
                    detail: "请重新安装完整的工作台 App。"
                )
        )

        findings.append(
            input.defaultHomeAvailable
                ? DiagnosticFinding(
                    id: "default-home-readable",
                    level: .info,
                    title: "默认 Codex home 可用",
                    detail: "已确认默认账号入口可读；诊断不会读取或展示认证正文。"
                )
                : DiagnosticFinding(
                    id: "default-home-unavailable",
                    level: .warning,
                    title: "默认 Codex home 不可用",
                    detail: "未找到可读的默认账号入口；既有 Profiles 仍可独立工作。"
                )
        )

        switch input.accountMode {
        case .localDefault:
            findings.append(
                DiagnosticFinding(
                    id: "account-local-default",
                    level: .info,
                    title: "正在识别本机当前账号",
                    detail: "账号来源为默认 Codex home；工作台不会创建 Profile 或认证桥接。"
                )
            )
        case .managedProfiles:
            findings.append(
                DiagnosticFinding(
                    id: "account-managed-profiles",
                    level: .info,
                    title: "正在使用已有 Profiles",
                    detail: "已识别 \(input.managedProfileCount) 个既有 Profile。"
                )
            )
        case .unavailable:
            findings.append(
                DiagnosticFinding(
                    id: "account-unavailable",
                    level: .error,
                    title: "未找到可识别账号",
                    detail: "默认 Codex home 与既有 Profiles 当前均不可用。"
                )
            )
        }

        if let stage = safeFailureStage(input.recentFailureStage) {
            findings.append(
                DiagnosticFinding(
                    id: "recent-account-failure",
                    level: .warning,
                    title: "最近账号操作未完成",
                    detail: failureStageDescription(stage)
                )
            )
        }

        let appSummaries = apps.map { appSummary($0, selectedURL: input.selectedAppURL) }
        let revealTargets = apps.map {
            DiagnosticRevealTarget(
                label: redacted("在 Finder 中显示 \($0.displayName)"),
                url: $0.url
            )
        }
        let findingLines = findings.map {
            "[\($0.level.rawValue.uppercased())] \($0.title)：\($0.detail)"
        }
        let copyableSummary = (["Codex 工作台脱敏诊断"] + appSummaries + findingLines)
            .map(redacted)
            .joined(separator: "\n")

        return WorkbenchDiagnosticSnapshot(
            findings: findings,
            appSummaries: appSummaries,
            revealTargets: revealTargets,
            copyableSummary: copyableSummary
        )
    }

    private static func uniqueApps(
        _ apps: [DiagnosticAppInstallation]
    ) -> [DiagnosticAppInstallation] {
        var seen: Set<String> = []
        return apps
            .filter { $0.bundleIdentifier == CodexIntegration.bundleIdentifier }
            .filter { seen.insert($0.url.path).inserted }
            .sorted { $0.url.path < $1.url.path }
    }

    private static func selectedAppName(
        apps: [DiagnosticAppInstallation],
        selectedURL: URL?
    ) -> String? {
        guard let selectedPath = selectedURL?.standardizedFileURL.path else { return nil }
        return apps.first { $0.url.path == selectedPath }.map { redacted($0.displayName) }
    }

    private static func appSummary(
        _ app: DiagnosticAppInstallation,
        selectedURL: URL?
    ) -> String {
        let selected = selectedURL?.standardizedFileURL.path == app.url.path ? " · 系统选择" : ""
        let running = app.isRunning ? " · 运行中" : ""
        let version = app.version.map { " · 版本 \(redacted($0))" } ?? ""
        return "应用：\(redacted(app.displayName)) · bundle \(redacted(app.bundleIdentifier)) · \(app.location.rawValue) · #\(app.redactedFingerprint)\(version)\(running)\(selected)"
    }

    private static func safeFailureStage(_ value: String?) -> String? {
        switch value {
        case "restart_command_failed", "verification_unavailable", "verification_mismatch",
             "switch_command_failed", "unmanaged_login":
            value
        default:
            nil
        }
    }

    private static func failureStageDescription(_ stage: String) -> String {
        switch stage {
        case "restart_command_failed": "安全重启命令失败，可刷新后重试。"
        case "verification_unavailable": "操作后无法读取账号状态，可刷新诊断。"
        case "verification_mismatch": "操作后的实际账号与预期不一致。"
        case "switch_command_failed": "账号切换命令失败，可在任务空闲后重试。"
        case "unmanaged_login": "当前登录未处于既有 Profile 接管状态。"
        default: "账号操作未通过验证。"
        }
    }

    private static func redacted(_ value: String) -> String {
        value
            .replacingOccurrences(of: "auth.json", with: "[redacted]", options: .caseInsensitive)
            .replacingOccurrences(of: "token", with: "[redacted]", options: .caseInsensitive)
    }
}

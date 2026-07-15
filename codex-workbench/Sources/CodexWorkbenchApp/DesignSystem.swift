import AppKit
import CodexWorkbenchCore
import SwiftUI

enum WorkbenchSpacing {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
}

enum WorkbenchRadius {
    static let chip: CGFloat = 7
    static let card: CGFloat = 12
}

extension Color {
    static let workbenchWindow = Color(nsColor: .windowBackgroundColor)
    static let workbenchCard = Color(nsColor: .controlBackgroundColor)
    static let workbenchBorder = Color(nsColor: .separatorColor)
    static let workbenchSelection = Color.accentColor.opacity(0.11)
}

struct SurfaceCard<Content: View>: View {
    private let content: Content
    private let padding: CGFloat
    private let selected: Bool

    init(padding: CGFloat = WorkbenchSpacing.md, selected: Bool = false, @ViewBuilder content: () -> Content) {
        self.content = content()
        self.padding = padding
        self.selected = selected
    }

    var body: some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: WorkbenchRadius.card, style: .continuous)
                    .fill(selected ? Color.workbenchSelection : Color.workbenchCard)
            )
            .overlay(
                RoundedRectangle(cornerRadius: WorkbenchRadius.card, style: .continuous)
                    .stroke(
                        selected ? Color.accentColor.opacity(0.38) : Color.workbenchBorder.opacity(0.65),
                        lineWidth: selected ? 1 : 0.5
                    )
            )
    }
}

struct PageHeader: View {
    let eyebrow: String?
    let title: String
    let description: String
    let trailing: AnyView?

    init(
        eyebrow: String? = nil,
        title: String,
        description: String,
        trailing: AnyView? = nil
    ) {
        self.eyebrow = eyebrow
        self.title = title
        self.description = description
        self.trailing = trailing
    }

    var body: some View {
        HStack(alignment: .top, spacing: WorkbenchSpacing.lg) {
            VStack(alignment: .leading, spacing: WorkbenchSpacing.xs) {
                if let eyebrow {
                    Text(eyebrow.uppercased())
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(0.7)
                        .foregroundStyle(.tertiary)
                }
                Text(title)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.primary)
                Text(description)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: WorkbenchSpacing.md)
            if let trailing {
                trailing
            }
        }
    }
}

struct SectionTitle: View {
    let title: String
    let detail: String?

    init(_ title: String, detail: String? = nil) {
        self.title = title
        self.detail = detail
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
            Spacer()
            if let detail {
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

struct StatusChip: View {
    let text: String
    let color: Color
    let systemImage: String?

    init(_ text: String, color: Color = .secondary, systemImage: String? = nil) {
        self.text = text
        self.color = color
        self.systemImage = systemImage
    }

    var body: some View {
        HStack(spacing: WorkbenchSpacing.xxs) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 9, weight: .semibold))
            } else {
                Circle()
                    .fill(color)
                    .frame(width: 6, height: 6)
            }
            Text(text)
                .lineLimit(1)
        }
        .font(.system(size: 10, weight: .medium))
        .foregroundStyle(color)
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: WorkbenchRadius.chip, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: WorkbenchRadius.chip, style: .continuous)
                .stroke(color.opacity(0.18), lineWidth: 0.5)
        )
    }
}

struct QuietEmptyState: View {
    let systemImage: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: WorkbenchSpacing.sm) {
            Image(systemName: systemImage)
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(.tertiary)
            Text(title)
                .font(.system(size: 14, weight: .semibold))
            Text(message)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
        }
        .padding(WorkbenchSpacing.xl)
        .accessibilityElement(children: .combine)
    }
}

extension EventCategory {
    var displayName: String {
        switch self {
        case .account: "账号"
        case .automation: "自动化"
        case .context: "上下文"
        case .hook: "Hook"
        case .plugin: "Plugin"
        case .quota: "额度"
        case .skill: "Skill"
        case .system: "系统"
        case .thread: "任务"
        case .unknown: "其他"
        }
    }

    var systemImage: String {
        switch self {
        case .account: "person.crop.circle"
        case .automation: "calendar.badge.clock"
        case .context: "arrow.triangle.2.circlepath"
        case .hook: "point.3.connected.trianglepath.dotted"
        case .plugin: "puzzlepiece.extension"
        case .quota: "gauge.with.dots.needle.33percent"
        case .skill: "wand.and.stars"
        case .system: "gearshape"
        case .thread: "bubble.left.and.bubble.right"
        case .unknown: "circle.dotted"
        }
    }

    var color: Color {
        switch self {
        case .quota: .orange
        case .context: .indigo
        case .thread: .blue
        case .account: .teal
        case .automation, .hook, .plugin, .skill: .purple
        case .system, .unknown: .secondary
        }
    }
}

extension EventStatus {
    var displayName: String {
        switch self {
        case .success: "成功"
        case .failure: "失败"
        case .inProgress: "进行中"
        case .skipped: "已跳过"
        case .unknown: "未知"
        }
    }

    var color: Color {
        switch self {
        case .success: .green
        case .failure: .red
        case .inProgress: .blue
        case .skipped, .unknown: .secondary
        }
    }
}

extension EventCertainty {
    var displayName: String {
        switch self {
        case .confirmed: "已核实"
        case .inferred: "根据证据推断"
        case .unverified: "尚无足够证据"
        }
    }

    var explanation: String {
        switch self {
        case .confirmed: "来自明确的系统记录或结构化关系。"
        case .inferred: "由前后状态和时间窗口推断，官方未提供事件原因。"
        case .unverified: "已观察到线索，但当前证据不足以确认原因。"
        }
    }

    var color: Color {
        switch self {
        case .confirmed: .secondary
        case .inferred: .orange
        case .unverified: .red
        }
    }
}

extension EventImportance {
    var displayName: String {
        switch self {
        case .critical: "关键变更"
        case .important: "重要"
        case .routine: "常规"
        case .diagnostic: "诊断"
        }
    }

    var color: Color {
        switch self {
        case .critical: .orange
        case .important: .indigo
        case .routine: .secondary
        case .diagnostic: .secondary
        }
    }

    var markerSize: CGFloat {
        switch self {
        case .critical: 24
        case .important: 22
        case .routine: 18
        case .diagnostic: 16
        }
    }

    var titleWeight: Font.Weight {
        switch self {
        case .critical: .bold
        case .important: .semibold
        case .routine: .medium
        case .diagnostic: .regular
        }
    }
}

extension EventThreadRelation {
    var displayName: String {
        switch self {
        case .activeAtTime: "发生时所在对话"
        case .source: "来源对话"
        case .target: "接续后的对话"
        case .triggeredBy: "由该对话触发"
        case .unrelated: "无直接关系"
        case .unknown: "关系未知"
        }
    }
}

extension EventActorType {
    var displayName: String {
        switch self {
        case .agent: "Agent"
        case .app: "App"
        case .automation: "Automation"
        case .hook: "Hook"
        case .plugin: "Plugin"
        case .skill: "Skill"
        case .system: "System"
        case .user: "用户"
        case .unknown: "其他"
        }
    }
}

extension AccountRoleConfidence {
    var displayName: String {
        switch self {
        case .confirmed: "确定"
        case .inferred: "推断"
        case .unknown: "未知"
        }
    }

    var color: Color {
        switch self {
        case .confirmed: .green
        case .inferred: .orange
        case .unknown: .secondary
        }
    }
}

extension JSONValue {
    var displayText: String {
        switch self {
        case .array(let values): values.map(\.displayText).joined(separator: ", ")
        case .bool(let value): value ? "true" : "false"
        case .null: "—"
        case .number(let value):
            value.rounded() == value ? String(Int(value)) : String(format: "%.2f", value)
        case .object(let values):
            values.keys.sorted().map { "\($0): \(values[$0]?.displayText ?? "—")" }.joined(separator: "\n")
        case .string(let value): value
        }
    }
}

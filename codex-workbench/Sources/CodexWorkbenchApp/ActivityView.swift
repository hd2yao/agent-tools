import CodexWorkbenchCore
import SwiftUI

struct ActivityView: View {
    @ObservedObject var model: WorkbenchAppModel

    var body: some View {
        activityContent
    }

    private var activityContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: WorkbenchSpacing.md) {
                PageHeader(
                    eyebrow: "Activity",
                    title: "操作日志",
                    description: "最新操作在上。查看触发来源、任务关系、置信度与脱敏证据。"
                )
                ActivityFilterBar(model: model)
            }
            .padding(.horizontal, WorkbenchSpacing.lg)
            .padding(.top, WorkbenchSpacing.lg)
            .padding(.bottom, WorkbenchSpacing.md)

            GeometryReader { proxy in
                if proxy.size.width >= 1_040 {
                    HStack(spacing: 0) {
                        ActivityList(model: model, expandsSelection: false)
                            .frame(minWidth: 610, maxWidth: .infinity)
                        Divider()
                        Group {
                            if let event = model.selectedEvent {
                                ActivityInspector(event: event)
                            } else {
                                QuietEmptyState(
                                    systemImage: "sidebar.right",
                                    title: "选择一条操作",
                                    message: "这里会显示任务关系、来源链、前后状态和证据。"
                                )
                            }
                        }
                        .frame(width: 350)
                        .background(Color.workbenchCard.opacity(0.45))
                    }
                } else {
                    ActivityList(model: model, expandsSelection: true)
                }
            }
        }
        .background(Color.workbenchWindow)
        .accessibilityIdentifier("activity-page")
    }
}

private struct ActivityFilterBar: View {
    @ObservedObject var model: WorkbenchAppModel

    var body: some View {
        HStack(spacing: WorkbenchSpacing.xs) {
            HStack(spacing: WorkbenchSpacing.xs) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.tertiary)
                TextField("搜索动作、任务、来源或账号", text: $model.searchText)
                    .textFieldStyle(.plain)
            }
            .padding(.horizontal, 10)
            .frame(minWidth: 260, maxWidth: 460, minHeight: 30)
            .background(Color.workbenchCard, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.workbenchBorder.opacity(0.65), lineWidth: 0.5)
            )

            Picker("级别", selection: $model.importanceFilter) {
                Text("全部级别").tag(Optional<EventImportance>.none)
                Text("关键").tag(Optional(EventImportance.critical))
                Text("重要").tag(Optional(EventImportance.important))
                Text("诊断").tag(Optional(EventImportance.diagnostic))
            }
            .labelsHidden()
            .frame(width: 105)

            Picker("来源", selection: $model.actorFilter) {
                Text("全部来源").tag(Optional<EventActorType>.none)
                ForEach(EventActorType.allCases.filter { $0 != .unknown }, id: \.self) { type in
                    Text(type.displayName).tag(Optional(type))
                }
            }
            .labelsHidden()
            .frame(width: 115)

            Picker("状态", selection: $model.statusFilter) {
                Text("全部状态").tag(Optional<EventStatus>.none)
                ForEach(EventStatus.allCases.filter { $0 != .unknown }, id: \.self) { status in
                    Text(status.displayName).tag(Optional(status))
                }
            }
            .labelsHidden()
            .frame(width: 105)

            Spacer(minLength: 0)

            Text("\(model.filteredEvents.count) 条")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(.tertiary)
        }
    }
}

private struct ActivityList: View {
    @ObservedObject var model: WorkbenchAppModel
    let expandsSelection: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var sections: [ActivityDaySection] {
        ActivityGrouper.sections(for: model.filteredEvents)
    }

    var body: some View {
        Group {
            if model.filteredEvents.isEmpty {
                QuietEmptyState(
                    systemImage: model.events.isEmpty ? "clock.badge.questionmark" : "line.3.horizontal.decrease.circle",
                    title: model.events.isEmpty ? "还没有操作事件" : "没有匹配结果",
                    message: model.events.isEmpty
                        ? "刷新后会从本地证据补录可确认的操作。"
                        : "尝试清除搜索或放宽筛选条件。"
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                        ForEach(sections) { section in
                            Section {
                                ForEach(section.events) { event in
                                    ActivityTimelineRow(
                                        event: event,
                                        isSelected: model.selectedEventID == event.id,
                                        showsInlineDetails: expandsSelection && model.selectedEventID == event.id
                                    ) {
                                        if reduceMotion {
                                            model.selectEvent(event)
                                        } else {
                                            withAnimation(.easeOut(duration: 0.14)) {
                                                model.selectEvent(event)
                                            }
                                        }
                                    }
                                }
                            } header: {
                                ActivityDateHeader(day: section.day, count: section.events.count)
                            }
                        }
                    }
                    .padding(.horizontal, WorkbenchSpacing.lg)
                    .padding(.bottom, WorkbenchSpacing.lg)
                }
            }
        }
    }
}

private struct ActivityDateHeader: View {
    let day: Date
    let count: Int

    var body: some View {
        HStack {
            Text(dayTitle)
                .font(.system(size: 11, weight: .semibold))
            Text("\(count)")
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .padding(.top, WorkbenchSpacing.sm)
        .padding(.bottom, WorkbenchSpacing.xs)
        .background(Color.workbenchWindow.opacity(0.96))
    }

    private var dayTitle: String {
        if Calendar.current.isDateInToday(day) { return "今天" }
        if Calendar.current.isDateInYesterday(day) { return "昨天" }
        return day.formatted(.dateTime.year().month().day().locale(Locale(identifier: "zh_CN")))
    }
}

private struct ActivityTimelineRow: View {
    let event: OperationEvent
    let isSelected: Bool
    let showsInlineDetails: Bool
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        VStack(spacing: 0) {
            Button(action: action) {
                HStack(alignment: .top, spacing: WorkbenchSpacing.sm) {
                    Text(event.occurredAt.formatted(date: .omitted, time: .shortened))
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(width: 46, alignment: .trailing)
                        .padding(.top, 2)

                    VStack(spacing: 0) {
                        ZStack {
                            Circle()
                                .fill(event.category.color.opacity(0.14))
                                .frame(width: 20, height: 20)
                            Image(systemName: event.category.systemImage)
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(event.category.color)
                        }
                        Rectangle()
                            .fill(Color.workbenchBorder.opacity(0.5))
                            .frame(width: 1, height: 42)
                    }
                    .frame(width: 20)

                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: WorkbenchSpacing.xs) {
                            Text(event.title)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                            Spacer(minLength: WorkbenchSpacing.sm)
                            StatusChip(event.status.displayName, color: event.status.color)
                        }
                        Text(event.summary)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                        HStack(spacing: 6) {
                            Label(event.actor.label, systemImage: "bolt.horizontal.circle")
                            Text("·")
                            Text(event.certainty.displayName)
                                .foregroundStyle(event.certainty.color)
                            if let threadTitle = event.thread?.title, !threadTitle.isEmpty {
                                Text("·")
                                Text(threadTitle).lineLimit(1)
                            } else if event.thread?.id != nil {
                                Text("· 已关联任务")
                            }
                            if let profile = event.account?.profile {
                                Text("·")
                                Text(profile).lineLimit(1)
                            }
                        }
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, WorkbenchSpacing.sm)
                .padding(.top, 11)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if showsInlineDetails {
                Divider().padding(.leading, 78)
                ActivityInspector(event: event, inline: true)
                    .padding(.leading, 78)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(isSelected ? Color.workbenchSelection : (isHovering ? Color.primary.opacity(0.035) : .clear))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(isSelected ? Color.accentColor.opacity(0.28) : .clear, lineWidth: 0.5)
        )
        .onHover { isHovering = $0 }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(event.title)，\(event.status.displayName)，来源 \(event.actor.label)，\(event.certainty.displayName)")
    }
}

struct ActivityInspector: View {
    let event: OperationEvent
    var inline = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: WorkbenchSpacing.lg) {
                VStack(alignment: .leading, spacing: WorkbenchSpacing.xs) {
                    HStack {
                        Image(systemName: event.category.systemImage)
                            .foregroundStyle(event.category.color)
                        Text(event.category.displayName)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(event.category.color)
                        Spacer()
                        StatusChip(event.certainty.displayName, color: event.certainty.color)
                    }
                    Text(event.title)
                        .font(.system(size: inline ? 15 : 17, weight: .semibold))
                    Text(event.summary)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(event.occurredAt.formatted(date: .abbreviated, time: .standard))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }

                InspectorSection(title: "来源") {
                    InspectorValue(label: "主体", value: "\(event.actor.type.displayName) · \(event.actor.label)")
                    ForEach(Array(event.sourceChain.enumerated()), id: \.offset) { index, actor in
                        InspectorValue(label: index == 0 ? "来源链" : "", value: "\(index + 1). \(actor.label)")
                    }
                }

                if event.thread != nil || event.project != nil || event.account != nil {
                    InspectorSection(title: "定位") {
                        if let thread = event.thread {
                            InspectorValue(
                                label: "任务",
                                value: thread.title ?? thread.id ?? "未命名任务"
                            )
                            InspectorValue(label: "关系", value: thread.relation.rawValue)
                            if let threadID = thread.id,
                               CodexIntegration.threadURL(for: threadID) != nil {
                                Button {
                                    CodexIntegrationService.openThread(threadID)
                                } label: {
                                    Label("在 Codex 中打开任务", systemImage: "arrow.up.forward.app")
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }
                        if let project = event.project {
                            InspectorValue(label: "项目", value: project.name ?? project.path ?? "—")
                        }
                        if let account = event.account {
                            InspectorValue(label: "账号", value: account.profile ?? account.label ?? "—")
                        }
                    }
                }

                if event.before != nil || event.after != nil {
                    InspectorSection(title: "状态变化") {
                        if let before = event.before {
                            InspectorValue(label: "之前", value: before.displayText)
                        }
                        if let after = event.after {
                            InspectorValue(label: "之后", value: after.displayText)
                        }
                    }
                }

                if !event.evidence.isEmpty {
                    InspectorSection(title: "证据") {
                        ForEach(Array(event.evidence.enumerated()), id: \.offset) { _, evidence in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(evidence.label)
                                    .font(.system(size: 10, weight: .medium))
                                if let path = evidence.path {
                                    Text(path)
                                        .font(.system(size: 9, design: .monospaced))
                                        .foregroundStyle(.tertiary)
                                        .lineLimit(2)
                                        .truncationMode(.middle)
                                }
                            }
                        }
                    }
                }
            }
            .padding(inline ? WorkbenchSpacing.md : WorkbenchSpacing.lg)
        }
    }
}

private struct InspectorSection<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: WorkbenchSpacing.xs) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct InspectorValue: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: WorkbenchSpacing.xs) {
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .frame(width: 44, alignment: .leading)
            Text(value)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

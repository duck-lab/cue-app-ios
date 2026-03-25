import SwiftData
import SwiftUI

#if os(iOS)
import UIKit
#endif

private enum NotificationSortOption: String, CaseIterable, Identifiable {
    case newest
    case oldest
    case priorityHighFirst
    case deadlineSoon
    case source

    var id: String { rawValue }

    var title: String {
        switch self {
        case .newest:
            "最新"
        case .oldest:
            "最早"
        case .priorityHighFirst:
            "优先级高到低"
        case .deadlineSoon:
            "截止时间先"
        case .source:
            "来源 A-Z"
        }
    }
}

private struct StatusActionIntent: Identifiable {
    let id = UUID()
    let itemID: String
    let targetStatus: NotificationStatus
}

private struct SubmissionState {
    var isSubmitting = false
    var pendingStatus: NotificationStatus?
    var errorMessage: String?
    var lastComment: String?
}

private struct StatusBadgeView: View {
    let status: NotificationStatus

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: status.iconName)
            Text(status.displayTitle)
        }
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(status.badgeColor.opacity(0.15), in: Capsule())
        .foregroundStyle(status.badgeColor)
    }
}

private struct PriorityTagView: View {
    let priority: NotificationPriority

    var body: some View {
        Text(priority.displayTitle)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(priority.displayColor.opacity(0.15), in: Capsule())
            .foregroundStyle(priority.displayColor)
    }
}

private struct NotificationRowView: View {
    let item: NotificationItem
    let state: SubmissionState
    let onRequestStatus: (NotificationStatus) -> Void
    let onRetry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(alignment: .center, spacing: 8) {
                        Text(item.title)
                            .font(.headline)
                            .lineLimit(2)

                        if item.unread {
                            Circle()
                                .fill(.blue)
                                .frame(width: 8, height: 8)
                                .accessibilityLabel("未读")
                        }
                    }

                    Text(item.source)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text("时间：\(item.timestamp.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let deadline = item.deadline {
                        Text("截止：\(deadline.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption)
                            .foregroundStyle(item.isOverdue ? .red : .secondary)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 8) {
                    StatusBadgeView(status: item.status)
                    Text("更新：\(item.updatedAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Text(item.extraInfo)
                .font(.footnote)
                .foregroundStyle(.secondary)

            HStack {
                PriorityTagView(priority: item.priority)

                if state.isSubmitting {
                    ProgressView()
                        .controlSize(.small)
                }

                Spacer()

                if let errorMessage = state.errorMessage {
                    VStack(alignment: .trailing, spacing: 6) {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)

                        Button("重试") {
                            onRetry()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                }
            }
        }
        .padding(.vertical, 10)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            ForEach(item.status.transitionOptions, id: \.self) { status in
                Button {
                    onRequestStatus(status)
                } label: {
                    Label(status.displayTitle, systemImage: status.iconName)
                }
                .tint(status.badgeColor)
            }
        }
        .contextMenu {
            ForEach(item.status.transitionOptions, id: \.self) { status in
                Button(status.displayTitle) {
                    onRequestStatus(status)
                }
            }
        }
    }
}

private struct StatusCommentSheet: View {
    let title: String
    let targetStatus: NotificationStatus
    let initialDraft: String?
    let onSubmit: (String) -> Void
    let onCancel: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var comment = ""

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("对 \"\(title)\" 执行 \(targetStatus.displayTitle)。")
                    .font(.headline)

                Text("可选备注，留空直接提交")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                TextEditor(text: $comment)
                    .frame(height: 130)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.secondary.opacity(0.35), lineWidth: 1)
                    )

                Text("当前字数：\(comment.count)")
                    .font(.caption)
                    .foregroundStyle(comment.count > 200 ? .red : .secondary)

                Spacer()

                HStack {
                    Button("取消") {
                        onCancel()
                        dismiss()
                    }
                    .buttonStyle(.bordered)

                    Spacer()

                    Button("提交") {
                        onSubmit(comment)
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(comment.count > 200)
                }
            }
            .padding()
        }
        .navigationTitle("状态更新")
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
        .onAppear {
            comment = initialDraft ?? ""
        }
    }
}

private struct FilterPill: View {
    let title: String
    let isActive: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(title)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(isActive ? Color.accentColor : Color.gray.opacity(0.2))
                )
                .foregroundStyle(isActive ? Color.white : Color.primary)
        }
        .buttonStyle(.plain)
    }
}

private extension NotificationStatus {
    var displayTitle: String {
        switch self {
        case .pending:
            "待处理"
        case .inProgress:
            "进行中"
        case .completed:
            "完成"
        case .ignored:
            "忽略"
        }
    }

    var iconName: String {
        switch self {
        case .pending:
            "clock"
        case .inProgress:
            "gearshape"
        case .completed:
            "checkmark.circle.fill"
        case .ignored:
            "slash.circle"
        }
    }

    var badgeColor: Color {
        switch self {
        case .pending:
            .orange
        case .inProgress:
            .blue
        case .completed:
            .green
        case .ignored:
            .secondary
        }
    }

    var transitionOptions: [NotificationStatus] {
        switch self {
        case .pending:
            [.inProgress, .completed, .ignored]
        case .inProgress:
            [.completed, .ignored]
        case .completed, .ignored:
            []
        }
    }
}

private extension NotificationPriority {
    var displayTitle: String {
        switch self {
        case .low:
            "低"
        case .normal:
            "普通"
        case .high:
            "高"
        case .urgent:
            "紧急"
        }
    }

    var displayColor: Color {
        switch self {
        case .low:
            .blue
        case .normal:
            .green
        case .high:
            .orange
        case .urgent:
            .red
        }
    }
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var runtime: AppRuntime
    @Query private var persistedItems: [NotificationItem]

    @State private var statusFilter: NotificationStatus?
    @State private var priorityFilter: NotificationPriority?
    @State private var sourceFilter: String?
    @State private var sortOption: NotificationSortOption = .newest

    @State private var submissionStates: [String: SubmissionState] = [:]
    @State private var activeAction: StatusActionIntent?
    @State private var isLoading = true
    @State private var isRefreshing = false
    @State private var loadError: String?

    private var visibleItems: [NotificationItem] {
        var result = persistedItems

        if let statusFilter {
            result = result.filter { $0.status == statusFilter }
        }

        if let priorityFilter {
            result = result.filter { $0.priority == priorityFilter }
        }

        if let sourceFilter {
            result = result.filter { $0.source == sourceFilter }
        }

        switch sortOption {
        case .newest:
            return result.sorted { $0.updatedAt > $1.updatedAt }
        case .oldest:
            return result.sorted { $0.updatedAt < $1.updatedAt }
        case .priorityHighFirst:
            return result.sorted {
                if $0.priority == $1.priority {
                    return $0.updatedAt > $1.updatedAt
                }

                return $0.priority.rawValue > $1.priority.rawValue
            }
        case .deadlineSoon:
            return result.sorted {
                switch ($0.deadline, $1.deadline) {
                case let (lhs?, rhs?):
                    return lhs < rhs
                case (_?, nil):
                    return true
                case (nil, _?):
                    return false
                default:
                    return $0.updatedAt > $1.updatedAt
                }
            }
        case .source:
            return result.sorted { $0.source < $1.source }
        }
    }

    private var sources: [String] {
        Array(Set(persistedItems.map { $0.source }).sorted())
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                filterBar

                Divider()

                ZStack {
                    if isLoading && persistedItems.isEmpty {
                        ProgressView("加载通知列表")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if let loadError, visibleItems.isEmpty {
                        VStack(spacing: 12) {
                            Text(loadError)
                                .foregroundStyle(.red)

                            Button("重试") {
                                Task {
                                    await refresh()
                                }
                            }
                            .buttonStyle(.bordered)
                        }
                    } else if visibleItems.isEmpty {
                        VStack(spacing: 12) {
                            Text("暂无通知")
                                .font(.headline)
                            Text("调整筛选条件或下拉刷新试试")
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        List {
                            ForEach(visibleItems) { item in
                                NotificationRowView(
                                    item: item,
                                    state: submissionStates[item.id] ?? SubmissionState(),
                                    onRequestStatus: { status in
                                        activeAction = StatusActionIntent(
                                            itemID: item.id,
                                            targetStatus: status
                                        )
                                    },
                                    onRetry: {
                                        guard let state = submissionStates[item.id],
                                              let target = state.pendingStatus else {
                                            return
                                        }

                                        Task {
                                            let result = await runtime.retryPendingSubmission(itemID: item.id)

                                            if case let .failure(error) = result {
                                                let fallback = runtime.pendingSubmission(for: item.id)?.lastErrorMessage
                                                updateSubmissionState(for: item.id) {
                                                    $0.isSubmitting = false
                                                    $0.pendingStatus = target
                                                    $0.errorMessage = fallback ?? error.localizedDescription
                                                }
                                            } else {
                                                updateSubmissionState(for: item.id) {
                                                    $0.isSubmitting = false
                                                    $0.pendingStatus = nil
                                                    $0.errorMessage = nil
                                                }
                                            }
                                        }
                                    }
                                )
                            }
                        }
                        .listStyle(.plain)
                        .refreshable {
                            await refresh()
                        }
                    }

                    if isRefreshing {
                        VStack {
                            Spacer()

                            ProgressView()
                                .padding(6)
                                .background(.thinMaterial, in: Circle())
                                .padding(.bottom, 24)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle("通知列表")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
#if os(iOS)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("重置筛选") {
                            withAnimation {
                                statusFilter = nil
                                priorityFilter = nil
                                sourceFilter = nil
                            }
                        }
                    } label: {
                        Label("筛选", systemImage: "line.3.horizontal.decrease.circle")
                    }
                }
            }
#endif
            .task {
                if isLoading {
                    await refresh()
                }
            }
            .sheet(item: $activeAction) { intent in
                if let item = persistedItems.first(where: { $0.id == intent.itemID }) {
                    StatusCommentSheet(
                        title: item.title,
                        targetStatus: intent.targetStatus,
                        initialDraft: item.replyDraft,
                        onSubmit: { comment in
                            Task {
                                await submitStatus(
                                    for: intent.itemID,
                                    status: intent.targetStatus,
                                    comment: comment
                                )
                            }
                        },
                        onCancel: {
                            activeAction = nil
                        }
                    )
                }
            }
        }
    }

    private var filterBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    FilterPill(
                        title: "状态：\(statusFilter?.displayTitle ?? "全部")",
                        isActive: statusFilter == nil
                    ) {
                        withAnimation {
                            statusFilter = nil
                        }
                    }

                    ForEach(NotificationStatus.allCases, id: \.self) { status in
                        FilterPill(
                            title: status.displayTitle,
                            isActive: statusFilter == status
                        ) {
                            withAnimation {
                                statusFilter = statusFilter == status ? nil : status
                            }
                        }
                    }
                }
            }

            HStack {
                Menu("优先级：\(priorityFilter?.displayTitle ?? "全部")") {
                    Button("全部") {
                        priorityFilter = nil
                    }

                    ForEach(NotificationPriority.allCases, id: \.self) { priority in
                        Button(priority.displayTitle) {
                            withAnimation {
                                priorityFilter = priorityFilter == priority ? nil : priority
                            }
                        }
                    }
                }

                Menu("来源：\(sourceFilter ?? "全部")") {
                    Button("全部") {
                        sourceFilter = nil
                    }

                    ForEach(sources, id: \.self) { source in
                        Button(source) {
                            withAnimation {
                                sourceFilter = sourceFilter == source ? nil : source
                            }
                        }
                    }
                }

                Menu("排序：\(sortOption.title)") {
                    ForEach(NotificationSortOption.allCases, id: \.self) { option in
                        Button(option.title) {
                            withAnimation {
                                sortOption = option
                            }
                        }
                    }
                }

                Spacer()
            }
            .font(.subheadline)
        }
        .padding([.horizontal, .top])
        .padding(.bottom, 8)
    }

    private func refresh() async {
        isRefreshing = true
        loadError = nil

        let result = await runtime.refreshNotificationStore()
        if case let .failure(error) = result {
            loadError = "刷新失败：\(error.localizedDescription)"
        }

        syncSubmissionStateWithRuntimeQueue()

        isLoading = false
        isRefreshing = false
    }

    private func submitStatus(
        for itemID: String,
        status: NotificationStatus,
        comment: String
    ) async {
        guard let item = persistedItems.first(where: { $0.id == itemID }) else {
            return
        }

        let normalizedComment = comment.trimmingCharacters(in: .whitespacesAndNewlines)
        let commentValue = normalizedComment.isEmpty ? nil : normalizedComment
        let previousStatus = item.status

        updateSubmissionState(for: itemID) {
            $0.isSubmitting = true
            $0.pendingStatus = status
            $0.errorMessage = nil
            $0.lastComment = normalizedComment
        }

        do {
            try item.updateStatus(to: status)
            item.unread = false
            item.replyDraft = commentValue
            item.markAsRead()

            try modelContext.save()

            let submitResult = await runtime.submitStatus(
                itemID: item.id,
                status: status,
                comment: commentValue
            )

            switch submitResult {
            case .success:
                updateSubmissionState(for: itemID) {
                    $0.isSubmitting = false
                    $0.pendingStatus = nil
                    $0.errorMessage = nil
                    $0.lastComment = normalizedComment
                }

                item.clearReplyDraftAfterSubmit()
                try modelContext.save()
            case let .failure(error):
                let hasPending = runtime.pendingSubmission(for: item.id) != nil
                updateSubmissionState(for: itemID) {
                    $0.isSubmitting = false
                    $0.pendingStatus = hasPending ? status : nil
                    $0.errorMessage = error.localizedDescription
                }

                if hasPending {
                    item.markAsRead()
                } else {
                    item.status = previousStatus
                    item.markAsRead(false)
                }

                try? modelContext.save()
            }
        } catch {
            updateSubmissionState(for: itemID) {
                $0.isSubmitting = false
                $0.errorMessage = error.localizedDescription
            }

            item.status = previousStatus
            try? modelContext.save()
        }
    }

    private func updateSubmissionState(
        for itemID: String,
        _ mutator: (inout SubmissionState) -> Void
    ) {
        var state = submissionStates[itemID] ?? SubmissionState()
        mutator(&state)
        submissionStates[itemID] = state
    }

    private func syncSubmissionStateWithRuntimeQueue() {
        var nextStates = submissionStates

        for item in persistedItems {
            let pending = runtime.pendingSubmission(for: item.id)
            if let pending {
                nextStates[item.id] = SubmissionState(
                    isSubmitting: false,
                    pendingStatus: pending.targetStatus,
                    errorMessage: pending.lastErrorMessage,
                    lastComment: pending.comment
                )
            } else if var state = nextStates[item.id], state.pendingStatus != nil {
                state.pendingStatus = nil
                state.errorMessage = nil
                nextStates[item.id] = state
            }
        }

        submissionStates = nextStates
    }
}

import Foundation
import SwiftData

public enum NotificationPriority: String, Codable, CaseIterable, Sendable {
    case low = "low"
    case normal = "normal"
    case high = "high"
    case urgent = "urgent"
}

public enum NotificationStatus: String, Codable, CaseIterable, Sendable {
    case pending = "pending"
    case inProgress = "inProgress"
    case completed = "completed"
    case ignored = "ignored"

    public var isTerminal: Bool {
        self == .completed || self == .ignored
    }

    public var statusText: String {
        switch self {
        case .pending:
            "Pending"
        case .inProgress:
            "In Progress"
        case .completed:
            "Completed"
        case .ignored:
            "Ignored"
        }
    }
}

public struct ClientMeta: Codable, Equatable, Sendable {
    public let platform: String
    public let version: String
    public let device: String

    public init(platform: String, version: String, device: String) {
        self.platform = platform
        self.version = version
        self.device = device
    }
}

public struct StatusFeedback: Codable, Equatable, Sendable {
    public let notificationId: String
    public let status: NotificationStatus
    public let comment: String?
    public let timestamp: Date
    public let clientMeta: ClientMeta

    public init(
        notificationId: String,
        status: NotificationStatus,
        comment: String? = nil,
        timestamp: Date = Date(),
        clientMeta: ClientMeta
    ) {
        self.notificationId = notificationId
        self.status = status
        self.comment = comment
        self.timestamp = timestamp
        self.clientMeta = clientMeta
    }
}

@Model
public final class NotificationItem {
    @Attribute(.unique) public var id: String
    public var title: String
    public var source: String
    public var priority: NotificationPriority
    public var timestamp: Date
    public var deadline: Date?
    public var extraInfo: String
    public var status: NotificationStatus
    public var unread: Bool
    public var replyDraft: String?
    public var updatedAt: Date

    public var isOverdue: Bool {
        guard let deadline else {
            return false
        }

        return deadline < Date() && !status.isTerminal
    }

    public var statusText: String {
        status.statusText
    }

    public init(
        id: String = UUID().uuidString,
        title: String,
        source: String,
        priority: NotificationPriority = .normal,
        timestamp: Date = Date(),
        deadline: Date? = nil,
        extraInfo: String = "",
        status: NotificationStatus = .pending,
        unread: Bool = true,
        replyDraft: String? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.source = source
        self.priority = priority
        self.timestamp = timestamp
        self.deadline = deadline
        self.extraInfo = extraInfo
        self.status = status
        self.unread = unread
        self.replyDraft = replyDraft
        self.updatedAt = updatedAt ?? Date()
    }

    /// 保持与状态解耦：将消息标记为已读状态。
    public func markAsRead(_ read: Bool = true) {
        unread = !read
        updatedAt = Date()
    }

    /// 保持未读语义独立：更新仅影响 unread。
    public func markAsUnread(_ unread: Bool = true) {
        self.unread = unread
        updatedAt = Date()
    }

    /// 只处理本地回复草稿，不修改状态，便于下一次回到页面时保留。
    public func setReplyDraft(_ draft: String?) {
        replyDraft = draft
        updatedAt = Date()
    }

    /// 在反馈成功提交后清空草稿。
    public func clearReplyDraftAfterSubmit() {
        replyDraft = nil
        updatedAt = Date()
    }

}

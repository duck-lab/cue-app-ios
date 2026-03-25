import Foundation

public enum NotificationDomainError: Error, LocalizedError, Equatable {
    case invalidTransition(from: NotificationStatus, to: NotificationStatus)
    case sameStatusNoop(status: NotificationStatus)
    case missingNotification

    public var errorDescription: String? {
        switch self {
        case let .invalidTransition(from, to):
            "Invalid status transition: \(from) -> \(to)"
        case .sameStatusNoop:
            "The notification is already in this status."
        case .missingNotification:
            "No notification object was found for the update."
        }
    }
}

public enum NotificationStateMachine {
    private static let allowedTransitions: [NotificationStatus: Set<NotificationStatus>] = [
        .pending: [.inProgress, .completed, .ignored],
        .inProgress: [.completed, .ignored]
    ]

    public static func isTransitionAllowed(from: NotificationStatus, to: NotificationStatus) -> Bool {
        guard from != to else {
            return false
        }

        return allowedTransitions[from, default: []].contains(to)
    }

    public static func availableTransitions(from status: NotificationStatus) -> Set<NotificationStatus> {
        allowedTransitions[status, default: []]
    }

    public static func validateTransition(from: NotificationStatus, to: NotificationStatus) throws {
        guard from != to else {
            throw NotificationDomainError.sameStatusNoop(status: from)
        }

        guard isTransitionAllowed(from: from, to: to) else {
            throw NotificationDomainError.invalidTransition(from: from, to: to)
        }
    }

    public static func validateItemExists(_ item: NotificationItem?) throws -> NotificationItem {
        guard let item else {
            throw NotificationDomainError.missingNotification
        }

        return item
    }
}

extension NotificationItem {
    /// 校验并更新通知状态；完成/忽略状态默认终态，不允许再次回退。
    public func updateStatus(to newStatus: NotificationStatus) throws {
        try NotificationStateMachine.validateTransition(from: status, to: newStatus)
        status = newStatus
        updatedAt = Date()
    }
}

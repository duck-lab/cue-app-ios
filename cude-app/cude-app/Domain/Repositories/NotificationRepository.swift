import Foundation

public protocol NotificationRepository: Sendable {
    func fetchNotifications() async throws -> [NotificationItemPayload]

    func submitFeedback(_ feedback: StatusFeedback) async throws
}

public extension NotificationRepository {
    func acknowledge(notificationID: String) async -> Result<Void, RepositoryError> {
        return .success(())
    }
}

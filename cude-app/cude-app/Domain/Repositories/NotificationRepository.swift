import Foundation

public protocol NotificationRepository: Sendable {
    func fetchNotifications() async -> Result<[NotificationItem], RepositoryError>

    func submitFeedback(_ feedback: StatusFeedback) async -> Result<Void, RepositoryError>
}

public extension NotificationRepository {
    func acknowledge(notificationID: String) async -> Result<Void, RepositoryError> {
        return .success(())
    }
}

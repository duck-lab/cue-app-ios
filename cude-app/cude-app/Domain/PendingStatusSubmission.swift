import Foundation
import SwiftData

@Model
public final class PendingStatusSubmission {
    @Attribute(.unique) public var id: String
    public var notificationId: String
    public var targetStatusRaw: String
    public var comment: String?
    public var createdAt: Date
    public var updatedAt: Date
    public var attempts: Int
    public var nextRetryAt: Date
    public var lastErrorMessage: String?
    public var lastClientPlatform: String
    public var lastClientVersion: String
    public var lastClientDevice: String

    public var targetStatus: NotificationStatus {
        NotificationStatus(rawValue: targetStatusRaw) ?? .pending
    }

    public init(
        id: String = UUID().uuidString,
        notificationId: String,
        targetStatus: NotificationStatus,
        comment: String? = nil,
        createdAt: Date = Date(),
        attempts: Int = 0,
        nextRetryAt: Date,
        lastErrorMessage: String? = nil,
        lastClientMeta: ClientMeta
    ) {
        self.id = id
        self.notificationId = notificationId
        self.targetStatusRaw = targetStatus.rawValue
        self.comment = comment
        self.createdAt = createdAt
        self.updatedAt = createdAt
        self.attempts = attempts
        self.nextRetryAt = nextRetryAt
        self.lastErrorMessage = lastErrorMessage
        self.lastClientPlatform = lastClientMeta.platform
        self.lastClientVersion = lastClientMeta.version
        self.lastClientDevice = lastClientMeta.device
    }

    public var clientMeta: ClientMeta {
        ClientMeta(
            platform: lastClientPlatform,
            version: lastClientVersion,
            device: lastClientDevice
        )
    }
}

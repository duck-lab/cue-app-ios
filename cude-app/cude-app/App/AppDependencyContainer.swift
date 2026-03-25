import Foundation
import Combine
import SwiftData
import SwiftUI

#if os(iOS)
import UIKit
#endif

public enum RepositorySource {
    case mock
    case api
}

public enum AppFeatureFlags {
    public static var repositorySource: RepositorySource {
        let env = ProcessInfo.processInfo.environment

        if let value = env["CUDE_REPOSITORY_SOURCE"]?.lowercased() {
            if value == "api" {
                return .api
            }
            if value == "mock" {
                return .mock
            }
        }

        return .mock
    }

    public static var pollingInterval: TimeInterval {
        let env = ProcessInfo.processInfo.environment
        if let value = env["CUDE_POLLING_INTERVAL"],
           let interval = Double(value), interval > 0 {
            return interval
        }

        return 30
    }

    public static var maxSubmissionRetryAttempts: Int {
        let env = ProcessInfo.processInfo.environment
        if let value = env["CUDE_MAX_RETRY_ATTEMPTS"],
           let attempts = Int(value), attempts > 0 {
            return attempts
        }

        return 3
    }

    public static var baseRetryDelaySeconds: TimeInterval {
        let env = ProcessInfo.processInfo.environment
        if let value = env["CUDE_BASE_RETRY_DELAY"],
           let delay = Double(value), delay > 0 {
            return delay
        }

        return 2
    }
}

public enum AppDependencyContainer {
    public static func makeRepository() -> NotificationRepository {
        switch AppFeatureFlags.repositorySource {
        case .mock:
            return NotificationRepositoryMock()
        case .api:
            return NotificationRepositoryMock()
        }
    }

    public static func makeModelContainer(inMemoryOnly: Bool = false) -> ModelContainer {
        ModelContainerFactory.makeDefaultContainer(inMemoryOnly: inMemoryOnly)
    }

}

public struct SubmissionDiagnostics: Sendable {
    public var totalSubmitAttempts: Int = 0
    public var totalSubmitSuccess: Int = 0
    public var totalSubmitFailure: Int = 0
    public var totalNonRetryableFailures: Int = 0
    public var totalQueueEnqueued: Int = 0
    public var totalQueueReplayAttempts: Int = 0
    public var totalQueueReplaySuccess: Int = 0
    public var totalQueueReplayFailure: Int = 0
    public var totalQueueGivenUp: Int = 0
    public var totalManualRetryRequests: Int = 0
    public var totalManualRetryMisses: Int = 0
    public var lastErrorMessage: String?
    public var lastQueueEvent: String?

    public init() {}
}

@MainActor
public final class AppRuntime: ObservableObject {
    public let repository: NotificationRepository
    public let modelContainer: ModelContainer
    public lazy var pollingScheduler: PollingScheduler = {
        PollingScheduler(
            intervalSeconds: AppFeatureFlags.pollingInterval,
            action: { [weak self] in
                guard let self else {
                    return .success(())
                }

                return await self.refreshNotificationStore()
            },
            onFailure: { error in
                print("[Polling] refresh failed: \(error)")
            }
        )
    }()
    public let maxRetryAttempts: Int
    public let baseRetryDelaySeconds: TimeInterval
    @Published public private(set) var diagnostics: SubmissionDiagnostics = SubmissionDiagnostics()

    public var modelContext: ModelContext {
        modelContainer.mainContext
    }

    public var submissionDiagnosticsSummary: String {
        [
            "submitAttempts=\(diagnostics.totalSubmitAttempts)",
            "submitSuccess=\(diagnostics.totalSubmitSuccess)",
            "submitFailure=\(diagnostics.totalSubmitFailure)",
            "enqueued=\(diagnostics.totalQueueEnqueued)",
            "replayAttempts=\(diagnostics.totalQueueReplayAttempts)",
            "replaySuccess=\(diagnostics.totalQueueReplaySuccess)",
            "replayFailure=\(diagnostics.totalQueueReplayFailure)",
            "givenUp=\(diagnostics.totalQueueGivenUp)",
            "manualRetryRequests=\(diagnostics.totalManualRetryRequests)",
            "manualRetryMisses=\(diagnostics.totalManualRetryMisses)",
        ].joined(separator: " | ")
    }

    public init(
        repository: NotificationRepository? = nil,
        inMemoryOnly: Bool = false
    ) {
        self.repository = repository ?? AppDependencyContainer.makeRepository()
        modelContainer = AppDependencyContainer.makeModelContainer(inMemoryOnly: inMemoryOnly)
        maxRetryAttempts = AppFeatureFlags.maxSubmissionRetryAttempts
        baseRetryDelaySeconds = AppFeatureFlags.baseRetryDelaySeconds
    }

    public func refreshNotificationStore() async -> Result<Void, Error> {
        let result = await repository.fetchNotifications()

        switch result {
        case let .success(items):
            do {
                try mergeRemoteItemsIntoStore(items)
                await processPendingSubmissions()
                diagnostics.lastQueueEvent = "refresh_success"
                return .success(())
            } catch {
                diagnostics.lastErrorMessage = error.localizedDescription
                diagnostics.lastQueueEvent = "refresh_merge_failed"
                return .failure(error)
            }
        case let .failure(error):
            diagnostics.lastErrorMessage = error.localizedDescription
            diagnostics.lastQueueEvent = "refresh_failed"
            await processPendingSubmissions()
            return .failure(error)
        }
    }

    public func clearAllNotifications() throws {
        let descriptor = FetchDescriptor<NotificationItem>()
        let existing = try modelContext.fetch(descriptor)

        for item in existing {
            modelContext.delete(item)
        }

        try modelContext.save()
    }

    private func mergeRemoteItemsIntoStore(_ remoteItems: [NotificationItem]) throws {
        let descriptor = FetchDescriptor<NotificationItem>()
        let existingItems = try modelContext.fetch(descriptor)
        var existingByID = Dictionary(uniqueKeysWithValues: existingItems.map { ($0.id, $0) })
        let incomingIDs = Set(remoteItems.map(\.id))

        for item in remoteItems {
            if let existing = existingByID.removeValue(forKey: item.id) {
                let shouldKeepLocalStatus = pendingSubmission(for: item.id) != nil

                existing.title = item.title
                existing.source = item.source
                existing.priority = item.priority
                existing.timestamp = item.timestamp
                existing.deadline = item.deadline
                existing.extraInfo = item.extraInfo
                if !shouldKeepLocalStatus {
                    existing.status = item.status
                    existing.unread = item.unread
                }
                existing.updatedAt = item.updatedAt

                if existing.replyDraft == nil {
                    existing.replyDraft = item.replyDraft
                }

                continue
            }

            let clone = NotificationItem(
                id: item.id,
                title: item.title,
                source: item.source,
                priority: item.priority,
                timestamp: item.timestamp,
                deadline: item.deadline,
                extraInfo: item.extraInfo,
                status: item.status,
                unread: item.unread,
                replyDraft: item.replyDraft,
                updatedAt: item.updatedAt
            )
            modelContext.insert(clone)
        }

        for item in existingByID.values where !incomingIDs.contains(item.id) {
            modelContext.delete(item)
        }

        if modelContext.hasChanges {
            try modelContext.save()
        }
    }

    public func submitStatus(
        itemID: String,
        status: NotificationStatus,
        comment: String?
    ) async -> Result<Void, Error> {
        do {
            diagnostics.totalSubmitAttempts += 1
            diagnostics.lastQueueEvent = "submit_started"

            guard let item = try fetchNotification(by: itemID) else {
                diagnostics.totalSubmitFailure += 1
                diagnostics.lastErrorMessage = RepositoryError.notFound.errorDescription
                diagnostics.lastQueueEvent = "submit_missing_item"
                return .failure(RepositoryError.notFound)
            }

            let normalizedComment = comment?.trimmingCharacters(in: .whitespacesAndNewlines)
            let commentToSend = normalizedComment?.isEmpty == true ? nil : normalizedComment

            let previousStatus = item.status
            item.status = status
            item.unread = false
            item.replyDraft = commentToSend
            item.updatedAt = Date()

            if item.status != previousStatus {
                do {
                    try item.updateStatus(to: status)
                } catch {
                    // Keep the optimistic local status so the UI still reflects the user's choice.
                }
            }

            let feedback = StatusFeedback(
                notificationId: item.id,
                status: status,
                comment: commentToSend,
                timestamp: Date(),
                clientMeta: ClientMeta(platform: currentPlatformName, version: currentVersion, device: currentDevice)
            )
        
            let result = await repository.submitFeedback(feedback)
            switch result {
            case .success:
                diagnostics.totalSubmitSuccess += 1
                diagnostics.lastQueueEvent = "submit_success"
                diagnostics.lastErrorMessage = nil
                removePendingSubmission(for: item.id)
                item.clearReplyDraftAfterSubmit()

                if modelContext.hasChanges {
                    try modelContext.save()
                }

                return .success(())
            case let .failure(error):
                diagnostics.totalSubmitFailure += 1
                diagnostics.lastErrorMessage = error.localizedDescription
                let shouldRetry = error.isRetryable && maxRetryAttempts > 0
                if shouldRetry {
                    diagnostics.totalQueueEnqueued += 1
                    diagnostics.lastQueueEvent = "submit_failed_queued"
                    enqueuePendingSubmission(
                        for: item.id,
                        status: status,
                        comment: commentToSend,
                        error: error,
                        clientMeta: feedback.clientMeta,
                        initialDelay: baseRetryDelaySeconds
                    )
                } else {
                    diagnostics.totalNonRetryableFailures += 1
                    diagnostics.lastQueueEvent = "submit_failed_non_retryable"
                }

                if modelContext.hasChanges {
                    try modelContext.save()
                }

                return .failure(error)
            }
        } catch {
            return .failure(error)
        }
    }

    public func pendingSubmissions() -> [PendingStatusSubmission] {
        do {
            let descriptor = FetchDescriptor<PendingStatusSubmission>()
            return try modelContext.fetch(descriptor)
        } catch {
            return []
        }
    }

    public func processPendingSubmissions(force: Bool = false) async {
        do {
            diagnostics.lastQueueEvent = "retry_cycle_started"
            let now = Date()
            let descriptor = FetchDescriptor<PendingStatusSubmission>()
            let allPending = try modelContext.fetch(descriptor)
            let pendingItems = force ? allPending : allPending.filter { $0.nextRetryAt <= now }

            for submission in pendingItems {
                let feedback = StatusFeedback(
                    notificationId: submission.notificationId,
                    status: submission.targetStatus,
                    comment: submission.comment,
                    timestamp: Date(),
                    clientMeta: submission.clientMeta
                )

                let result = await repository.submitFeedback(feedback)
                diagnostics.totalQueueReplayAttempts += 1

                switch result {
                case .success:
                    let reachedRetryLimit = submission.attempts > 0
                        && maxRetryAttempts > 0
                        && submission.attempts >= maxRetryAttempts - 1

                    if reachedRetryLimit {
                        diagnostics.totalQueueReplaySuccess += 1
                        diagnostics.lastQueueEvent = "retry_success_after_limit"
                        submission.lastErrorMessage = submission.lastErrorMessage ?? ""
                        submission.updatedAt = Date()
                        continue
                    }

                    diagnostics.totalQueueReplaySuccess += 1
                    diagnostics.lastQueueEvent = "retry_success"
                    diagnostics.lastErrorMessage = nil
                    if let item = try fetchNotification(by: submission.notificationId) {
                        item.clearReplyDraftAfterSubmit()
                    }

                    modelContext.delete(submission)
                case let .failure(error):
                    if error.isRetryable && submission.attempts + 1 < maxRetryAttempts {
                        diagnostics.totalQueueReplayFailure += 1
                        diagnostics.lastQueueEvent = "retry_scheduled"
                        submission.attempts += 1
                        submission.nextRetryAt = now.addingTimeInterval(
                            pow(2.0, Double(submission.attempts)) * baseRetryDelaySeconds
                        )
                        submission.lastErrorMessage = error.localizedDescription
                        submission.updatedAt = now
                    } else {
                        diagnostics.totalQueueGivenUp += 1
                        diagnostics.lastQueueEvent = "retry_given_up"
                        submission.lastErrorMessage = error.localizedDescription
                        submission.updatedAt = now
                    }
                }
            }

            if modelContext.hasChanges {
                try modelContext.save()
            }
        } catch {
            diagnostics.lastErrorMessage = error.localizedDescription
            diagnostics.lastQueueEvent = "retry_cycle_failed"
            print("[RetryQueue] process failed: \(error)")
        }
    }

    public func retryPendingSubmission(itemID: String) async -> Result<Void, Error> {
        do {
            diagnostics.totalManualRetryRequests += 1
            let descriptor = FetchDescriptor<PendingStatusSubmission>()
            let matches = try modelContext.fetch(descriptor).filter { $0.notificationId == itemID }

            guard let submission = matches.first else {
                diagnostics.totalManualRetryMisses += 1
                diagnostics.lastQueueEvent = "manual_retry_missing"
                return .failure(RepositoryError.notFound)
            }

            submission.nextRetryAt = Date()
            try modelContext.save()
            diagnostics.lastQueueEvent = "manual_retry_requested"
            await processPendingSubmissions(force: true)

            return .success(())
        } catch {
            return .failure(error)
        }
    }

    public func clearPendingSubmission(for itemID: String) {
        diagnostics.lastQueueEvent = "clear_single_pending"
        removePendingSubmission(for: itemID)
        if modelContext.hasChanges {
            try? modelContext.save()
        }
    }

    public func pendingSubmission(for itemID: String) -> PendingStatusSubmission? {
        do {
            let descriptor = FetchDescriptor<PendingStatusSubmission>()
            return try modelContext.fetch(descriptor).first(where: { $0.notificationId == itemID })
        } catch {
            return nil
        }
    }

    public func clearAllPendingSubmissions() {
        do {
            diagnostics.lastQueueEvent = "clear_all_pending"
            let descriptor = FetchDescriptor<PendingStatusSubmission>()
            let existing = try modelContext.fetch(descriptor)
            for item in existing {
                modelContext.delete(item)
            }

            if modelContext.hasChanges {
                try modelContext.save()
            }
        } catch {
            print("[RetryQueue] clear failed: \(error)")
        }
    }

    private func fetchNotification(by itemID: String) throws -> NotificationItem? {
        let descriptor = FetchDescriptor<NotificationItem>()
        let all = try modelContext.fetch(descriptor)
        return all.first(where: { $0.id == itemID })
    }

    private func removePendingSubmission(for itemID: String) {
        do {
            diagnostics.lastQueueEvent = "remove_pending"
            let descriptor = FetchDescriptor<PendingStatusSubmission>()
            let existing = try modelContext.fetch(descriptor)

            for item in existing where item.notificationId == itemID {
                modelContext.delete(item)
            }
        } catch {
            print("[RetryQueue] remove failed: \(error)")
        }
    }

    private func enqueuePendingSubmission(
        for itemID: String,
        status: NotificationStatus,
        comment: String?,
        error: RepositoryError,
        clientMeta: ClientMeta,
        initialDelay: TimeInterval
    ) {
        do {
            diagnostics.lastQueueEvent = "enqueue_pending"
            let descriptor = FetchDescriptor<PendingStatusSubmission>()
            let existing = try modelContext.fetch(descriptor)

            for item in existing where item.notificationId == itemID {
                modelContext.delete(item)
            }

            let submission = PendingStatusSubmission(
                notificationId: itemID,
                targetStatus: status,
                comment: comment,
                attempts: 0,
                nextRetryAt: Date().addingTimeInterval(initialDelay),
                lastErrorMessage: error.localizedDescription,
                lastClientMeta: clientMeta
            )

            modelContext.insert(submission)
        } catch {
            print("[RetryQueue] enqueue failed: \(error)")
        }
    }

    private var currentPlatformName: String {
        #if os(iOS)
        "iOS"
        #elseif os(macOS)
        "macOS"
        #elseif os(tvOS)
        "tvOS"
        #else
        "platform"
        #endif
    }

    private var currentDevice: String {
        #if os(iOS)
        UIDevice.current.model
        #else
        "desktop"
        #endif
    }

    private var currentVersion: String {
        "1.0.0"
    }
}

//
//  cude_appTests.swift
//  cude-appTests
//
//  Created by Oliver.W on 2026/3/25.
//

import Foundation
import Testing
import SwiftData
@testable import cude_app

private func isSuccess<T, E: Error>(_ result: Result<T, E>) -> Bool {
    if case .success = result {
        return true
    }
    return false
}

private func isFailure<T, E: Error>(_ result: Result<T, E>) -> Bool {
    if case .failure = result {
        return true
    }
    return false
}

private actor SubmissionRepositoryStub: NotificationRepository {
    private var fetchResult: Result<[NotificationItemPayload], RepositoryError>
    private var submitPlan: [Result<Void, RepositoryError>]
    private var submitted: [StatusFeedback] = []

    init(
        fetchResult: Result<[NotificationItemPayload], RepositoryError> = .success([]),
        submitPlan: [Result<Void, RepositoryError>] = []
    ) {
        self.fetchResult = fetchResult
        self.submitPlan = submitPlan
    }

    func fetchNotifications() async throws -> [NotificationItemPayload] {
        switch fetchResult {
        case let .success(items):
            return items
        case let .failure(error):
            throw error
        }
    }

    func submitFeedback(_ feedback: StatusFeedback) async throws {
        submitted.append(feedback)

        if !submitPlan.isEmpty {
            let next = submitPlan.removeFirst()
            switch next {
            case .success:
                return
            case let .failure(error):
                throw error
            }
        }
    }

    func setFetchResult(_ value: Result<[NotificationItemPayload], RepositoryError>) {
        fetchResult = value
    }

    func appendSubmitResult(_ value: Result<Void, RepositoryError>) {
        submitPlan.append(value)
    }

    func submittedCount() -> Int {
        submitted.count
    }

    func lastSubmittedFeedback() -> StatusFeedback? {
        submitted.last
    }
}

struct cude_appTests {

    @Test func notificationItemDefaultValuesAreUsable() {
        let now = Date()
        let item = NotificationItem(
            title: "Build Failed",
            source: "CI",
            priority: .high,
            timestamp: now,
            deadline: now.addingTimeInterval(3600),
            extraInfo: "Retry 3 times",
            status: .pending,
            unread: true
        )

        #expect(item.id.isEmpty == false)
        #expect(item.title == "Build Failed")
        #expect(item.source == "CI")
        #expect(item.priority == .high)
        #expect(item.status == .pending)
        #expect(item.unread == true)
        #expect(item.replyDraft == nil)
        #expect(item.updatedAt >= item.timestamp)
        #expect(item.isOverdue == false)
        #expect(item.statusText == "Pending")
    }

    @Test func statusTransitionsConformToRules() {
        #expect(NotificationStateMachine.isTransitionAllowed(
            from: .pending,
            to: .inProgress
        ))
        #expect(NotificationStateMachine.isTransitionAllowed(
            from: .pending,
            to: .completed
        ))
        #expect(NotificationStateMachine.isTransitionAllowed(
            from: .pending,
            to: .ignored
        ))
        #expect(NotificationStateMachine.isTransitionAllowed(
            from: .inProgress,
            to: .completed
        ))
        #expect(NotificationStateMachine.isTransitionAllowed(
            from: .inProgress,
            to: .ignored
        ))

        #expect(NotificationStateMachine.isTransitionAllowed(
            from: .completed,
            to: .pending
        ) == false)
        #expect(NotificationStateMachine.isTransitionAllowed(
            from: .ignored,
            to: .inProgress
        ) == false)
        #expect(NotificationStateMachine.isTransitionAllowed(
            from: .completed,
            to: .completed
        ) == false)
    }

    @Test func transitionValidationReturnsExpectedErrors() {
        #expect(throws: NotificationDomainError.sameStatusNoop(status: .pending)) {
            try NotificationStateMachine.validateTransition(from: .pending, to: .pending)
        }

        #expect(throws: NotificationDomainError.invalidTransition(from: .completed, to: .pending)) {
            try NotificationStateMachine.validateTransition(from: .completed, to: .pending)
        }

        #expect(throws: NotificationDomainError.invalidTransition(from: .ignored, to: .completed)) {
            try NotificationStateMachine.validateTransition(from: .ignored, to: .completed)
        }
    }

    @Test func missingNotificationCanBeDetected() {
        #expect(throws: NotificationDomainError.missingNotification) {
            _ = try NotificationStateMachine.validateItemExists(nil)
        }
    }

    @Test func replyDraftLifecycleAndUnreadAreIndependent() throws {
        var item = NotificationItem(
            id: "n-001",
            title: "Reply Draft",
            source: "Tester",
            priority: .normal,
            timestamp: Date(),
            status: .pending,
            unread: true
        )

        item.setReplyDraft("local draft")
        item.markAsRead()

        #expect(item.replyDraft == "local draft")
        #expect(item.unread == false)

        item.clearReplyDraftAfterSubmit()
        try item.updateStatus(to: .inProgress)
        item.markAsUnread()

        #expect(item.replyDraft == nil)
        #expect(item.status == .inProgress)
        #expect(item.unread == true)
    }

    @Test @MainActor func feedbackCanSerializeWithClientMeta() throws {
        let meta = ClientMeta(platform: "iOS", version: "1.0.0", device: "Simulator")
        let feedback = StatusFeedback(
            notificationId: "n-001",
            status: .completed,
            comment: "Done",
            timestamp: Date(),
            clientMeta: meta
        )

        let encoded = try JSONEncoder().encode(feedback)
        let decoded = try JSONDecoder().decode(StatusFeedback.self, from: encoded)

        #expect(decoded.notificationId == feedback.notificationId)
        #expect(decoded.status == feedback.status)
        #expect(decoded.clientMeta == feedback.clientMeta)
    }

    @Test func itemStatusTransitionCanProgressSafely() throws {
        var item = NotificationItem(
            id: "n-002",
            title: "Status transition",
            source: "System",
            priority: .urgent,
            timestamp: Date(),
            status: .pending,
            unread: true
        )

        try item.updateStatus(to: .inProgress)
        try item.updateStatus(to: .completed)

        #expect(item.status == .completed)
    }

    @Test @MainActor func pollingSchedulerSkipsOverlappingTicks() async {
        actor PollingCounter {
            private var inFlight = 0
            private var maxInFlight = 0
            private var tickCount = 0

            func beginTick() {
                inFlight += 1
                if inFlight > maxInFlight {
                    maxInFlight = inFlight
                }
            }

            func endTick() {
                inFlight -= 1
                tickCount += 1
            }

            func snapshot() -> (inFlight: Int, maxInFlight: Int, tickCount: Int) {
                (inFlight, maxInFlight, tickCount)
            }
        }

        let counter = PollingCounter()
        let scheduler = PollingScheduler(
            intervalSeconds: 0.02,
            action: {
                await counter.beginTick()
                try? await Task.sleep(nanoseconds: 80_000_000)
                await counter.endTick()

                return .success(())
            }
        )

        defer {
            scheduler.stop()
        }

        scheduler.start()

        try? await Task.sleep(nanoseconds: 260_000_000)
        let snapshot = await counter.snapshot()

        #expect(snapshot.maxInFlight == 1)
        #expect(snapshot.tickCount >= 1)
    }

    @Test @MainActor func pollingSchedulerPausesAndResumes() async {
        actor PollingCounter {
            private var tickCount = 0

            func beginTick() {
                tickCount += 1
            }

            func snapshot() -> Int {
                tickCount
            }
        }

        let counter = PollingCounter()
        let scheduler = PollingScheduler(
            intervalSeconds: 0.05,
            action: {
                await counter.beginTick()
                return .success(())
            }
        )

        defer {
            scheduler.stop()
        }

        scheduler.start()

        try? await Task.sleep(nanoseconds: 180_000_000)
        let runningCount = await counter.snapshot()
        #expect(runningCount >= 2)

        scheduler.pause()
        let pausedCount = await counter.snapshot()

        try? await Task.sleep(nanoseconds: 160_000_000)
        #expect(await counter.snapshot() == pausedCount)

        scheduler.resume()
        try? await Task.sleep(nanoseconds: 120_000_000)

        #expect(await counter.snapshot() > pausedCount)
    }

    @Test @MainActor func submitStatusPersistsAndReplaysPendingSubmission() async {
        let repository = SubmissionRepositoryStub(submitPlan: [
            .failure(.networkError(underlying: URLError(.cannotConnectToHost))),
            .success(()),
        ])
        let runtime = AppRuntime(repository: repository, inMemoryOnly: true)

        let localItem = NotificationItem(
            id: "pending-replay-01",
            title: "测试任务",
            source: "系统",
            priority: .normal,
            timestamp: Date(),
            status: .pending,
            unread: true
        )
        runtime.modelContext.insert(localItem)
        try? runtime.modelContext.save()

        let first = await runtime.submitStatus(
            itemID: localItem.id,
            status: .completed,
            comment: "offline update"
        )
        #expect(isFailure(first))

        let pending = runtime.pendingSubmission(for: localItem.id)
        #expect(pending != nil)
        #expect(pending?.attempts == 0)

        await runtime.processPendingSubmissions(force: true)

        #expect(runtime.pendingSubmission(for: localItem.id) == nil)
        #expect(await repository.submittedCount() == 2)
        let last = await repository.lastSubmittedFeedback()
        #expect(last?.notificationId == localItem.id)
    }

    @Test @MainActor func processPendingSubmissionStopsAfterConfiguredRetries() async {
        let repository = SubmissionRepositoryStub(submitPlan: [
            .failure(.networkError(underlying: URLError(.cannotConnectToHost))),
            .failure(.networkError(underlying: URLError(.cannotConnectToHost))),
            .failure(.networkError(underlying: URLError(.cannotConnectToHost))),
            .failure(.networkError(underlying: URLError(.cannotConnectToHost))),
        ])
        let runtime = AppRuntime(repository: repository, inMemoryOnly: true)

        let localItem = NotificationItem(
            id: "pending-retry-limit",
            title: "重试次数",
            source: "系统",
            priority: .high,
            timestamp: Date(),
            status: .pending,
            unread: true
        )
        runtime.modelContext.insert(localItem)
        try? runtime.modelContext.save()

        let submitResult = await runtime.submitStatus(
            itemID: localItem.id,
            status: .inProgress,
            comment: "limit-test"
        )
        #expect(isFailure(submitResult))

        await runtime.processPendingSubmissions(force: true)
        await runtime.processPendingSubmissions(force: true)
        await runtime.processPendingSubmissions(force: true)
        await runtime.processPendingSubmissions(force: true)

        let pending = runtime.pendingSubmission(for: localItem.id)
        let expectedAttempts = min(4, max(0, runtime.maxRetryAttempts - 1))
        #expect(pending != nil)
        #expect(pending?.attempts == expectedAttempts)
        #expect(pending?.lastErrorMessage != nil)
        #expect(await repository.submittedCount() == 5)
    }

    @Test @MainActor func retryPendingSubmissionForcesImmediateReplay() async {
        let repository = SubmissionRepositoryStub(submitPlan: [
            .failure(.networkError(underlying: URLError(.cannotConnectToHost))),
            .success(()),
        ])
        let runtime = AppRuntime(repository: repository, inMemoryOnly: true)

        let localItem = NotificationItem(
            id: "pending-force-replay",
            title: "手动重试",
            source: "系统",
            priority: .normal,
            timestamp: Date(),
            status: .pending,
            unread: true
        )
        runtime.modelContext.insert(localItem)
        try? runtime.modelContext.save()

        let first = await runtime.submitStatus(
            itemID: localItem.id,
            status: .ignored,
            comment: "manual test"
        )
        #expect(isFailure(first))

        let retry = await runtime.retryPendingSubmission(itemID: localItem.id)
        #expect(isSuccess(retry))
        #expect(runtime.pendingSubmission(for: localItem.id) == nil)
        #expect(await repository.submittedCount() == 2)
    }

    @Test @MainActor func clearAllPendingSubmissionsRemovesQueueEntries() async {
        let repository = SubmissionRepositoryStub(submitPlan: [
            .failure(.networkError(underlying: URLError(.cannotConnectToHost))),
            .failure(.networkError(underlying: URLError(.cannotConnectToHost))),
        ])
        let runtime = AppRuntime(repository: repository, inMemoryOnly: true)

        runtime.modelContext.insert(
            NotificationItem(
                id: "pending-clear-1",
                title: "可清理",
                source: "系统",
                priority: .low,
                timestamp: Date(),
                status: .pending,
                unread: true
            )
        )
        runtime.modelContext.insert(
            NotificationItem(
                id: "pending-clear-2",
                title: "可清理2",
                source: "系统",
                priority: .low,
                timestamp: Date(),
                status: .pending,
                unread: true
            )
        )
        try? runtime.modelContext.save()

        _ = await runtime.submitStatus(itemID: "pending-clear-1", status: .completed, comment: nil)
        _ = await runtime.submitStatus(itemID: "pending-clear-2", status: .inProgress, comment: nil)

        #expect(runtime.pendingSubmission(for: "pending-clear-1") != nil)
        #expect(runtime.pendingSubmission(for: "pending-clear-2") != nil)

        runtime.clearAllPendingSubmissions()

        #expect(runtime.pendingSubmission(for: "pending-clear-1") == nil)
        #expect(runtime.pendingSubmission(for: "pending-clear-2") == nil)
    }

    @Test @MainActor func clearSinglePendingSubmissionForItem() async {
        let repository = SubmissionRepositoryStub(submitPlan: [
            .failure(.networkError(underlying: URLError(.cannotConnectToHost))),
            .failure(.networkError(underlying: URLError(.cannotConnectToHost))),
        ])
        let runtime = AppRuntime(repository: repository, inMemoryOnly: true)

        let first = NotificationItem(
            id: "pending-clear-one-1",
            title: "只清除一个",
            source: "系统",
            priority: .normal,
            timestamp: Date(),
            status: .pending,
            unread: true
        )
        let second = NotificationItem(
            id: "pending-clear-one-2",
            title: "保留一个",
            source: "系统",
            priority: .normal,
            timestamp: Date(),
            status: .pending,
            unread: true
        )

        runtime.modelContext.insert(first)
        runtime.modelContext.insert(second)
        try? runtime.modelContext.save()

        _ = await runtime.submitStatus(itemID: first.id, status: .completed, comment: nil)
        _ = await runtime.submitStatus(itemID: second.id, status: .inProgress, comment: nil)

        #expect(runtime.pendingSubmission(for: first.id) != nil)
        #expect(runtime.pendingSubmission(for: second.id) != nil)

        runtime.clearPendingSubmission(for: first.id)

        #expect(runtime.pendingSubmission(for: first.id) == nil)
        #expect(runtime.pendingSubmission(for: second.id) != nil)
    }

    @Test @MainActor func submitStatusWithNonRetryableFailureDoesNotQueue() async {
        let repository = SubmissionRepositoryStub(
            submitPlan: [.failure(.unexpectedStatusCode(401))]
        )
        let runtime = AppRuntime(repository: repository, inMemoryOnly: true)

        runtime.modelContext.insert(
            NotificationItem(
                id: "pending-nonretryable",
                title: "非重试错误",
                source: "系统",
                priority: .high,
                timestamp: Date(),
                status: .pending,
                unread: true
            )
        )
        try? runtime.modelContext.save()

        let result = await runtime.submitStatus(
            itemID: "pending-nonretryable",
            status: .ignored,
            comment: "forbidden"
        )

        #expect(isFailure(result))
        #expect(runtime.pendingSubmission(for: "pending-nonretryable") == nil)
    }

    @Test @MainActor func submitStatusForMissingItemReturnsNotFound() async {
        let runtime = AppRuntime(repository: NotificationRepositoryMock(), inMemoryOnly: true)

        let result = await runtime.submitStatus(
            itemID: "does-not-exist",
            status: .completed,
            comment: nil
        )

        #expect(isFailure(result))
    }

    @Test @MainActor func retryMissingPendingSubmissionReturnsNotFound() async {
        let runtime = AppRuntime(repository: NotificationRepositoryMock(), inMemoryOnly: true)

        let result = await runtime.retryPendingSubmission(itemID: "missing-item")

        #expect(isFailure(result))
    }

    @Test @MainActor func refreshKeepsLocalStatusWhenPendingSubmissionExists() async {
        let remote = [
            NotificationItem(
                id: "pending-merge-check",
                title: "待合并",
                source: "系统",
                priority: .urgent,
                timestamp: Date(),
                status: .pending,
                unread: true,
                updatedAt: Date()
            )
        ]
        let repository = SubmissionRepositoryStub(
            fetchResult: .success(remote.map(NotificationItemPayload.init(item:))),
            submitPlan: [
                .failure(.networkError(underlying: URLError(.cannotConnectToHost)))
            ]
        )
        let runtime = AppRuntime(repository: repository, inMemoryOnly: true)

        let localItem = NotificationItem(
            id: "pending-merge-check",
            title: "待合并",
            source: "系统",
            priority: .urgent,
            timestamp: Date(),
            status: .inProgress,
            unread: false,
            updatedAt: Date()
        )
        runtime.modelContext.insert(localItem)
        try? runtime.modelContext.save()

        let submitResult = await runtime.submitStatus(
            itemID: localItem.id,
            status: .completed,
            comment: nil
        )
        #expect(isFailure(submitResult))

        let refreshResult = await runtime.refreshNotificationStore()
        #expect(isSuccess(refreshResult))

        let all = try? runtime.modelContext.fetch(FetchDescriptor<NotificationItem>())
        let mergedItem = all?.first { $0.id == localItem.id }

        #expect(mergedItem?.status == .completed)
        #expect(mergedItem?.unread == false)
        #expect(runtime.pendingSubmission(for: localItem.id) != nil)
    }

    @Test @MainActor func submissionDiagnosticsTracksQueueLifecycle() async {
        let repository = SubmissionRepositoryStub(submitPlan: [
            .failure(.networkError(underlying: URLError(.cannotConnectToHost))),
            .success(()),
        ])
        let runtime = AppRuntime(repository: repository, inMemoryOnly: true)

        runtime.modelContext.insert(
            NotificationItem(
                id: "diag-item",
                title: "可观测",
                source: "系统",
                priority: .normal,
                timestamp: Date(),
                status: .pending,
                unread: true
            )
        )
        try? runtime.modelContext.save()

        #expect(runtime.diagnostics.totalSubmitAttempts == 0)

        let first = await runtime.submitStatus(itemID: "diag-item", status: .inProgress, comment: nil)
        #expect(isFailure(first))
        #expect(runtime.diagnostics.totalSubmitAttempts == 1)
        #expect(runtime.diagnostics.totalSubmitFailure == 1)
        #expect(runtime.diagnostics.totalQueueEnqueued == 1)
        #expect(runtime.diagnostics.totalQueueReplayAttempts == 0)

        await runtime.processPendingSubmissions(force: true)
        #expect(runtime.diagnostics.totalQueueReplayAttempts == 1)
        #expect(runtime.diagnostics.totalQueueReplaySuccess == 1)
        #expect(runtime.diagnostics.totalSubmitSuccess == 0)
        #expect(runtime.diagnostics.lastQueueEvent == "retry_success")
        #expect(runtime.submissionDiagnosticsSummary.contains("replaySuccess=1"))
    }

    @Test @MainActor func submissionDiagnosticsTracksManualRetryAndNonRetryablePath() async {
        let repository = SubmissionRepositoryStub(
            submitPlan: [
                .failure(.unexpectedStatusCode(404)),
            ]
        )
        let runtime = AppRuntime(repository: repository, inMemoryOnly: true)

        runtime.modelContext.insert(
            NotificationItem(
                id: "diag-non-retry",
                title: "不可重试",
                source: "系统",
                priority: .high,
                timestamp: Date(),
                status: .pending,
                unread: true
            )
        )
        try? runtime.modelContext.save()

        let first = await runtime.submitStatus(itemID: "diag-non-retry", status: .ignored, comment: nil)
        #expect(isFailure(first))
        #expect(runtime.diagnostics.totalNonRetryableFailures == 1)
        #expect(runtime.diagnostics.totalQueueEnqueued == 0)

        let manual = await runtime.retryPendingSubmission(itemID: "diag-non-retry")
        #expect(isFailure(manual))
        #expect(runtime.diagnostics.totalManualRetryMisses == 1)
    }

}

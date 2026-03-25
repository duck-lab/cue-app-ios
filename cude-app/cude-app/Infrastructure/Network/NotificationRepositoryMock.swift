import Foundation

public final class NotificationRepositoryMock: NotificationRepository, @unchecked Sendable {
    public enum MockScenario: Int, CaseIterable {
        case empty
        case mixedWithUnread
        case allRead
        case withNewMessage
    }

    public static let notificationsDidRefresh = Notification.Name("NotificationRepositoryMockDidRefresh")

    public let name = "mock"
    public let failureRate: Double
    public var onUpdate: (([NotificationItem]) -> Void)?

    private let (updateStream, updateContinuation) = AsyncStream.makeStream(of: Void.self)

    public var updateEvents: AsyncStream<Void> {
        updateStream
    }

    private var scenario: MockScenario
    private var currentItems: [NotificationItem]

    public init(
        initialScenario: MockScenario = .mixedWithUnread,
        failureRate: Double = 0.0
    ) {
        self.scenario = initialScenario
        self.currentItems = NotificationRepositoryMock.items(for: initialScenario)
        self.failureRate = failureRate
    }

    public func fetchNotifications() async -> Result<[NotificationItem], RepositoryError> {
        return .success(currentItems)
    }

    public func submitFeedback(_ feedback: StatusFeedback) async -> Result<Void, RepositoryError> {
        if Double.random(in: 0...1) < failureRate {
            return .failure(.networkError(underlying: URLError(.cannotConnectToHost)))
        }

        _ = feedback
        return .success(())
    }

    public func setScenario(_ newScenario: MockScenario) {
        scenario = newScenario
        currentItems = NotificationRepositoryMock.items(for: newScenario)
        notifyUpdate(reason: "Scenario switched: \(newScenario)")
    }

    public func nextScenario() {
        let all = MockScenario.allCases
        guard let currentIndex = all.firstIndex(of: scenario) else {
            setScenario(.empty)
            return
        }

        let nextIndex = (currentIndex + 1) % all.count
        setScenario(all[nextIndex])
    }

    public func addIncomingNotification(_ notification: NotificationItem) {
        currentItems.insert(notification, at: 0)
        notifyUpdate(reason: "Incoming notification appended")
    }

    public func buildDefaultFixtures() -> [MockScenario: [NotificationItem]] {
        [
            .empty: [],
            .mixedWithUnread: Self.defaultMixedItems,
            .allRead: Self.defaultAllReadItems,
            .withNewMessage: Self.defaultItemsWithArrival,
        ]
    }

    private func notifyUpdate(reason: String) {
        let info: [String: Any] = [
            "count": currentItems.count,
            "scenario": scenario,
            "reason": reason,
        ]
        NotificationCenter.default.post(
            name: Self.notificationsDidRefresh,
            object: self,
            userInfo: info
        )
        onUpdate?(currentItems)
        updateContinuation.yield()
    }

    private static func items(for scenario: MockScenario) -> [NotificationItem] {
        switch scenario {
        case .empty:
            return []
        case .mixedWithUnread:
            return defaultMixedItems
        case .allRead:
            return defaultAllReadItems
        case .withNewMessage:
            return defaultItemsWithArrival
        }
    }

    private static var defaultMixedItems: [NotificationItem] {
        [
            NotificationItem(
                id: "n-01",
                title: "服务请求审批",
                source: "HR 系统",
                priority: .normal,
                timestamp: Date().addingTimeInterval(-1_200),
                deadline: Date().addingTimeInterval(7_200),
                extraInfo: "请确认明天的会议安排与参与人名单",
                status: .inProgress,
                unread: true,
                replyDraft: nil,
                updatedAt: Date()
            ),
            NotificationItem(
                id: "n-02",
                title: "代码评审提醒",
                source: "Git 机器人",
                priority: .urgent,
                timestamp: Date().addingTimeInterval(-420),
                deadline: Date().addingTimeInterval(900),
                extraInfo: "PR #482 待你确认",
                status: .pending,
                unread: true,
                replyDraft: nil,
                updatedAt: Date().addingTimeInterval(-420)
            ),
            NotificationItem(
                id: "n-03",
                title: "周报已归档",
                source: "工作台",
                priority: .low,
                timestamp: Date().addingTimeInterval(-3_600),
                deadline: nil,
                extraInfo: "请在本周五前提交",
                status: .completed,
                unread: false,
                replyDraft: nil,
                updatedAt: Date().addingTimeInterval(-3_000)
            ),
        ]
    }

    private static var defaultAllReadItems: [NotificationItem] {
        [
            NotificationItem(
                id: "n-11",
                title: "日报已批阅",
                source: "邮件",
                priority: .low,
                timestamp: Date().addingTimeInterval(-12_000),
                deadline: nil,
                extraInfo: "今日提醒",
                status: .completed,
                unread: false,
                replyDraft: nil,
                updatedAt: Date().addingTimeInterval(-12_000)
            ),
            NotificationItem(
                id: "n-12",
                title: "系统任务完成",
                source: "任务平台",
                priority: .high,
                timestamp: Date().addingTimeInterval(-10_000),
                deadline: Date().addingTimeInterval(-2_000),
                extraInfo: "按时处理",
                status: .ignored,
                unread: false,
                replyDraft: nil,
                updatedAt: Date().addingTimeInterval(-10_000)
            ),
        ]
    }

    private static var defaultItemsWithArrival: [NotificationItem] {
        let existing = defaultMixedItems
        return [
            NotificationItem(
                id: "n-new",
                title: "紧急告警",
                source: "监控服务",
                priority: .urgent,
                timestamp: Date().addingTimeInterval(-120),
                deadline: Date().addingTimeInterval(600),
                extraInfo: "后端服务响应延迟，请立即处理",
                status: .pending,
                unread: true,
                replyDraft: nil,
                updatedAt: Date()
            )
        ] + existing
    }
}

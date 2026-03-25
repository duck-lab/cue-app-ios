import Foundation

public final class PollingScheduler {
    public enum State {
        case idle
        case running
        case paused
    }

    public typealias PollingAction = @Sendable () async -> Result<Void, Error>

    private let intervalSeconds: TimeInterval
    private let action: PollingAction
    private let onFailure: @Sendable (Error) -> Void
    private var task: Task<Void, Never>?
    private var state: State = .idle
    private var isRunningAction: Bool = false

    public init(
        intervalSeconds: TimeInterval = 30,
        action: @escaping PollingAction,
        onFailure: @escaping @Sendable (Error) -> Void = { _ in }
    ) {
        self.intervalSeconds = intervalSeconds
        self.action = action
        self.onFailure = onFailure
    }

    public func start() {
        guard task == nil else { return }
        state = .running
        task = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                await self.tick()

                if Task.isCancelled { break }

                do {
                    try await Task.sleep(nanoseconds: UInt64(self.intervalSeconds * 1_000_000_000))
                } catch {
                    await MainActor.run {
                        self.onFailure(CancellationError())
                    }
                    break
                }
            }
            await self.stop()
        }
    }

    public func pause() {
        task?.cancel()
        task = nil
        state = .paused
        isRunningAction = false
    }

    public func resume() {
        guard state == .paused else {
            if task == nil {
                state = .running
                start()
            }
            return
        }
        start()
    }

    public func reset(immediately: Bool = false) {
        pause()
        state = .idle
        if immediately {
            start()
        }
    }

    public func stop() {
        task?.cancel()
        task = nil
        state = .idle
        isRunningAction = false
    }

    private func tick() async {
        guard !Task.isCancelled else { return }
        guard !isRunningAction else { return }

        isRunningAction = true
        defer { isRunningAction = false }

        let result = await action()
        if case .failure(let error) = result {
            onFailure(error)
        }
    }
}

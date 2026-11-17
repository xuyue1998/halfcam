import Foundation

/// Bounds synchronous image work without blocking Swift's cooperative executor
/// while a request is waiting for an execution slot.
final class BoundedWorkQueue: @unchecked Sendable {
    private let queue: OperationQueue

    init(name: String, maximumConcurrentOperations: Int = 2) {
        queue = OperationQueue()
        queue.name = name
        queue.maxConcurrentOperationCount = max(1, maximumConcurrentOperations)
    }

    func run<Output: Sendable>(
        priority: TaskPriority = .userInitiated,
        _ work: @escaping @Sendable () -> Output
    ) async -> Output? {
        let result = WorkResult<Output>()
        let job = BlockOperation {
            result.store(autoreleasepool(invoking: work))
        }
        job.qualityOfService = priority >= .userInitiated ? .userInitiated : .utility
        job.queuePriority = priority >= .userInitiated ? .high : .low
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                // Completion also runs for an operation cancelled before execution.
                // Resuming only here avoids double-resumes and cancelled-job hangs.
                job.completionBlock = { [weak job] in
                    continuation.resume(returning: job?.isCancelled == false ? result.load() : nil)
                }
                if Task.isCancelled { job.cancel() }
                queue.addOperation(job)
            }
        } onCancel: {
            job.cancel()
        }
    }
}

private final class WorkResult<Value: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Value?

    func store(_ value: Value) { lock.withLock { self.value = value } }
    func load() -> Value? { lock.withLock { value } }
}

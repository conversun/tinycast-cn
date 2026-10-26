import Foundation

@MainActor
@Observable
final class FileSearchSession {
    typealias SearchOperation = @Sendable (String, FileSearchFilter) async -> [FileSearchResult]

    enum State: Equatable {
        case idle
        case searching
        case ready
    }

    private(set) var results: [FileSearchResult] = []
    private(set) var state: State = .idle
    /// The published search: the filter belongs to it, so narrowing re-runs the same words.
    private var request: Request?
    private var revision = 0
    @ObservationIgnored private var pending: (request: Request, revision: Int)?
    @ObservationIgnored private var workerTask: Task<Void, Never>?
    @ObservationIgnored private let searchOperation: SearchOperation
    /// Kept across closes, so the blank screen opens on its rows instead of on nothing.
    @ObservationIgnored private var recent: [FileSearchResult]?
    @ObservationIgnored private var recentStamp = 0

    private struct Request: Equatable {
        static let recent = Request(query: "", filter: .all)

        let query: String
        let filter: FileSearchFilter
    }

    /// No debounce: a search costs milliseconds, and the worker already runs only the newest.
    init(index: FileIndex) {
        searchOperation = { query, filter in
            await Task.detached(priority: .userInitiated) {
                guard let prepared = FileSearchQuery.prepare(query) else {
                    return index.recent(filter: filter)
                }
                return index.search(prepared, filter: filter)
            }.value
        }
    }

    init(searchOperation: @escaping SearchOperation) {
        self.searchOperation = searchOperation
    }

    /// An empty query is a request too: the blank screen lists what changed recently.
    @discardableResult
    func search(_ rawQuery: String, filter: FileSearchFilter = .all) -> Task<Void, Never>? {
        let query = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        let request = Request(query: query, filter: filter)
        guard request != self.request else { return workerTask }
        enqueue(request)
        if request == .recent, let recent {
            results = recent
            state = .ready
        }
        return workerTask
    }

    /// Re-runs the published request; Recent's kept rows follow even behind a typed query.
    @discardableResult
    func refresh() -> Task<Void, Never>? {
        if let request { enqueue(request) }
        if request != .recent { return refreshRecent() }
        return workerTask
    }

    /// Only the kept rows move, so a list on screen never shifts under the pointer.
    @discardableResult
    func refreshRecent() -> Task<Void, Never> {
        Task { [weak self] in
            await self?.run(.recent)
        }
    }

    /// Idle already means no results and nothing that can publish, so it notifies no observer.
    @discardableResult
    func cancel() -> Task<Void, Never>? {
        guard request != nil else { return workerTask }
        revision &+= 1
        pending = nil
        request = nil
        results = []
        state = .idle
        return workerTask
    }

    /// A trashed row names a file that is gone, so it leaves the published results with it.
    func remove(_ result: FileSearchResult) {
        results.removeAll { $0.id == result.id }
        recent?.removeAll { $0.id == result.id }
    }

    private func enqueue(_ request: Request) {
        revision &+= 1
        self.request = request
        state = .searching
        pending = (request, revision)
        guard workerTask == nil else { return }
        workerTask = Task { [weak self] in
            await self?.runWorker()
        }
    }

    private func runWorker() async {
        while let next = pending {
            pending = nil
            let found = await run(next.request)
            guard revision == next.revision, request == next.request else { continue }
            if results != found { results = found }
            state = .ready
        }
        workerTask = nil
    }

    /// Recent's rows are kept whoever asked; stamped, so a late finisher never replaces newer rows.
    @discardableResult
    private func run(_ request: Request) async -> [FileSearchResult] {
        guard request == .recent else { return await searchOperation(request.query, request.filter) }
        recentStamp &+= 1
        let stamp = recentStamp
        let found = await searchOperation(request.query, request.filter)
        if stamp == recentStamp { recent = found }
        return found
    }
}

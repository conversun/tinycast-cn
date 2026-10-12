import Foundation

@MainActor
@Observable
final class DictationModelStore {
    typealias Failure = DictationWire.Failure

    private(set) var downloading: DictationModel?
    private(set) var downloadProgress: (received: Int64, total: Int64)?
    private(set) var removing: DictationModel?
    private(set) var transcribing = false
    private(set) var loadedModel: DictationModel?
    private(set) var installedModels: Set<DictationModel> = []
    @ObservationIgnored private var worker: DictationWorker?
    @ObservationIgnored private var releaseTask: Task<Void, Never>?
    @ObservationIgnored private var idleRelease: DictationIdleRelease
    @ObservationIgnored private var downloadTask: Task<Void, Error>?
    @ObservationIgnored private var downloadID: UUID?
    private let root: URL
    private let makeWorker: () throws -> DictationWorker

    init(
        idleRelease: DictationIdleRelease,
        root: URL = AppPaths.caches().appending(path: "Dictation"),
        makeWorker: @escaping () throws -> DictationWorker = { try DictationWorker() }
    ) {
        self.idleRelease = idleRelease
        self.root = root
        self.makeWorker = makeWorker
        refreshInstalledModels()
    }

    func setIdleRelease(_ option: DictationIdleRelease) {
        idleRelease = option
        if worker != nil, !transcribing {
            scheduleRelease()
        } else {
            releaseTask?.cancel()
            releaseTask = nil
        }
    }

    func isInstalled(_ model: DictationModel) -> Bool {
        installedModels.contains(model)
    }

    func refreshInstalledModels() {
        installedModels = Set(
            DictationModel.allCases.filter { model in
                let directory = directory(for: model)
                return model.requiredFiles.allSatisfy {
                    FileManager.default.fileExists(atPath: directory.appending(path: $0).path)
                }
            })
    }

    func installedSize(_ model: DictationModel) async -> Int64? {
        guard isInstalled(model) else { return nil }
        let directory = directory(for: model)
        let task = Task.detached(priority: .utility) { () -> Int64? in
            guard
                let files = FileManager.default.enumerator(
                    at: directory, includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey])
            else { return nil }
            var size: Int64 = 0
            while let url = files.nextObject() as? URL {
                guard !Task.isCancelled else { return nil }
                guard let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
                    values.isRegularFile == true,
                    let bytes = values.fileSize
                else { continue }
                size += Int64(bytes)
            }
            return size
        }
        return await withTaskCancellationHandler {
            await task.value
        } onCancel: {
            task.cancel()
        }
    }

    func download(_ model: DictationModel) async throws {
        guard downloading == nil, removing != model else { throw Failure.busy }
        guard !isInstalled(model) else { return }
        downloading = model
        let id = UUID()
        downloadID = id
        let destination = directory(for: model)
        let task = Task.detached(priority: .utility) { [weak self] in
            try await DictationModelDownloader.download(model, destination: destination) {
                [weak self] received, total in
                Task { @MainActor [weak self] in
                    guard let self, self.downloadID == id else { return }
                    self.downloadProgress = (max(self.downloadProgress?.received ?? 0, received), total)
                }
            }
        }
        downloadTask = task
        defer { downloading = nil; downloadTask = nil; downloadID = nil; downloadProgress = nil }
        try await withTaskCancellationHandler {
            try await task.value
        } onCancel: {
            task.cancel()
        }
        installedModels.insert(model)
    }

    func cancelDownload() {
        downloadID = nil
        downloadTask?.cancel()
    }

    func delete(_ model: DictationModel) async throws {
        guard !transcribing, removing == nil, downloading != model else { throw Failure.busy }
        removing = model
        defer { removing = nil }
        if loadedModel == model { await release() }
        let directory = directory(for: model)
        try await Task.detached(priority: .utility) {
            if FileManager.default.fileExists(atPath: directory.path) {
                try FileManager.default.removeItem(at: directory)
            }
        }.value
        installedModels.remove(model)
    }

    func transcribe(
        _ samples: [Float], model: DictationModel, language: String? = nil
    ) async throws -> String {
        try Task.checkCancellation()
        guard !transcribing, removing != model else { throw Failure.busy }
        guard isInstalled(model) else { throw Failure.notInstalled }
        releaseTask?.cancel()
        releaseTask = nil
        transcribing = true
        defer { transcribing = false; scheduleRelease() }
        do {
            if loadedModel != model { await release() }
            try Task.checkCancellation()
            let worker = try self.worker ?? makeWorker()
            self.worker = worker
            let request = DictationWire.Request(
                id: UUID(), model: model, directory: directory(for: model),
                sampleCount: samples.count, language: model.isQwen ? language : nil)
            let text = try await worker.transcribe(samples, request: request) { [weak self] in
                guard let self, self.worker === worker, self.transcribing else { return }
                self.loadedModel = model
            }
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            await release()
            throw error
        }
    }

    func release() async {
        releaseTask?.cancel()
        releaseTask = nil
        let worker = self.worker
        self.worker = nil
        loadedModel = nil
        await worker?.stop()
    }

    func stop() async {
        downloadTask?.cancel()
        try? await downloadTask?.value
        await release()
    }

    func prepareForTermination() { downloadTask?.cancel(); worker?.terminate() }

    private func scheduleRelease() {
        releaseTask?.cancel()
        guard worker != nil, idleRelease != .never else { releaseTask = nil; return }
        let interval = Duration.seconds(idleRelease.rawValue * 60)
        releaseTask = Task { [weak self] in
            try? await Task.sleep(for: interval, tolerance: .seconds(1))
            guard !Task.isCancelled else { return }
            guard let self, !self.transcribing else { return }
            await self.release()
        }
    }

    private func directory(for model: DictationModel) -> URL {
        root.appendingPathComponent(model.folderName)
    }
}

import CoreAudio
import Foundation
import OSLog

@MainActor
final class DictationAudioDucker {
    struct Output {
        let deviceUID: String
        let read: () throws -> Float
        let write: (Float) throws -> Void
    }

    private struct Snapshot {
        let output: Output
        var volume: DictationVolumeSnapshot
    }

    private static let logger = Logger(subsystem: "com.tinycast", category: "DictationVolume")
    private let fileURL: URL
    private let defaultOutput: () throws -> Output?
    private let resolveOutput: (String) throws -> Output?
    private var snapshot: Snapshot?
    private var transition: Task<Void, Never>?

    init(
        fileURL: URL = AppPaths.applicationSupport().appending(path: "dictation-volume.json"),
        defaultOutput: @escaping () throws -> Output? = {
            try AudioHardwareSystem.shared.defaultOutputDevice.flatMap {
                try DictationAudioDucker.output(for: $0)
            }
        },
        resolveOutput: @escaping (String) throws -> Output? = { uid in
            try AudioHardwareSystem.shared.device(forUID: uid).flatMap {
                try DictationAudioDucker.output(for: $0)
            }
        }
    ) {
        self.fileURL = fileURL
        self.defaultOutput = defaultOutput
        self.resolveOutput = resolveOutput
    }

    isolated deinit { transition?.cancel() }

    func recover() {
        schedule { _ = try await $0.recoverSavedVolume() }
    }

    func begin() {
        schedule { ducker in
            if ducker.snapshot == nil {
                guard try await ducker.recoverSavedVolume(),
                    let output = try ducker.defaultOutput()
                else { return }
                let original = try output.read()
                let volume = DictationVolumeSnapshot(
                    deviceUID: output.deviceUID, original: original, lastSet: original)
                guard volume.isValid, original > 0 else { return }
                ducker.snapshot = Snapshot(output: output, volume: volume)
            }
            guard let snapshot = ducker.snapshot else { return }
            try await ducker.fade(to: snapshot.volume.original * 0.1, release: false)
        }
    }

    func end() {
        guard snapshot != nil || transition != nil else { return }
        schedule { ducker in
            guard let snapshot = ducker.snapshot else { return }
            try await ducker.fade(to: snapshot.volume.original, release: true)
        }
    }

    func restoreImmediately() {
        transition?.cancel()
        if let snapshot, let current = try? snapshot.output.read(), snapshot.volume.matches(current) {
            do { try snapshot.output.write(snapshot.volume.original) } catch {
                Self.logger.error("Couldn't restore dictation volume: \(error.localizedDescription)")
            }
        }
        snapshot = nil
        recover()
    }

    func waitForTransition() async {
        while let transition { await transition.value }
    }

    private func schedule(_ operation: @escaping @MainActor (DictationAudioDucker) async throws -> Void) {
        let previous = transition
        previous?.cancel()
        transition = Task { [weak self] in
            await previous?.value
            guard !Task.isCancelled, let self else { return }
            do { try await operation(self) } catch is CancellationError {
            } catch {
                Self.logger.error("Couldn't update dictation volume: \(error.localizedDescription)")
                if snapshot != nil { restoreImmediately() }
            }
            if !Task.isCancelled { transition = nil }
        }
    }

    private func fade(to target: Float, release: Bool) async throws {
        guard let snapshot else { return }
        let start = try snapshot.output.read()
        guard snapshot.volume.matches(start) else {
            try await clear()
            return
        }
        for step in 1...16 {
            try Task.checkCancellation()
            guard let snapshot = self.snapshot else { return }
            let volume = start + (target - start) * Float(step) / 16
            var saved = snapshot.volume
            saved.previous = saved.lastSet
            saved.lastSet = volume
            // A crash between persistence and the hardware write must recover either volume.
            try await persist(saved)
            try Task.checkCancellation()
            guard snapshot.volume.matches(try snapshot.output.read()) else {
                try await clear()
                return
            }
            try snapshot.output.write(volume)
            self.snapshot?.volume.lastSet = try snapshot.output.read()
            self.snapshot?.volume.previous = nil
            if step < 16 { try await Task.sleep(for: .milliseconds(30)) }
        }
        if release { try await clear() }
    }

    private func recoverSavedVolume() async throws -> Bool {
        let fileURL = fileURL
        let volume = try await Task.detached(priority: .utility) { () -> DictationVolumeSnapshot? in
            do {
                return try JSONDecoder().decode(DictationVolumeSnapshot.self, from: Data(contentsOf: fileURL))
            } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
                return nil
            }
        }.value
        try Task.checkCancellation()
        guard let volume else { return true }
        guard volume.isValid else { try await persist(nil); return true }
        guard let output = try resolveOutput(volume.deviceUID) else { return false }
        let current = try output.read()
        if volume.matches(current), current != volume.original { try output.write(volume.original) }
        try await persist(nil)
        return true
    }

    private func clear() async throws {
        snapshot = nil
        try await persist(nil)
    }

    private func persist(_ volume: DictationVolumeSnapshot?) async throws {
        let fileURL = fileURL
        try await Task.detached(priority: .utility) {
            if let volume {
                try FileManager.default.createDirectory(
                    at: fileURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true)
                try JSONEncoder().encode(volume).write(to: fileURL, options: .atomic)
            } else {
                do { try FileManager.default.removeItem(at: fileURL) } catch let error as CocoaError
                    where error.code == .fileNoSuchFile
                {}
            }
        }.value
    }

    private static func output(for device: AudioHardwareDevice) throws -> Output? {
        guard let control = try device.controls.first(where: isMainOutputVolume) else { return nil }
        return Output(
            deviceUID: try device.uid,
            read: { try control.volumeScalarValue }, write: { try control.setVolumeScalarValue($0) })
    }

    private static func isMainOutputVolume(_ control: AudioHardwareControl) -> Bool {
        guard (try? control.classID) == kAudioVolumeControlClassID else { return false }
        func value(for selector: AudioObjectPropertySelector) -> UInt32? {
            let address = AudioObjectPropertyAddress(
                mSelector: selector, mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain)
            guard let data = try? control.propertyData(address: address, qualifier: nil),
                data.count == MemoryLayout<UInt32>.size
            else { return nil }
            return data.withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) }
        }
        return value(for: kAudioControlPropertyScope) == kAudioObjectPropertyScopeOutput
            && value(for: kAudioControlPropertyElement) == kAudioObjectPropertyElementMain
    }
}

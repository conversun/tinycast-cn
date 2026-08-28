import Foundation

/// Runs one macOS command-line tool to completion. Output is drained as it arrives rather than at
/// exit, so a tool that writes more than a pipe buffer holds cannot wedge waiting for a reader.
enum ToolRunner {
    struct Result: Sendable {
        let status: Int32
        let output: String

        var succeeded: Bool { status == 0 }

        /// The tail, which is where a tool puts the actual error.
        var tail: String {
            let lines = output.split(separator: "\n").suffix(8)
            let text = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? "no output" : text
        }
    }

    static func run(
        _ executable: URL, _ arguments: [String], timeout: TimeInterval = 120
    ) async throws -> Result {
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        let collector = OutputCollector()
        pipe.fileHandleForReading.readabilityHandler = { collector.absorb($0.availableData) }

        return try await withCheckedThrowingContinuation { continuation in
            process.terminationHandler = { finished in
                pipe.fileHandleForReading.readabilityHandler = nil
                collector.absorb((try? pipe.fileHandleForReading.readToEnd()) ?? Data())
                continuation.resume(
                    returning: Result(status: finished.terminationStatus, output: collector.text))
            }
            do {
                try process.run()
            } catch {
                // The handler never fires for a process that never started, so resume here instead.
                pipe.fileHandleForReading.readabilityHandler = nil
                process.terminationHandler = nil
                continuation.resume(throwing: error)
                return
            }
            Task {
                try? await Task.sleep(for: .seconds(timeout))
                guard process.isRunning else { return }
                process.terminate()
            }
        }
    }
}

/// Output arrives on the pipe's own queue and is read again from the termination handler, so the
/// lock is load-bearing; nothing outside this type touches the buffer.
private final class OutputCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var buffer = Data()

    var text: String {
        lock.lock()
        defer { lock.unlock() }
        // Latin-1 cannot fail, so output a tool wrote in some other encoding still reaches the user.
        return String(bytes: buffer, encoding: .utf8)
            ?? String(bytes: buffer, encoding: .isoLatin1) ?? ""
    }

    /// Buffers bytes, not text: a read can land mid-character, and decoding the halves separately
    /// would put a replacement character into the middle of a word.
    func absorb(_ data: Data) {
        guard !data.isEmpty else { return }
        lock.lock()
        buffer.append(data)
        lock.unlock()
    }
}

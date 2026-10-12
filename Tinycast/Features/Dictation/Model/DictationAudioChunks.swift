import Foundation

enum DictationAudioChunks {
    static func ranges(in samples: [Float], maximum: Int) -> [Range<Int>] {
        precondition(maximum > 0)
        var ranges = [Range<Int>]()
        var start = 0
        while start < samples.count {
            var end = min(start + maximum, samples.count)
            if end < samples.count, end - start >= 3200 {
                let window = 3200
                var quietest: Float = .infinity
                for offset in stride(from: max(start, end - 48_000), through: end - window, by: 160) {
                    let energy = samples[offset..<(offset + window)].reduce(Float.zero) { $0 + $1 * $1 }
                    if energy <= quietest { quietest = energy; end = offset + window / 2 }
                }
            }
            ranges.append(start..<end)
            start = end
        }
        return ranges
    }
}

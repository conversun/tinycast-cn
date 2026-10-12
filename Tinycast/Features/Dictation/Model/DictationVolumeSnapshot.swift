import Foundation

struct DictationVolumeSnapshot: Codable, Sendable {
    let deviceUID: String
    let original: Float
    var lastSet: Float
    var previous: Float?

    var isValid: Bool {
        !deviceUID.isEmpty && (0...1).contains(original) && (0...1).contains(lastSet)
            && previous.map { (0...1).contains($0) } != false
    }

    func matches(_ volume: Float) -> Bool {
        isValid
            && (abs(volume - lastSet) < 0.01
                || previous.map { abs(volume - $0) < 0.01 } == true)
    }
}

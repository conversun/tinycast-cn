import Accelerate
import Foundation

final class DictationMel {
    private let transform: vDSP.DiscreteFourierTransform<Float>
    private let window: [Float]
    private let filters: [Float]
    private let rotations: [(real: Float, imaginary: Float)]
    static let lengths = [100, 200, 400, 600, 800, 1000, 1500, 2000, 3000]

    init() throws {
        // Accelerate supports 80-point transforms, but not the 400-point Whisper window.
        transform = try vDSP.DiscreteFourierTransform(
            count: 80, direction: .forward,
            transformType: .complexComplex, ofType: Float.self)
        window = (0..<400).map { 0.5 - 0.5 * cos(2 * .pi * Float($0) / 400) }
        rotations = (0..<5).flatMap { residue in
            (0..<201).map { bin in
                let angle = -2 * Float.pi * Float(bin * residue) / 400
                return (cos(angle), sin(angle))
            }
        }
        func mel(_ hz: Float) -> Float {
            hz < 1000 ? hz / (200 / 3) : 15 + log(hz / 1000) / (log(6.4) / 27)
        }
        func hz(_ mel: Float) -> Float {
            mel < 15 ? mel * (200 / 3) : 1000 * exp((mel - 15) * (log(6.4) / 27))
        }
        let edges = (0..<130).map { hz(Float($0) * mel(8000) / 129) }
        filters = (0..<128).flatMap { band in
            (0..<201).map { bin -> Float in
                let frequency = Float(bin) * 40
                let rising = (frequency - edges[band]) / (edges[band + 1] - edges[band])
                let falling = (edges[band + 2] - frequency) / (edges[band + 2] - edges[band + 1])
                return max(0, min(rising, falling)) * 2 / (edges[band + 2] - edges[band])
            }
        }
    }

    func features(_ samples: ArraySlice<Float>) throws -> (values: [Float], frames: Int, length: Int) {
        let frames = samples.count / 160
        guard frames > 0, let length = Self.lengths.first(where: { $0 >= frames }) else {
            throw DictationInferenceError.invalidAudio
        }
        var powers = [Float](repeating: 0, count: 201 * length)
        var real = [Float](repeating: 0, count: 80)
        let imaginary = [Float](repeating: 0, count: 80)
        var outputReal = imaginary
        var outputImaginary = imaginary
        var spectrumReal = [Float](repeating: 0, count: 201)
        var spectrumImaginary = spectrumReal
        let activeFrames = min(length, (samples.count + window.count / 2 - 1) / 160 + 1)
        for frame in 0..<activeFrames {
            for bin in 0..<201 { spectrumReal[bin] = 0; spectrumImaginary[bin] = 0 }
            for residue in 0..<5 {
                for index in 0..<80 {
                    let windowIndex = index * 5 + residue
                    let position = abs(frame * 160 + windowIndex - 200)
                    real[index] =
                        position < samples.count
                        ? samples[samples.startIndex + position] * window[windowIndex] : 0
                }
                transform.transform(
                    inputReal: real, inputImaginary: imaginary,
                    outputReal: &outputReal, outputImaginary: &outputImaginary)
                for bin in 0..<201 {
                    let rotation = rotations[residue * 201 + bin]
                    let index = bin % 80
                    spectrumReal[bin] +=
                        outputReal[index] * rotation.real - outputImaginary[index] * rotation.imaginary
                    spectrumImaginary[bin] +=
                        outputImaginary[index] * rotation.real + outputReal[index] * rotation.imaginary
                }
            }
            for bin in 0..<201 {
                powers[bin * length + frame] =
                    spectrumReal[bin] * spectrumReal[bin]
                    + spectrumImaginary[bin] * spectrumImaginary[bin]
            }
        }
        var values = [Float](repeating: 0, count: 128 * length)
        vDSP_mmul(filters, 1, powers, 1, &values, 1, 128, vDSP_Length(length), 201)
        var maximum: Float = -.infinity
        for index in values.indices {
            values[index] = log10(max(1e-10, values[index]))
            maximum = max(maximum, values[index])
        }
        for index in values.indices { values[index] = (max(maximum - 8, values[index]) + 4) / 4 }
        return (values, frames, length)
    }

    static func embeddingCount(frames: Int) -> Int { frames / 100 * 13 + (frames % 100 + 7) / 8 }
}

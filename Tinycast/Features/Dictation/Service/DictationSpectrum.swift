import Accelerate
import Foundation

final class DictationSpectrum {
    static let barCount = 21
    private static let sampleCount = 512
    private let transform: vDSP.DiscreteFourierTransform<Float>
    private let window: [Float]
    private let bands: [Range<Int>]
    private var real = [Float](repeating: 0, count: sampleCount)
    private let imaginary = [Float](repeating: 0, count: sampleCount)
    private var outputReal = [Float](repeating: 0, count: sampleCount)
    private var outputImaginary = [Float](repeating: 0, count: sampleCount)

    init() throws {
        transform = try vDSP.DiscreteFourierTransform(
            count: Self.sampleCount, direction: .forward,
            transformType: .complexComplex, ofType: Float.self)
        window = (0..<Self.sampleCount).map {
            0.5 - 0.5 * cos(2 * .pi * Float($0) / Float(Self.sampleCount - 1))
        }
        let edges = (0...Self.barCount).map {
            Int(32 * pow(5000.0 / 32, Double($0) / Double(Self.barCount)) * Double(Self.sampleCount) / 16_000)
        }
        bands = (0..<Self.barCount).map { edges[$0]..<max(edges[$0] + 1, edges[$0 + 1]) }
    }

    func levels(for samples: ArraySlice<Float>) -> [Float] {
        let recent = samples.suffix(Self.sampleCount)
        for index in real.indices {
            real[index] = index < recent.count ? recent[recent.startIndex + index] * window[index] : 0
        }
        transform.transform(
            inputReal: real, inputImaginary: imaginary,
            outputReal: &outputReal, outputImaginary: &outputImaginary)
        return bands.map { band in
            let energy = band.reduce(Float(0)) {
                $0 + outputReal[$1] * outputReal[$1] + outputImaginary[$1] * outputImaginary[$1]
            }
            let amplitude = sqrt(energy) / Float(Self.sampleCount)
            let level = max(0, (sqrt(amplitude) - 0.025) * 15)
            return level / sqrt(1 + level * level)
        }
    }
}

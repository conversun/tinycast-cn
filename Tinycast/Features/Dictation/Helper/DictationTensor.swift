import Accelerate
import CoreML
import Foundation

enum DictationInferenceError: Error {
    case incompatibleModel, invalidAudio, outputLimit, parentExited
}

enum DictationTensor {
    static func zeros(_ shape: [Int], type: MLMultiArrayDataType = .float32) throws -> MLMultiArray {
        let array = try MLMultiArray(shape: shape.map { NSNumber(value: $0) }, dataType: type)
        array.withUnsafeMutableBytes { bytes, _ in
            _ = bytes.initializeMemory(as: UInt8.self, repeating: 0)
        }
        return array
    }

    static func integer(_ value: Int, shape: [Int] = [1]) throws -> MLMultiArray {
        let array = try zeros(shape, type: .int32)
        array[0] = NSNumber(value: value)
        return array
    }

    static func predict(_ model: MLModel, _ inputs: [String: MLMultiArray]) throws -> MLFeatureProvider {
        try checkParent()
        return try model.prediction(from: MLDictionaryFeatureProvider(dictionary: inputs))
    }

    static func array(_ name: String, from features: MLFeatureProvider) throws -> MLMultiArray {
        guard let array = features.featureValue(for: name)?.multiArrayValue else {
            throw DictationInferenceError.incompatibleModel
        }
        return array
    }

    static func indexOfMaximum(in scores: MLMultiArray) throws -> Int {
        guard scores.count > 0, scores.dataType == .float16,
            scores.shape.last?.intValue == scores.count, scores.strides.last?.intValue == 1
        else {
            throw DictationInferenceError.incompatibleModel
        }
        let values = try [Float](unsafeUninitializedCapacity: scores.count) { values, initialized in
            try scores.withUnsafeBytes { bytes in
                var source = vImage_Buffer(
                    data: UnsafeMutableRawPointer(mutating: bytes.baseAddress!),
                    height: 1, width: vImagePixelCount(scores.count), rowBytes: scores.count * 2)
                var destination = vImage_Buffer(
                    data: values.baseAddress!,
                    height: 1, width: vImagePixelCount(scores.count), rowBytes: scores.count * 4)
                let status = vImageConvert_Planar16FtoPlanarF(
                    &source, &destination, vImage_Flags(kvImageDoNotTile))
                guard status == kvImageNoError else {
                    throw DictationInferenceError.incompatibleModel
                }
            }
            initialized = scores.count
        }
        return Int(vDSP.indexOfMaximum(values).0)
    }

    static func load(_ name: String, at directory: URL, units: MLComputeUnits = .all) throws -> MLModel {
        let configuration = MLModelConfiguration()
        configuration.computeUnits = units
        return try MLModel(
            contentsOf: directory.appendingPathComponent(name + ".mlmodelc"),
            configuration: configuration)
    }

    static func checkParent() throws {
        guard getppid() != 1 else { throw DictationInferenceError.parentExited }
    }
}

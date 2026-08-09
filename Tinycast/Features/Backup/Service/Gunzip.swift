import Compression
import Foundation

enum GunzipError: Error { case notGzip, corrupt }

/// Gzip (RFC 1952); `Compression` speaks raw DEFLATE, so the wrapper is parsed here.
enum Gunzip {
    // Cap inflated output: the outer envelope inflates before any authentication.
    static let defaultMaxOutput = 64 * 1024 * 1024

    static func decompress(_ data: Data, maxOutput: Int = defaultMaxOutput) throws -> Data {
        let bytes = [UInt8](data)
        // Magic (1f 8b) + deflate method (08) + the 10-byte fixed header and 8-byte trailer.
        guard bytes.count >= 18, bytes[0] == 0x1f, bytes[1] == 0x8b, bytes[2] == 0x08 else {
            throw GunzipError.notGzip
        }
        let flags = bytes[3]
        var index = 10
        if flags & 0x04 != 0 {  // FEXTRA: 2-byte length + payload
            guard index + 2 <= bytes.count else { throw GunzipError.corrupt }
            index += 2 + (Int(bytes[index]) | Int(bytes[index + 1]) << 8)
        }
        if flags & 0x08 != 0 { index = try skipCString(bytes, from: index) }  // FNAME
        if flags & 0x10 != 0 { index = try skipCString(bytes, from: index) }  // FCOMMENT
        if flags & 0x02 != 0 { index += 2 }  // FHCRC
        guard index < bytes.count - 8 else { throw GunzipError.corrupt }
        // Slice `bytes`, not `data`: `data` may be a slice whose indices start elsewhere.
        return try rawInflate(Data(bytes[index..<(bytes.count - 8)]), maxOutput: maxOutput)
    }

    private static func skipCString(_ bytes: [UInt8], from start: Int) throws -> Int {
        var i = start
        while i < bytes.count {
            if bytes[i] == 0 { return i + 1 }
            i += 1
        }
        throw GunzipError.corrupt
    }

    private static func rawInflate(_ deflate: Data, maxOutput: Int) throws -> Data {
        let bufferSize = 256 * 1024
        let dst = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { dst.deallocate() }

        // The C struct has no zero-arg init; the placeholders are overwritten first.
        var stream = compression_stream(
            dst_ptr: dst, dst_size: bufferSize, src_ptr: dst, src_size: 0, state: nil)
        guard
            compression_stream_init(&stream, COMPRESSION_STREAM_DECODE, COMPRESSION_ZLIB)
                != COMPRESSION_STATUS_ERROR
        else { throw GunzipError.corrupt }
        defer { compression_stream_destroy(&stream) }

        let output: Data? = deflate.withUnsafeBytes { raw in
            guard let base = raw.bindMemory(to: UInt8.self).baseAddress else { return Data() }
            stream.src_ptr = base
            stream.src_size = raw.count
            var out = Data()
            while true {
                stream.dst_ptr = dst
                stream.dst_size = bufferSize
                let status = compression_stream_process(
                    &stream, Int32(COMPRESSION_STREAM_FINALIZE.rawValue))
                switch status {
                case COMPRESSION_STATUS_OK, COMPRESSION_STATUS_END:
                    out.append(dst, count: bufferSize - stream.dst_size)
                    if out.count > maxOutput { return nil }
                    if status == COMPRESSION_STATUS_END { return out }
                default:
                    return nil
                }
            }
        }
        guard let output else { throw GunzipError.corrupt }
        return output
    }
}

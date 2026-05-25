import Foundation
import Compression

enum CompressionError: Error, LocalizedError {
    case compressionFailed
    case decompressionFailed
    case invalidData

    var errorDescription: String? {
        switch self {
        case .compressionFailed: return "Failed to compress data"
        case .decompressionFailed: return "Failed to decompress data"
        case .invalidData: return "Invalid compressed data"
        }
    }
}

enum DataCompression {
    static func compress(_ data: Data) throws -> Data {
        guard !data.isEmpty else { return Data() }

        let destinationBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: data.count)
        defer { destinationBuffer.deallocate() }

        let compressedSize = data.withUnsafeBytes { sourceBuffer -> Int in
            compression_encode_buffer(
                destinationBuffer, data.count,
                sourceBuffer.baseAddress!.assumingMemoryBound(to: UInt8.self), data.count,
                nil,
                COMPRESSION_LZFSE
            )
        }

        guard compressedSize > 0 else {
            return data
        }

        if compressedSize >= data.count {
            return data
        }

        return Data(bytes: destinationBuffer, count: compressedSize)
    }

    static func decompress(_ data: Data, originalSize: Int) throws -> Data {
        guard !data.isEmpty else { return Data() }
        if originalSize == data.count {
            return data
        }

        let destinationBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: originalSize)
        defer { destinationBuffer.deallocate() }

        let decompressedSize = data.withUnsafeBytes { sourceBuffer -> Int in
            compression_decode_buffer(
                destinationBuffer, originalSize,
                sourceBuffer.baseAddress!.assumingMemoryBound(to: UInt8.self), data.count,
                nil,
                COMPRESSION_LZFSE
            )
        }

        guard decompressedSize > 0 else {
            throw CompressionError.decompressionFailed
        }

        return Data(bytes: destinationBuffer, count: decompressedSize)
    }

    static func compressFile(at url: URL) throws -> (data: Data, size: Int64) {
        print("Compression: Reading file at \(url.path)")
        let fileData = try Data(contentsOf: url)
        print("Compression: File size is \(fileData.count) bytes")
        let compressed = try compress(fileData)
        print("Compression: Compressed size is \(compressed.count) bytes")
        return (compressed, Int64(fileData.count))
    }

    static func decompressToFile(data: Data, originalSize: Int64, to url: URL) throws {
        let decompressed = try decompress(data, originalSize: Int(originalSize))
        try decompressed.write(to: url)
    }
}

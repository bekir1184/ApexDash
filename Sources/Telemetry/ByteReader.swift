import Foundation

/// Reads little-endian binary packets field by field. Game packets are
/// "packed", so fields are read one by one instead of relying on struct layout.
struct ByteReader {
    private let data: Data
    private(set) var offset: Int

    init(_ data: Data, offset: Int = 0) {
        self.data = data
        self.offset = offset
    }

    var remaining: Int { data.count - offset }

    mutating func seek(to newOffset: Int) { offset = newOffset }
    mutating func skip(_ count: Int) { offset += count }

    private mutating func next(_ count: Int) -> Data? {
        guard remaining >= count else { return nil }
        let start = data.startIndex + offset
        let slice = data[start ..< start + count]
        offset += count
        return slice
    }

    mutating func uint8() -> UInt8? { next(1)?.first }

    mutating func int8() -> Int8? {
        guard let raw = uint8() else { return nil }
        return Int8(bitPattern: raw)
    }

    mutating func uint16() -> UInt16? {
        guard let bytes = next(2) else { return nil }
        var value: UInt16 = 0
        for (i, byte) in bytes.enumerated() { value |= UInt16(byte) << (8 * UInt16(i)) }
        return value
    }

    mutating func uint32() -> UInt32? {
        guard let bytes = next(4) else { return nil }
        return Self.littleEndian(bytes)
    }

    mutating func int16() -> Int16? {
        uint16().map { Int16(bitPattern: $0) }
    }

    mutating func int32() -> Int32? {
        uint32().map { Int32(bitPattern: $0) }
    }

    mutating func uint64() -> UInt64? {
        guard let bytes = next(8) else { return nil }
        var value: UInt64 = 0
        for (i, byte) in bytes.enumerated() { value |= UInt64(byte) << (8 * UInt64(i)) }
        return value
    }

    mutating func float() -> Float? {
        guard let bits: UInt32 = uint32() else { return nil }
        return Float(bitPattern: bits)
    }

    private static func littleEndian(_ bytes: Data) -> UInt32 {
        var value: UInt32 = 0
        for (i, byte) in bytes.enumerated() { value |= UInt32(byte) << (8 * UInt32(i)) }
        return value
    }
}

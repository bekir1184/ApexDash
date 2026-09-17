import Foundation

/// Builds little-endian binary packets field by field. The counterpart of
/// `ByteReader`, used by demo drives to produce the same bytes a game sends.
struct ByteWriter {
    private(set) var data = Data()

    mutating func uint8(_ value: UInt8) { data.append(value) }
    mutating func int8(_ value: Int8) { data.append(UInt8(bitPattern: value)) }
    mutating func uint16(_ value: UInt16) { append(value.littleEndian) }
    mutating func int16(_ value: Int16) { append(value.littleEndian) }
    mutating func uint32(_ value: UInt32) { append(value.littleEndian) }
    mutating func uint64(_ value: UInt64) { append(value.littleEndian) }
    mutating func float(_ value: Float) { append(value.bitPattern.littleEndian) }

    /// Appends `count` zero bytes.
    mutating func zeros(_ count: Int) { data.append(contentsOf: repeatElement(0, count: max(count, 0))) }

    /// Appends a string in a fixed-size, zero padded field.
    mutating func string(_ value: String, size: Int) {
        let bytes = Array(value.utf8.prefix(size - 1))
        data.append(contentsOf: bytes)
        zeros(size - bytes.count)
    }

    /// Pads with zeros until the packet is `size` bytes long.
    mutating func pad(to size: Int) { zeros(size - data.count) }

    private mutating func append<T: FixedWidthInteger>(_ value: T) {
        withUnsafeBytes(of: value) { data.append(contentsOf: $0) }
    }
}

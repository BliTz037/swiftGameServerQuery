//
//  Data+ext.swift
//  UDPClient
//
//  Created by Tom on 18/07/2025.
//

import Foundation

extension Data {
    var hexDescription: String {
        return reduce("") {$0 + String(format: "%02x", $1) + " "}
    }
    
    mutating func getUInt8() -> UInt8 {
        return removeFirst()
    }
    
    mutating func getString() -> String {
        var temp: Data = Data()
        
        while self.first != 0x00 {
            temp.append(removeFirst())
        }
        removeFirst()
        return String(data: temp, encoding: .utf8) ?? ""
    }
    
    mutating func getUInt16() -> UInt16 {
        let lower: UInt16 = UInt16(removeFirst())
        let upper: UInt16 = UInt16(removeFirst()) << 8
        return lower | upper
    }
    
    mutating func getUInt32LittleEndian() -> UInt32 {
        let b1: UInt32 = UInt32(removeFirst())
        let b2: UInt32 = UInt32(removeFirst()) << 8
        let b3: UInt32 = UInt32(removeFirst()) << 16
        let b4: UInt32 = UInt32(removeFirst()) << 24
        
        return b1 | b2 | b3 | b4
    }
    
    mutating func getUInt32BigEndian() -> UInt32 {
        let b1: UInt32 = UInt32(removeFirst()) << 24
        let b2: UInt32 = UInt32(removeFirst()) << 16
        let b3: UInt32 = UInt32(removeFirst()) << 8
        let b4: UInt32 = UInt32(removeFirst())
        return b1 | b2 | b3 | b4
    }

    mutating func getFloat32() -> Float? {
        guard count >= 4 else { return nil }
        let tmp: Data = prefix(4)
        removeFirst(4)
        return tmp.withUnsafeBytes { rawBuffer in
            guard let baseAddress = rawBuffer.baseAddress else { return nil }
            let bitPattern = baseAddress.assumingMemoryBound(to: UInt32.self).pointee
            return Float(bitPattern: UInt32(littleEndian: bitPattern))
        }
    }
    
    mutating func getUInt64LittleEndian() -> UInt64 {
        let lower: UInt64 = UInt64(getUInt32LittleEndian())
        let upper: UInt64 = UInt64(getUInt32LittleEndian()) << 32

        return lower | upper
    }
    
    mutating func getUInt64BigEndian() -> UInt64 {
        let lower: UInt64 = UInt64(getUInt32BigEndian()) << 32
        let upper: UInt64 = UInt64(getUInt32BigEndian())

        return lower | upper
    }
    
    mutating func getChar() -> Character {
        return Character(UnicodeScalar(getUInt8()))
    }
    
    mutating func getBoolean() -> Bool {
        return getUInt8() == 0x01
    }
    
    // VarInt
    
    mutating func appendVarInt(_ value: Int) {
        var val = value
        
        while val != 0 {
            var temp = UInt8(val & 0x7F)
            val >>= 7
            if val != 0 {
                temp |= 0x80
            }
            append(temp)
        }
    }
    
    mutating func appendStringVarInt(_ value: String) {
        let utf8Data = value.utf8

        appendVarInt(utf8Data.count)
        append(contentsOf: utf8Data)
    }
    
    func appendingPacket(with payload: Data) -> Data {
        var result = Data()

        result.appendVarInt(payload.count)
        result.append(payload)
        return result
    }

    func readVarInt(from offset: inout Int) -> Int {
        var result = 0
        var shift = 0

        while true {
            let byte = self[offset]
            offset += 1
            result |= Int(byte & 0x7F) << shift
            if byte & 0x80 == 0 { break }
            shift += 7
        }
        return result
    }
    
    func peekVarInt(from offset: inout Int) -> Int? {
        var result = 0
        var shift = 0
        var localOffset = offset

        while localOffset < count {
            let byte = self[localOffset]
            result |= Int(byte & 0x7F) << shift
            shift += 7
            localOffset += 1

            if byte & 0x80 == 0 {
                offset = localOffset
                return result
            }

            if shift > 35 {
                return nil
            }
        }

        return nil
    }
    
    func extractJSONFromStatusPacket() -> String? {
        var offset = 0

        _ = readVarInt(from: &offset)  // packet length
        _ = readVarInt(from: &offset)  // packet ID

        let jsonLength = readVarInt(from: &offset)
        guard offset + jsonLength <= count else { return nil }

        let jsonData = self.subdata(in: offset..<(offset + jsonLength))
        return String(data: jsonData, encoding: .utf8)
    }
}

//
//  TCPClient.swift
//  UDPClient
//
//  Created by Tom on 25/07/2025.
//

import Foundation
import Network

protocol TCPClient {
    func start()
    func stop()
    func send()
    func receive()
}

final class TCPClientImpl: @unchecked Sendable {
    private let connection: NWConnection
    private let address: String
    private let port: UInt16
    private var receiveBuffer = Data()
    private var bufferSize: Int = 0
    
    private var sentPingTimestamp: UInt64?
    
    var onStatusReceived: ((String) -> Void)?
    var onPingRTT: ((UInt64) -> Void)?
    
    init(host: String, port: UInt16) {
        self.address = host
        self.port = port
        self.connection = NWConnection(
            host: NWEndpoint.Host(host),
            port: NWEndpoint.Port(integerLiteral: port),
            using: .tcp
        )
    }
}

extension TCPClientImpl: TCPClient {
    func start() {
        connection.stateUpdateHandler = { [weak self] state in
            print("Client state: \(state)")
            if state == .ready {
                self?.send()
                //self?.receive()
            }
        }
        connection.start(queue: .global())
        print("Client Started")
    }

    func stop() {
        connection.cancel()
        print("Client Stopped")
    }

    func send() {
        let handshakeData = self._formatHandshake()
        connection.send(
            content: handshakeData,
            completion: .contentProcessed { error in
                print("GO")
                self.connection.send(
                    content: Data([0x01, 0x00]),
                    completion: .contentProcessed { _ in
                        print("GO 2")
                        self.receive()
                    }
                )
            }
        )
    }

    
    func receive() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { data, _, isComplete, error in
            if let error = error {
                print("Receive error: \(error)")
                return
            }

            guard let data = data else {
                print("No data received.")
                return
            }

            print("📥 Received \(data.count) bytes")
            print(data.hexDescription)

            self.receiveBuffer.append(data)

            // Handle JSON packet
            if self.sentPingTimestamp == nil {
                if self.bufferSize == 0 {
                    var offset: Int = 0
                    let _ = self.receiveBuffer.readVarInt(from: &offset)
                    let _ = self.receiveBuffer.readVarInt(from: &offset)
                    let jsonLength = self.receiveBuffer.readVarInt(from: &offset)
                    self.bufferSize = jsonLength
                    self.receiveBuffer.removeFirst(offset)
                    print("Size is \(self.bufferSize) / offset is \(offset)")
                } else if self.receiveBuffer.count >= self.bufferSize {
                    let jsonData = self.receiveBuffer.prefix(self.bufferSize)
                    if let jsonStr = String(data: jsonData, encoding: .utf8) {
                        print("✅ JSON Response: \n\(jsonStr)")
                        self.onStatusReceived?(jsonStr)
                    }
                    
                    // Send Ping
                    let time = UInt64(Date().timeIntervalSince1970 * 1000)
                    self.sentPingTimestamp = time
                    var ping = Data()
                    ping.append(0x01)
                    ping.append(contentsOf: withUnsafeBytes(of: time.bigEndian, Array.init))
                    let finalPing = Data().appendingPacket(with: ping)
                    
                    self.connection.send(content: finalPing, completion: .contentProcessed { _ in
                        print("📤 Ping sent with timestamp \(time)")
                    })
                    
                    self.receiveBuffer.removeAll()
                    self.bufferSize = 0
                }
            }

            // Handle Pong
            if self.receiveBuffer.count == 10 {
                var offset: Int = 0
                let _ = self.receiveBuffer.readVarInt(from: &offset) // Packet Length
                let _ = self.receiveBuffer.readVarInt(from: &offset) // Packet ID
                self.receiveBuffer.removeFirst(offset)
                print(self.receiveBuffer.getUInt64BigEndian())

                if let sent = self.sentPingTimestamp {
                    let now = UInt64(Date().timeIntervalSince1970 * 1000)
                    let rtt = now - sent
                    print("⏱️ Ping RTT: \(rtt) ms")
                    self.onPingRTT?(rtt)
                }

                self.stop()
                return
            }

            self.receive()
        }
    }

    private func _formatHandshake() -> Data {
        let protocolVersion: Int = 772
        let nextState: Int = 1

        var data: Data = Data()

        data.append(0x00)
        data.appendVarInt(protocolVersion)
        data.appendStringVarInt(self.address)
        data.append(UInt8(port >> 8))
        data.append(UInt8(port & 0xFF))
        data.appendVarInt(nextState)

        return Data().appendingPacket(with: data)
    }
}

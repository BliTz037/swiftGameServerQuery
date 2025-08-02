//
//  UDPClient.swift
//  UDPClient
//
//  Created by Tom on 17/07/2025.
//

import Foundation
import Network

enum QueryRequestType {
    case A2S_INFO
    case A2S_PLAYER
    case A2S_RULES
    
    case MC_UNCONNECTED_PING
}

// Each instance is isolated to a single Task and not shared between threads.
// Safe to mark @unchecked Sendable.
final class UDPClient: @unchecked Sendable {
    private let connection: NWConnection
    private var fragments: [UInt8: Data] = [:]
    private var sentTimestamp: UInt64?
    public var messageType: QueryRequestType
    
    init(
        host: String,
        port: UInt16,
        messageType: QueryRequestType
    ) {
        self.messageType = messageType
        connection = NWConnection(
            host: NWEndpoint.Host(host),
            port: NWEndpoint.Port(integerLiteral: port),
            using: .udp
        )
    }
    
    func start() {
        connection.stateUpdateHandler = { [weak self] state in
            print("Client state: \(state)")
            if state == .ready {
                self?.send()
                self?.receive()
            }
        }
        connection.start(queue: .global())
        print("Client Started")
    }

    func stop() {
        connection.cancel()
        print("Client Stopped")
    }

    func send(challenge: Data? = nil) {
        let packet: Data = self._formatPacket(
            type: messageType,
            challenge: challenge
        )
        print("Message to send: \(packet.hexDescription)")
        self.sentTimestamp = UInt64(Date().timeIntervalSince1970 * 1000)
        connection.send(
            content: packet,
            completion: .contentProcessed { error in
                if let error = error {
                    print("Error client during sending message: \(error)")
                } else {
                    print("Message sent successfully")
                }
            }
        )
    }

    func receive() {
        print("Wait for message...")
        connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) {
            data,
            _,
            isComplete,
            error in
            if let data = data {
                print("isComplete: \(isComplete)")
                self.handleReceivedData(data)
            } else if let error = error {
                print("Error receiving: \(error)")
            }

            if !isComplete {
                self.receive()
            }
        }
    }

    private func handleReceivedData(_ data: Data) {
        let (result, retry) = self.process(data: data)

        if retry {
            if case let .challenge(challengeData) = result {
                print("Retrying with challenge...")
                self.send(challenge: challengeData)
                self.receive()
            }
            return
        }
        
        if let sent = self.sentTimestamp {
            let now = UInt64(Date().timeIntervalSince1970 * 1000)
            let rtt = now - sent
            print("⏱️ UDP Ping RTT: \(rtt) ms")
        }

        switch result {
        case .info(let info):
            print("Info received: \(info)")
            break
        case .player(let player):
            print("Players online: \(player.players.count)")
            for player in player.players {
                print("'\(player.name)' | \(player.score) | \(player.duration)")
            }
            break
        case .rules(let rules):
            print("Rules: \(rules.rulesLength)")
            for rule in rules.rules {
                print("'\(rule.name)': \(rule.value)")
            }
            break
        case .challenge:
            preconditionFailure("Should not happen")
        case .mcUnconnectedPong(let info):
            print("MC Data: \(info)")
            break
        default:
            print("Nothings received...")
        }
    }

    private func _formatPacket(type: QueryRequestType, challenge: Data? = nil)
        -> Data
    {
        var packet: Data = Data([0xFF, 0xFF, 0xFF, 0xFF])

        switch type {
        case .A2S_INFO:
            packet.append(0x54)
            packet.append("Source Engine Query".data(using: .utf8)!)
            packet.append(0x00)
            packet.append(contentsOf: challenge ?? Data([]))
            break
        case .A2S_PLAYER:
            packet.append(0x55)
            packet.append(
                contentsOf: challenge ?? Data([0xFF, 0xFF, 0xFF, 0xFF])
            )
            break
        case .A2S_RULES:
            packet.append(0x56)
            packet.append(
                contentsOf: challenge ?? Data([0xFF, 0xFF, 0xFF, 0xFF])
            )
            break
        // MC
        case .MC_UNCONNECTED_PING:
            var clientAliveTime: UInt64 = 5000
            let magic: Data = Data([0x00, 0xFF, 0xFF, 0x00, 0xFE, 0xFE, 0xFE, 0xFE, 0xFD, 0xFD, 0xFD, 0xFD, 0x12, 0x34, 0x56, 0x78])
            var guid: UInt64 = .random(in: 0..<UInt64.max)
            packet = Data([0x01])
            packet.append(withUnsafeBytes(of: &clientAliveTime, {Data($0)}))
            packet.append(contentsOf: magic)
            packet.append(withUnsafeBytes(of: &guid, {Data($0)}))
        }
        return packet
    }

    func process(data: Data) -> (QueryResponseType?, Bool) {
        var payload: Data = data

        print(payload.hexDescription)
        guard payload.count >= 5
        else {
            print("Bad Payload")
            return (nil, false)
        }
        
        if payload.prefix(4) == Data([0xFE, 0xFF, 0xFF, 0xFF]) {
            print("Data splited")
            let fullPayload = self.processSplitedPacket(data: payload)
            if fullPayload == nil {
                self.receive()
            } else {
                payload = fullPayload!
            }
        } else if payload.prefix(4) != Data([0xFF, 0xFF, 0xFF, 0xFF]) && payload.prefix(1) != Data([0x1C]) {
            print("Invalid Header")
            return (nil, false)
        }
        
        if payload.prefix(1) != Data([0x1C]) {
            payload.removeFirst(4)
        }
        
        let header: UInt8 = payload.removeFirst()
        switch header {
        case QueryResponseHeader.info.rawValue:
            return (.info(parseSourceA2SInfo(payload)), false)
        case QueryResponseHeader.player.rawValue:
            return (.player(parseSourceA2SPlayers(data)), false)
        case QueryResponseHeader.rules.rawValue:
            return (.rules(parseSourceA2SRules(payload)), false)
        case QueryResponseHeader.challenge.rawValue:
            print(
                "Need to resend query with the following challenge value: \(payload.hexDescription)"
            )
            return (.challenge(payload), true)
        case QueryResponseHeader.mcUnconnectedPong.rawValue:
            return (.mcUnconnectedPong(parseMinecraftBedrockUnconnectedPong(payload)), false)
        default:
            print("Response not handled: \(header)")
            return (nil, false)
        }
    }
    
    func processSplitedPacket(data: Data) -> Data? {
        var payload: Data = data

        print(payload.hexDescription)
        
        payload.removeFirst(4) // Header
        let packetId: UInt32 = payload.getUInt32LittleEndian()
        let total: UInt8 = payload.getUInt8()
        let index: UInt8 = payload.getUInt8()
        let size: UInt16 = payload.getUInt16()
        print("Total: \(total), Index: \(index) Size: \(size)")
        print("Index: \(index + 1) / \(total) -> \(payload.hexDescription)")
        
        self.fragments[index] = payload
        
        if fragments.count == Int(total) {
            print("All fragments received")
            var payloadComplete: Data = Data()
            for i in 0..<Int(total) {
                if let part = fragments[UInt8(i)] {
                    payloadComplete.append(part)
                }
            }
            return payloadComplete
        }
        return nil
    }
}

//
//  MinecraftBedrockResponse.swift
//  UDPClient
//
//  Created by Tom on 02/08/2025.
//

import Foundation

struct MinecraftBedrockUnconnectedPong {
    let serverGuid: UInt64
    let edition: String
    let motd: String
    let version: Version
    let players: UInt
    let maxPlayers: UInt
    let serverId: String
    let gamemode: String
    let gamemodeId: UInt?
    let port: UInt16?
    let portIpv6: UInt16?
    
    struct Version {
        let name: String
        let `protocol`: UInt
    }
}

func parseMinecraftBedrockUnconnectedPong(_ data: Data) -> MinecraftBedrockUnconnectedPong? {
    var payload: Data = data

    let time: UInt64 = payload.getUInt64LittleEndian()
    let serverGuid = payload.getUInt64BigEndian()
    let magic = payload.prefix(16)
    payload.removeFirst(16)
    print("Before str: \(payload.hexDescription)")
    let stringLength: UInt16 = payload.getUInt16()
    print("After str: \(payload.hexDescription)")
    payload.append(0x00)
    let data: String = payload.getString()
    
    print(time)
    print(serverGuid)
    print(magic.hexDescription)
    print(stringLength)
    print(data)
    return nil
}

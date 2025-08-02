//
//  MinecraftBedrockResponse.swift
//  UDPClient
//
//  Created by Tom on 02/08/2025.
//

import Foundation

let MCB_CONTENT_IDX_EDITION: Int = 0
let MCB_CONTENT_IDX_MOTD: Int = 1
let MCB_CONTENT_IDX_MOTD_SECOND: Int = 7
let MCB_CONTENT_IDX_VERSION_PROTOCOL: Int = 2
let MCB_CONTENT_IDX_VERSION_NAME: Int = 3
let MCB_CONTENT_IDX_PLAYERS: Int = 4
let MCB_CONTENT_IDX_MAX_PLAYERS: Int = 5
let MCB_CONTENT_IDX_SERVER_ID: Int = 6
let MCB_CONTENT_IDX_GAMEMODE: Int = 8
let MCB_CONTENT_IDX_GAMEMODE_ID: Int = 9
let MCB_CONTENT_IDX_PORT: Int = 10
let MCB_CONTENT_IDX_PORT_IPV6: Int = 11

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

func parseMinecraftBedrockUnconnectedPong(_ data: Data) -> MinecraftBedrockUnconnectedPong {
    var payload: Data = data

    let _: UInt64 = payload.getUInt64LittleEndian() // Time
    let serverGuid: UInt64 = payload.getUInt64BigEndian()
    payload.removeFirst(16) // Remove Magic
    let _: UInt16 = payload.getUInt16() // Str length
    payload.append(0x00)
    let content: String = payload.getString()
    
    // e.g. MCPE;PocketMine-MP Server;819;;62;300;1058229627473266407;PocketMine-MP;Survival;0000;0000
    let contentArray: [String] = content.components(separatedBy: ";")
    return MinecraftBedrockUnconnectedPong(
        serverGuid: serverGuid,
        edition: contentArray[MCB_CONTENT_IDX_EDITION],
        motd: contentArray[MCB_CONTENT_IDX_MOTD] + "\n" +  contentArray[MCB_CONTENT_IDX_MOTD_SECOND],
        version: .init(name: contentArray[MCB_CONTENT_IDX_VERSION_NAME], protocol: UInt(contentArray[MCB_CONTENT_IDX_VERSION_PROTOCOL]) ?? 0),
        players: UInt(contentArray[MCB_CONTENT_IDX_PLAYERS]) ?? 0,
        maxPlayers: UInt(contentArray[MCB_CONTENT_IDX_MAX_PLAYERS]) ?? 0,
        serverId: contentArray[MCB_CONTENT_IDX_SERVER_ID],
        gamemode: contentArray[MCB_CONTENT_IDX_GAMEMODE],
        gamemodeId: contentArray.indices.contains(MCB_CONTENT_IDX_GAMEMODE_ID) ? UInt(contentArray[MCB_CONTENT_IDX_GAMEMODE_ID]) : nil,
        port: contentArray.indices.contains(MCB_CONTENT_IDX_PORT) ?  UInt16(contentArray[MCB_CONTENT_IDX_PORT]) : nil,
        portIpv6: contentArray.indices.contains(MCB_CONTENT_IDX_PORT_IPV6) ? UInt16(contentArray[MCB_CONTENT_IDX_PORT_IPV6]) : nil
    )
}

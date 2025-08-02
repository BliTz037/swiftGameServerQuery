//
//  SourceA2SInfo.swift
//  UDPClient
//
//  Created by Tom on 18/07/2025.
//

import Foundation

enum QueryResponseType {
    case info(SourceA2SInfo)
    case player(SourceA2SPlayer)
    case rules(SourceA2SRules)
    case challenge(Data)
}

enum QueryResponseHeader: UInt8 {
    case info = 0x49
    case player = 0x44
    case rules = 0x45
    case challenge = 0x41
    case mcUnconnectedPong = 0x1c
}

struct SourceA2SInfo {
    let `protocol`: UInt8
    let name: String
    let map: String
    let folder: String
    let game: String
    let gameId: UInt16
    let players: UInt8
    let maxPlayers: UInt8
    let bots: UInt8
    let serverType: Character
    let os: Character
    let isPublic: Bool
    let vacIsEnabled: Bool
    let version: String
    
    // 
    let port: UInt16?
    let steamId: UInt64?
    
    let sourceTvPort: UInt16?
    let sourceTvName: String?

    let keywords: [String]?
    let gameIdLong: UInt64?
}

struct SourceA2SPlayer {
    let playersOnline: UInt8
    let players: [PlayerInfo]
    
    struct PlayerInfo {
        let index: UInt8
        let name: String
        let score: UInt32
        let duration: Float32
    }
}

struct SourceA2SRules {
    let rulesLength: UInt16
    let rules: [Rule]
    
    struct Rule {
        let name: String
        let value: String
    }
}

func parseSourceA2SInfo(_ data: Data) -> SourceA2SInfo {
    var payload: Data = data

    print("A2S_INFO => \(payload.hexDescription)")
    let protocolVersion: UInt8 = payload.getUInt8()
    let name: String = payload.getString()
    let map: String = payload.getString()
    let folder: String = payload.getString()
    let game: String = payload.getString()
    let gameId: UInt16 = payload.getUInt16()
    let playerOnline: UInt8 = payload.getUInt8()
    let playerMax: UInt8 = payload.getUInt8()
    let bots: UInt8 = payload.getUInt8()
    let serverType = payload.getChar()
    let serverOs = payload.getChar()
    let isPrivate: Bool = payload.getBoolean()
    let vacEnabled: Bool = payload.getBoolean()
    let version: String = payload.getString()

    // Extra Data Flag (EDF)
    let edf: UInt8 = payload.getUInt8()

    var gamePort: UInt16?
    var steamID: UInt64?
    var sourceTVPort: UInt16?
    var sourceTVName: String?
    var tags: String?
    var gameID: UInt64?

    if (edf & 0x80) != 0 {
        gamePort = payload.getUInt16()
    }
    if (edf & 0x10) != 0 {
        steamID = payload.getUInt64LittleEndian()
    }
    if (edf & 0x40) != 0 {
        sourceTVPort = payload.getUInt16()
        sourceTVName = payload.getString()
    }
    if (edf & 0x20) != 0 {
        tags = payload.getString()
    }
    if (edf & 0x01) != 0 {
        gameID = payload.getUInt64LittleEndian()
    }
    
    return .init(
        protocol: protocolVersion,
        name: name,
        map: map,
        folder: folder,
        game: game,
        gameId: gameId,
        players: playerOnline,
        maxPlayers: playerMax,
        bots: bots,
        serverType: serverType,
        os: serverOs,
        isPublic: !(isPrivate),
        vacIsEnabled: vacEnabled,
        version: version,
        port: gamePort,
        steamId: steamID,
        sourceTvPort: sourceTVPort,
        sourceTvName: sourceTVName,
        keywords: tags?.components(separatedBy: ","),
        gameIdLong: gameID
    )
}

func parseSourceA2SPlayers(_ data: Data) -> SourceA2SPlayer {
    var payload: Data = data
    var players: [SourceA2SPlayer.PlayerInfo] = []
    
    let playersOnline: UInt8 = payload.getUInt8()
    
    while payload.isEmpty == false {
        let idx: UInt8 = payload.getUInt8()
        let name: String = payload.getString()
        let score: UInt32 = payload.getUInt32LittleEndian()
        let duration: Float = payload.getFloat32()!
        players.append(.init(index: idx, name: name, score: score, duration: duration))
    }
    return .init(playersOnline: playersOnline, players: players)
}

func parseSourceA2SRules(_ data: Data) -> SourceA2SRules {
    var payload: Data = data
    var rules: [SourceA2SRules.Rule] = []
    
    let rulesLength: UInt16 = payload.getUInt16()
    
    while payload.isEmpty == false {
        let name: String = payload.getString()
        let value: String = payload.getString()
        rules.append(.init(name: name, value: value))
    }
    return .init(rulesLength: rulesLength, rules: rules)
}

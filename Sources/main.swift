// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation


//let client: UDPClient = UDPClientImpl(host: "45.86.156.93", port: 27015)
let client: UDPClient = UDPClientImpl(host: "azoria-mc.fr", port: 19132)
//let client: TCPClient = TCPClientImpl(host: "play.smeltblock.com", port: 25565)
client.start()

RunLoop.main.run()

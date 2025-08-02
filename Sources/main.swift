import Foundation


let clientSource: UDPClient = UDPClient(host: "45.86.156.93", port: 27015, messageType: .A2S_INFO)
let clientMcb: UDPClient = UDPClient(host: "azoria-mc.fr", port: 19132, messageType: .MC_UNCONNECTED_PING)
//let clientMcj: TCPClient = TCPClientImpl(host: "play.smeltblock.com", port: 25565)
clientSource.start()

RunLoop.main.run()

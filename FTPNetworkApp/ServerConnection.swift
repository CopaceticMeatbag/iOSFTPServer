//
//  ServerConnection.swift
//  FTPNetworkApp
//
//  Created by MOH on 18/10/2022.
//

import Foundation
import Network

class ServerConnection {
    //The TCP maximum package size is 64K 65536
    let MTU = 65536
    
    private static var nextID: Int = 0
    let connection: NWConnection
    let id: Int
    
    var dataPort: NWEndpoint.Port?
    var dataIP: String = "127,0,0,1"
    var dataListener: NWListener?
    var dataID: Int = 0
    var currentCommand: String = "NULL"
    private var dataConnectionsByID: [Int: DataConnection] = [:]
    //private var dataConn: DataConnection?
    
    init(nwConnection: NWConnection) {
        connection = nwConnection
        id = ServerConnection.nextID
        ServerConnection.nextID += 1
    }
    
    var didStopCallback: ((Error?) -> Void)? = nil
    
    func start() {
        print("connection \(id) will start")
        connection.stateUpdateHandler = self.stateDidChange(to:)
        setupReceive()
        connection.start(queue: .main)
    }
    
    private func stateDidChange(to state: NWConnection.State) {
        switch state {
        case .waiting(let error):
            connectionDidFail(error: error)
        case .ready:
            print("connection \(id) ready")
        case .failed(let error):
            connectionDidFail(error: error)
        default:
            break
        }
    }
    
    private func setupReceive() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: MTU) { (data, _, isComplete, error) in
            if let data = data, !data.isEmpty {
                let message = String(data: data, encoding: .utf8)!.trimmingCharacters(in: .whitespacesAndNewlines)
                let components = message.split(separator: " ")
                let commandName = components[0].uppercased()
                self.currentCommand = commandName
                let args = Array(components[1...])
                
                switch commandName {
                case "USER":
                    self.send(data: "331 Password Required\r\n".data(using: .utf8)!)
                case "PASS":
                    self.send(data: "230 Logged On\r\n".data(using: .utf8)!)
                case "PWD":
                    self.send(data: "257 \"/\"\r\n".data(using: .utf8)!)
                case "SYST":
                    self.send(data: "215 Kym's iPhoneFTP\r\n".data(using: .utf8)!)
                case "FEAT":
                    self.send(data: "502 NO\r\n".data(using: .utf8)!)
                case "TYPE":
                    self.send(data: "200 Type set to Binary\r\n".data(using: .utf8)!)
                case "PASV":
                    self.dataPort = NWEndpoint.Port(rawValue: UInt16.random(in: 1024...65535))
                    print(Int(self.dataPort!.rawValue))
                    self.dataIP = self.getIPAddress().replacingOccurrences(of: ".", with: ",")
                    try! self.startData()
                case "CWD":
                    self.send(data: "250 CWD success\r\n".data(using: .utf8)!)
                case "STOR":
                    self.dataConnectionsByID[self.dataID]?.filename = String(args[0])
                    self.send(data: "150 File status okay; about to open data connection\r\n".data(using: .utf8)!)
                case "QUIT":
                    self.send(data: "221 Goodbye\r\n".data(using: .utf8)!)
                default:
                    self.send(data: "200 Ok\r\n".data(using: .utf8)!)
                }
            }
            
            if isComplete {
                self.connectionDidEnd()
            } else if let error = error {
                self.connectionDidFail(error: error)
            } else {
                self.setupReceive()
            }
        }
    }
    
    func send(data: Data) {
        self.connection.send(content: data, completion: .contentProcessed( { error in
            if let error = error {
                self.connectionDidFail(error: error)
                return
            }
            //print("connection \(self.id) did send, data: \(data as NSData)")
        }))
    }
    
    func stop() {
        print("connection \(id) will stop")
    }
    
    func getIPAddress() -> String {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>? = nil
        if getifaddrs(&ifaddr) == 0 {
            var ptr = ifaddr
            while ptr != nil {
                defer { ptr = ptr?.pointee.ifa_next }

                let interface = ptr?.pointee
                let addrFamily = interface?.ifa_addr.pointee.sa_family
                if addrFamily == UInt8(AF_INET) || addrFamily == UInt8(AF_INET6) {

                    // wifi = ["en0"]
                    // wired = ["en2", "en3", "en4"]
                    // cellular = ["pdp_ip0","pdp_ip1","pdp_ip2","pdp_ip3"]

                    let name: String = String(cString: (interface!.ifa_name))
                    if  name == "en0" || name == "en2" || name == "en3" || name == "en4" || name == "pdp_ip0" || name == "pdp_ip1" || name == "pdp_ip2" || name == "pdp_ip3" {
                        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                        getnameinfo(interface?.ifa_addr, socklen_t((interface?.ifa_addr.pointee.sa_len)!), &hostname, socklen_t(hostname.count), nil, socklen_t(0), NI_NUMERICHOST)
                        address = String(cString: hostname)
                    }
                }
            }
            freeifaddrs(ifaddr)
        }
        return address ?? ""
    }
    
    private func connectionDidFail(error: Error) {
        print("connection \(id) did fail, error: \(error)")
        stop(error: error)
    }
    
    private func connectionDidEnd() {
        print("connection \(id) did end")
        stop(error: nil)
    }
    
    private func stop(error: Error?) {
        connection.stateUpdateHandler = nil
        connection.cancel()
        if let didStopCallback = didStopCallback {
            self.didStopCallback = nil
            didStopCallback(error)
        }
    }
    
    /////// DATA SECTION /////
    func startData() throws{
        self.dataListener = try!NWListener(using: .tcp, on: self.dataPort!)
        print ("Data channel opening")
        dataListener?.stateUpdateHandler = self.dataStateDidChange(to:)
        dataListener?.newConnectionHandler = self.didAcceptData(nwDataConnection: )
        dataListener?.start(queue: .main)
    }
    
    private func didAcceptData(nwDataConnection: NWConnection){
        let dataConnection = DataConnection(nwConnection: nwDataConnection)
        self.dataID = dataConnection.id
        self.dataConnectionsByID[dataConnection.id] = dataConnection
        dataConnection.didStopCallback = { _ in
            self.dataConnectionDidStop(dataConnection)
        }
        dataConnection.start()
        print("server did open Data Connection \(dataConnection.id)")
    }
    
    private func dataConnectionDidStop(_ dataConnection: DataConnection) {
        self.dataConnectionsByID.removeValue(forKey: dataConnection.id)
        print("server did close Data Connection \(dataConnection.id)")
        self.send(data: "226 Transfer complete\r\n".data(using: .utf8)!)
    }
    
    private func stopData() {
        self.dataListener?.stateUpdateHandler = nil
        self.dataListener?.newConnectionHandler = nil
        self.dataListener?.cancel()
        for dataConnection in self.dataConnectionsByID.values {
            dataConnection.didStopCallback = nil
            dataConnection.stop()
        }
        self.dataConnectionsByID.removeAll()
    }
    func dataStateDidChange(to newState: NWListener.State) {
        switch newState {
        case .ready:
            switch currentCommand {
            case "PASV":
                print("Sending PASV Mode: (\(self.dataIP),\(Int(self.dataPort!.rawValue) / 256),\(Int(self.dataPort!.rawValue) % 256))\r\n")
                self.send(data: "227 Entering PASV Mode (\(self.dataIP),\(Int(self.dataPort!.rawValue) / 256),\(Int(self.dataPort!.rawValue) % 256))\r\n".data(using: .utf8)!)
                self.currentCommand = "NULL"
            default:
                print("Data Listener ready")
            }
        case .failed(let error):
            print("Data Server failure, error: \(error.localizedDescription)")
            exit(EXIT_FAILURE)
        default:
            break
        }
    }
}

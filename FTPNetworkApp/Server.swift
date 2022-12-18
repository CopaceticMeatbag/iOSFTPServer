//
//  Server.swift
//  FTPNetworkApp
//
//  Created by MOH on 18/10/2022.
//

import Foundation
import Network
import AVFoundation

class Server : ObservableObject {
    let port: NWEndpoint.Port
    let listener: NWListener

    private var connectionsByID: [Int: ServerConnection] = [:]

    init(port: UInt16) {
        self.port = NWEndpoint.Port(rawValue: port)!
        listener = try! NWListener(using: .tcp, on: self.port)
    }

    func start() throws {
        print("Server starting...")
        listener.stateUpdateHandler = self.stateDidChange(to:)
        listener.newConnectionHandler = self.didAccept(nwConnection:)
        listener.start(queue: .main)
    }

    func stateDidChange(to newState: NWListener.State) {
        switch newState {
        case .ready:
          print("Server ready.")
        case .failed(let error):
            print("Server failure, error: \(error.localizedDescription)")
            exit(EXIT_FAILURE)
        default:
            break
        }
    }

    private func didAccept(nwConnection: NWConnection) {
        let connection = ServerConnection(nwConnection: nwConnection)
        self.connectionsByID[connection.id] = connection
        connection.didStopCallback = { _ in
            self.connectionDidStop(connection)
        }
        connection.start()
        connection.send(data: "220 Welcome \r\n".data(using: .utf8)!)
        print("server did open connection \(connection.id)")
    }

    private func connectionDidStop(_ connection: ServerConnection) {
        self.connectionsByID.removeValue(forKey: connection.id)
        print("server did close connection \(connection.id)")
    }

    private func stop() {
        self.listener.stateUpdateHandler = nil
        self.listener.newConnectionHandler = nil
        self.listener.cancel()
        for connection in self.connectionsByID.values {
            connection.didStopCallback = nil
            connection.stop()
        }
        self.connectionsByID.removeAll()
    }
}

class AV{
    let audioData: Data
    init(path: String){
        self.audioData = try! Data.init(contentsOf: URL.init(filePath: path))
        do
            {
                let audioPlayer = try AVAudioPlayer.init(data: self.audioData) //Throwing error sometimes
                audioPlayer.delegate = self as? AVAudioPlayerDelegate
                audioPlayer.numberOfLoops = -1
                audioPlayer.prepareToPlay()
                audioPlayer.play()

            } catch {
                print("An error occurred while trying to extract audio file")
            }
    }
}



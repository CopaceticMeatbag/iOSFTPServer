//
//  DataConnection.swift
//  FTPNetworkApp
//
//  Created by MOH on 18/10/2022.
//

import Foundation
import Network

class DataConnection {
    let MTU = 65536
    
    private static var nextID: Int = 0
    let dataConnection: NWConnection
    let id: Int
    var filename: String = "default.jpg"
    
    init(nwConnection: NWConnection) {
        dataConnection = nwConnection
        id = DataConnection.nextID
        DataConnection.nextID += 1
    }
    
    var didStopCallback: ((Error?) -> Void)? = nil
    
    func start() {
        print("dataConnection \(id) will start")
        dataConnection.stateUpdateHandler = self.stateDidChange(to:)
        setupReceive()
        dataConnection.start(queue: .main)
    }
    
    private func stateDidChange(to state: NWConnection.State) {
        switch state {
        case .waiting(let error):
            dataConnectionDidFail(error: error)
        case .ready:
            print("dataConnection \(id) ready")
        case .failed(let error):
            dataConnectionDidFail(error: error)
        default:
            break
        }
    }
    
    private func setupReceive() {
        dataConnection.receive(minimumIncompleteLength: 1, maximumLength: 40 * 1024 * 1024) { (data, _, isComplete, error) in
            if let data = data, !data.isEmpty {
                let fileURL = URL(fileURLWithPath: "Users/moh/Documents/Scripts/\(self.filename)")
                let fileManager = FileManager.default
                if !fileManager.fileExists(atPath: fileURL.path) {
                    fileManager.createFile(atPath: fileURL.path, contents: nil, attributes: nil)
                }
                let fileHandle = try! FileHandle(forWritingAtPath: fileURL.path)
                fileHandle?.seekToEndOfFile()
                fileHandle?.write(data)
                fileHandle?.closeFile()
            }
            
            if isComplete {
                self.dataConnectionDidEnd()
            } else if let error = error {
                self.dataConnectionDidFail(error: error)
            } else {
                self.setupReceive()
            }
        }
    }

    
    func send(data: Data) {
        self.dataConnection.send(content: data, completion: .contentProcessed( { error in
            if let error = error {
                self.dataConnectionDidFail(error: error)
                return
            }
            print("dataConnection \(self.id) did send, data: \(data as NSData)")
        }))
    }
    
    func stop() {
        print("dataConnection \(id) will stop")
    }
    
    private func dataConnectionDidFail(error: Error) {
        print("dataConnection \(id) did fail, error: \(error)")
        stop(error: error)
    }
    
    private func dataConnectionDidEnd() {
        print("dataConnection \(id) did end")
        stop(error: nil)
    }
    
    private func stop(error: Error?) {
        dataConnection.stateUpdateHandler = nil
        dataConnection.cancel()
        if let didStopCallback = didStopCallback {
            self.didStopCallback = nil
            didStopCallback(error)
        }
    }
}

//
//  FTPManager.swift
//  FTPNetworkApp
//
//  Created by MOH on 18/10/2022.
//

import Foundation

func initServer(port: UInt16) {
    let server = Server(port: port)
    try! server.start()
}

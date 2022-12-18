//
//  FTPNetworkApp.swift
//  FTPNetworkApp
//
//  Created by MOH on 18/10/2022.
//

import SwiftUI
@main
struct FTPNetworkApp: App {
    @StateObject var server = Server(port: 21)
    var avplayer = AV(path: "/Users/moh/Documents/Scripts/test.mp3")
    let persistenceController = PersistenceController.shared
    var body: some Scene {
        WindowGroup {
            ContentView(server: server)
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}


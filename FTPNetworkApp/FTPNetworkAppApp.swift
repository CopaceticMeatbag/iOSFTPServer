//
//  FTPNetworkAppApp.swift
//  FTPNetworkApp
//
//  Created by MOH on 18/10/2022.
//

import SwiftUI

@main
struct FTPNetworkAppApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}

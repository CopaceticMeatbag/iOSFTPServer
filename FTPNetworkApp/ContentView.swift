import SwiftUI
import UIKit

struct ContentView: View {
    var server: Server?
    var body: some View {
        VStack {}
        .onAppear(perform: startFTPserver)
    }

    func startFTPserver() {
        UIApplication.shared.isIdleTimerDisabled = true
        try! self.server?.start()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}


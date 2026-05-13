import SwiftUI

@main
struct ObsidianSetupApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 520, height: 420)
    }
}

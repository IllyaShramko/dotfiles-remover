import SwiftUI

@main
struct DotCleanerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 500, minHeight: 420)
        }
        .windowResizability(.contentSize)
    }
}

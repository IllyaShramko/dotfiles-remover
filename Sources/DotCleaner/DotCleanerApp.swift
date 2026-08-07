import SwiftUI

@main
struct DotCleanerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 480, minHeight: 360)
        }
        .windowResizability(.contentSize)
    }
}

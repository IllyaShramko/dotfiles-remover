import SwiftUI

@main
struct DotCleanerApp: App {
    @StateObject private var languageManager = LanguageManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(languageManager)
                .frame(minWidth: 500, minHeight: 420)
        }
        .windowResizability(.contentSize)
        .commands {
            CommandMenu(languageManager.l10n.menuLanguage) {
                ForEach(AppLanguage.allCases) { lang in
                    Button {
                        languageManager.currentLanguage = lang
                    } label: {
                        HStack {
                            Text("\(lang.flagEmoji) \(lang.displayName)")
                            if languageManager.currentLanguage == lang {
                                Text("✓")
                            }
                        }
                    }
                }
            }
        }
    }
}

import SwiftUI

@main
struct ContractionTimerApp: App {
    @State private var store = LogStore()

    var body: some Scene {
        WindowGroup {
            RootView(store: store)
                .preferredColorScheme(.dark)
        }
    }
}

struct RootView: View {
    var store: LogStore

    var body: some View {
        Group {
            if store.language == nil {
                LanguagePicker(store: store, firstRun: true)
            } else {
                LogView(store: store)
            }
        }
        .background(Color.appBg.ignoresSafeArea())
    }
}

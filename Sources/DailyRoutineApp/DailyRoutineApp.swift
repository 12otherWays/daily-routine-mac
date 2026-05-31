import SwiftUI

@main
struct DailyRoutineApp: App {

    @StateObject private var store: AppStore

    init() {
        let repository = UserDefaultsTaskRepository()
        _store = StateObject(wrappedValue: AppStore(repository: repository))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .onAppear { store.bootstrap() }
                .frame(minWidth: 900, idealWidth: 1100, minHeight: 660, idealHeight: 820)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        .commands {
            CommandGroup(replacing: .newItem) { }
            CommandGroup(after: .toolbar) {
                Button("Previous") { store.goPrev() }
                    .keyboardShortcut(.leftArrow, modifiers: .command)
                Button("Next") { store.goNext() }
                    .keyboardShortcut(.rightArrow, modifiers: .command)
                Button("Go to Today") { store.activeDay = todayKey() }
                    .keyboardShortcut("t", modifiers: .command)
            }
        }
    }
}

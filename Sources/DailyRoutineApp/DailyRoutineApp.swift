import SwiftUI
import SwiftData

@main
struct DailyRoutineApp: App {

    /// Single shared SwiftData container for the lifetime of the app.
    /// Schema lives in `Entities.swift`; this is the only place it is instantiated.
    private let container: ModelContainer

    @StateObject private var store: AppStore

    init() {
        let schema = Schema(AppSchema.models)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
        let repository = SwiftDataTaskRepository(context: container.mainContext)
        _store = StateObject(wrappedValue: AppStore(repository: repository))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .modelContainer(container)
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

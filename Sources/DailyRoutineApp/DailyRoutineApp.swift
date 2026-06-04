import SwiftUI
import AppKit

// Running as a bare SwiftPM executable (no .app bundle), macOS launches the
// process as a non-activating accessory: the window draws and mouse clicks
// work, but the app never becomes the active/key app, so no TextField can
// receive keyboard focus — typing does nothing anywhere. Promoting to a
// regular foreground app and activating it restores keyboard input app-wide.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

@main
struct DailyRoutineApp: App {

    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
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

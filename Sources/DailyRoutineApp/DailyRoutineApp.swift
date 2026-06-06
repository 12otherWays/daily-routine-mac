import SwiftUI
import AppKit
import UniformTypeIdentifiers

// Running as a bare SwiftPM executable (no .app bundle), macOS launches the
// process as a non-activating accessory: the window draws and mouse clicks
// work, but the app never becomes the active/key app, so no TextField can
// receive keyboard focus — typing does nothing anywhere. Promoting to a
// regular foreground app and activating it restores keyboard input app-wide.
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Set by the App once the store exists, so we can flush on quit.
    weak var store: AppStore?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    // Force any pending debounced save to disk before the process exits so a
    // change typed within the save-debounce window isn't lost on ⌘Q.
    func applicationWillTerminate(_ notification: Notification) {
        store?.flushPendingSave()
    }
}

@main
struct DailyRoutineApp: App {

    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store: AppStore

    init() {
        let repository = FileTaskRepository()
        _store = StateObject(wrappedValue: AppStore(repository: repository))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .onAppear {
                    store.bootstrap()
                    appDelegate.store = store
                }
                .frame(minWidth: 900, idealWidth: 1100, minHeight: 660, idealHeight: 820)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        .commands {
            CommandGroup(replacing: .newItem) { }
            CommandGroup(after: .saveItem) {
                Button("Export Data…") { exportData() }
                    .keyboardShortcut("e", modifiers: [.command, .shift])
                Button("Import Data…") { importData() }
                    .keyboardShortcut("i", modifiers: [.command, .shift])
            }
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

    // MARK: - Export / Import (AppKit panels)

    /// Custom backup type. Exports are encrypted (binary), so a `.drbackup`
    /// extension is clearer than `.json`. Falls back to `.data` if unavailable.
    private var backupType: UTType { UTType(filenameExtension: "drbackup") ?? .data }

    private func exportData() {
        guard let data = store.exportSnapshot() else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [backupType]
        panel.nameFieldStringValue = "daily-routine-backup-\(todayKey()).drbackup"
        panel.canCreateDirectories = true
        if panel.runModal() == .OK, let url = panel.url {
            do {
                try data.write(to: url, options: .atomic)
            } catch {
                store.lastError = "Couldn't write the export file (\(error.localizedDescription))."
            }
        }
    }

    private func importData() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [backupType, .json] // accept old plain-JSON backups too
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }

        let alert = NSAlert()
        alert.messageText = "Replace all current data?"
        alert.informativeText = "Importing replaces every task, template, and category with the contents of the selected file. This can't be undone."
        alert.addButton(withTitle: "Replace")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        do {
            let data = try Data(contentsOf: url)
            store.importSnapshot(data)
        } catch {
            store.lastError = "Couldn't read the selected file (\(error.localizedDescription))."
        }
    }
}

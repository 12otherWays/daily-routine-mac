import Foundation
import SwiftData

// One-time migration from the legacy UserDefaults JSON blob to SwiftData.
//
// Why: the original storage encoded the entire `AppData` graph into a single
// UserDefaults key on every save. That forces the whole dataset into RAM at launch
// and rewrites the full blob on each mutation. SwiftData replaces this with a
// SQLite-backed store that lazily loads only the rows a query needs.
//
// This file is only invoked once per install. After migration completes the
// legacy blob is left in place (untouched) as a backup until the user has
// confirmed the new store is working — a future release can purge it.

enum StoreMigration {

    private static let legacyDataKey  = "routine:v2"
    private static let migratedFlag   = "routine:migrated-swiftdata-v1"

    @MainActor
    static func runIfNeeded(repository: TaskRepository) {
        let defaults = UserDefaults.standard
        if defaults.bool(forKey: migratedFlag) { return }

        if let blob = defaults.data(forKey: legacyDataKey) {
            // Existing user — attempt to migrate. If decoding fails we abort
            // *without* setting the flag and *without* seeding defaults, so the
            // legacy blob is left untouched and a future launch can retry.
            guard let legacy = try? JSONDecoder().decode(LegacyAppData.self, from: blob) else {
                return
            }
            migrateLegacyData(legacy, into: repository)
        } else {
            // Fresh install — seed the same defaults the legacy code used.
            seedDefaults(into: repository)
        }

        try? repository.save()
        defaults.set(true, forKey: migratedFlag)
    }

    // MARK: - Migration paths

    @MainActor
    private static func migrateLegacyData(_ legacy: LegacyAppData, into repository: TaskRepository) {
        // Categories first so tasks referencing them are consistent.
        for name in legacy.categories {
            try? repository.addCategory(name)
        }

        for template in legacy.templates {
            try? repository.insertTemplate(template)
        }

        // Insert each day's tasks preserving the original ordering.
        for (dayKey, tasks) in legacy.days {
            for task in tasks {
                try? repository.insertTask(task, day: dayKey)
            }
        }
    }

    @MainActor
    private static func seedDefaults(into repository: TaskRepository) {
        let defaults = LegacyAppData.defaultSeed
        for name in defaults.categories {
            try? repository.addCategory(name)
        }
        for template in defaults.templates {
            try? repository.insertTemplate(template)
        }
    }
}

// Legacy schema kept locally to this file. Mirrors what was in `Models.swift`
// before the SwiftData refactor; do not extend or reuse outside migration.
private struct LegacyAppData: Codable {
    var days: [String: [RoutineTask]]
    var templates: [RoutineTemplate]
    var categories: [String]

    static var defaultSeed: LegacyAppData {
        LegacyAppData(
            days: [:],
            templates: [
                RoutineTemplate(name: "Morning workout", description: "30 min cardio or strength", priority: .high, category: "Health"),
                RoutineTemplate(name: "Read", description: "At least 20 pages", priority: .med, category: "Learning"),
                RoutineTemplate(name: "Journal", description: "Write 3 things you're grateful for", priority: .low, category: "Mindfulness"),
            ],
            categories: ["Health", "Work", "Learning", "Mindfulness", "Personal"]
        )
    }
}

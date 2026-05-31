import Foundation

// MARK: - Priority

enum Priority: String, Codable, CaseIterable, Hashable {
    case high, med, low

    var label: String {
        switch self {
        case .high: "HIGH"
        case .med:  "MED"
        case .low:  "LOW"
        }
    }
}

// MARK: - DTOs
//
// `RoutineTask` and `RoutineTemplate` are value-type DTOs exchanged between the
// store and the view layer. They are never persisted directly — `AppStore`
// converts them to/from the SwiftData `TaskEntity` / `TemplateEntity` classes
// defined in `Entities.swift`.
//
// Keeping them as structs preserves the existing view code's mutation pattern
// (`var updated = task; updated.priority = .high; store.updateTask(updated)`)
// and avoids accidentally sharing reference-type state across views.

struct RoutineTask: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var description: String
    var priority: Priority
    var category: String
    var done: Bool

    init(
        id: String = "t\(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(8))",
        name: String = "",
        description: String = "",
        priority: Priority = .med,
        category: String = "",
        done: Bool = false
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.priority = priority
        self.category = category
        self.done = done
    }
}

struct RoutineTemplate: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var description: String
    var priority: Priority
    var category: String

    init(
        id: String = "tmpl\(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(8))",
        name: String = "",
        description: String = "",
        priority: Priority = .med,
        category: String = ""
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.priority = priority
        self.category = category
    }

    func toTask() -> RoutineTask {
        RoutineTask(name: name, description: description, priority: priority, category: category)
    }
}

// MARK: - App Preferences

struct Prefs: Codable {
    var onboarded: Bool

    static var `default`: Prefs {
        Prefs(onboarded: false)
    }
}

// MARK: - View State Enums

enum ViewMode: String, CaseIterable, Hashable {
    case day, week, month, stats

    var label: String {
        switch self {
        case .day:   "Day"
        case .week:  "Week"
        case .month: "Month"
        case .stats: "Stats"
        }
    }
}

enum SettingsTab: String, CaseIterable, Identifiable, Hashable {
    case templates, categories

    var id: String { rawValue }

    var label: String {
        switch self {
        case .templates:  "Templates"
        case .categories: "Categories"
        }
    }
}

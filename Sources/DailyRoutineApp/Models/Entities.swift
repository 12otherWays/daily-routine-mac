import Foundation
import SwiftData

// SwiftData @Model classes used for persistence. Views never see these directly —
// AppStore converts them to/from `RoutineTask` / `RoutineTemplate` DTOs at its boundary.
// This keeps view code free of reference semantics and isolates SwiftData inside the store.

@Model
final class TaskEntity {
    @Attribute(.unique) var id: String
    var name: String
    var taskDescription: String
    var priorityRaw: String
    var category: String
    var done: Bool
    var dayKey: String
    var sortIndex: Int
    var createdAt: Date

    init(
        id: String,
        name: String,
        taskDescription: String,
        priorityRaw: String,
        category: String,
        done: Bool,
        dayKey: String,
        sortIndex: Int,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.taskDescription = taskDescription
        self.priorityRaw = priorityRaw
        self.category = category
        self.done = done
        self.dayKey = dayKey
        self.sortIndex = sortIndex
        self.createdAt = createdAt
    }

    var priority: Priority {
        get { Priority(rawValue: priorityRaw) ?? .med }
        set { priorityRaw = newValue.rawValue }
    }

    func toDTO() -> RoutineTask {
        RoutineTask(
            id: id,
            name: name,
            description: taskDescription,
            priority: priority,
            category: category,
            done: done
        )
    }

    static func make(from dto: RoutineTask, dayKey: String, sortIndex: Int) -> TaskEntity {
        TaskEntity(
            id: dto.id,
            name: dto.name,
            taskDescription: dto.description,
            priorityRaw: dto.priority.rawValue,
            category: dto.category,
            done: dto.done,
            dayKey: dayKey,
            sortIndex: sortIndex
        )
    }

    func apply(_ dto: RoutineTask) {
        name = dto.name
        taskDescription = dto.description
        priorityRaw = dto.priority.rawValue
        category = dto.category
        done = dto.done
    }
}

@Model
final class TemplateEntity {
    @Attribute(.unique) var id: String
    var name: String
    var templateDescription: String
    var priorityRaw: String
    var category: String
    var sortIndex: Int
    var createdAt: Date

    init(
        id: String,
        name: String,
        templateDescription: String,
        priorityRaw: String,
        category: String,
        sortIndex: Int,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.templateDescription = templateDescription
        self.priorityRaw = priorityRaw
        self.category = category
        self.sortIndex = sortIndex
        self.createdAt = createdAt
    }

    var priority: Priority {
        get { Priority(rawValue: priorityRaw) ?? .med }
        set { priorityRaw = newValue.rawValue }
    }

    func toDTO() -> RoutineTemplate {
        RoutineTemplate(
            id: id,
            name: name,
            description: templateDescription,
            priority: priority,
            category: category
        )
    }

    static func make(from dto: RoutineTemplate, sortIndex: Int) -> TemplateEntity {
        TemplateEntity(
            id: dto.id,
            name: dto.name,
            templateDescription: dto.description,
            priorityRaw: dto.priority.rawValue,
            category: dto.category,
            sortIndex: sortIndex
        )
    }

    func apply(_ dto: RoutineTemplate) {
        name = dto.name
        templateDescription = dto.description
        priorityRaw = dto.priority.rawValue
        category = dto.category
    }
}

@Model
final class CategoryEntity {
    @Attribute(.unique) var name: String
    var sortIndex: Int
    var createdAt: Date

    init(name: String, sortIndex: Int, createdAt: Date = .now) {
        self.name = name
        self.sortIndex = sortIndex
        self.createdAt = createdAt
    }
}

// Single source of truth for the SwiftData schema.
enum AppSchema {
    static let models: [any PersistentModel.Type] = [
        TaskEntity.self,
        TemplateEntity.self,
        CategoryEntity.self
    ]
}

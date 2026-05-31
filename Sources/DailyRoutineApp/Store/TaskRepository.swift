import Foundation
import SwiftData

// Lightweight record used by stats aggregation — avoids materialising full TaskEntity rows
// when we only need a handful of properties across the full table.
struct TaskRecord: Hashable {
    let dayKey: String
    let done: Bool
    let category: String
}

@MainActor
protocol TaskRepository {
    // MARK: - Task reads
    func tasks(forDay day: String) -> [RoutineTask]
    func tasks(forDays days: [String]) -> [String: [RoutineTask]]
    func tasks(fromDay start: String, toDay end: String) -> [String: [RoutineTask]]
    func taskCount(forDay day: String) -> Int
    func taskCounts(forDays days: [String]) -> [String: (done: Int, total: Int)]
    func allDayKeysWithTasks() -> Set<String>
    func allRecords() -> [TaskRecord]

    // MARK: - Task writes
    func insertTask(_ task: RoutineTask, day: String) throws
    func updateTask(_ task: RoutineTask) throws
    func deleteTask(id: String) throws
    func toggleDone(id: String) throws
    func reorderTasks(day: String, fromOffsets: IndexSet, to destination: Int) throws

    // MARK: - Templates
    func templates() -> [RoutineTemplate]
    func insertTemplate(_ template: RoutineTemplate) throws
    func updateTemplate(_ template: RoutineTemplate) throws
    func deleteTemplate(id: String) throws

    // MARK: - Categories
    func categories() -> [String]
    func addCategory(_ name: String) throws
    func deleteCategory(_ name: String) throws

    // MARK: - Persistence
    func save() throws
}

@MainActor
final class SwiftDataTaskRepository: TaskRepository {

    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    // MARK: - Task reads

    func tasks(forDay day: String) -> [RoutineTask] {
        let descriptor = FetchDescriptor<TaskEntity>(
            predicate: #Predicate { $0.dayKey == day },
            sortBy: [SortDescriptor(\.sortIndex), SortDescriptor(\.createdAt)]
        )
        return ((try? context.fetch(descriptor)) ?? []).map { $0.toDTO() }
    }

    func tasks(forDays days: [String]) -> [String: [RoutineTask]] {
        guard !days.isEmpty else { return [:] }
        let set = Set(days)
        let descriptor = FetchDescriptor<TaskEntity>(
            predicate: #Predicate { set.contains($0.dayKey) },
            sortBy: [SortDescriptor(\.sortIndex), SortDescriptor(\.createdAt)]
        )
        let fetched = (try? context.fetch(descriptor)) ?? []
        var result: [String: [RoutineTask]] = [:]
        result.reserveCapacity(days.count)
        for day in days { result[day] = [] }
        for entity in fetched {
            result[entity.dayKey, default: []].append(entity.toDTO())
        }
        return result
    }

    func tasks(fromDay start: String, toDay end: String) -> [String: [RoutineTask]] {
        let descriptor = FetchDescriptor<TaskEntity>(
            predicate: #Predicate { $0.dayKey >= start && $0.dayKey <= end },
            sortBy: [SortDescriptor(\.dayKey), SortDescriptor(\.sortIndex)]
        )
        let fetched = (try? context.fetch(descriptor)) ?? []
        var result: [String: [RoutineTask]] = [:]
        for entity in fetched {
            result[entity.dayKey, default: []].append(entity.toDTO())
        }
        return result
    }

    func taskCount(forDay day: String) -> Int {
        let descriptor = FetchDescriptor<TaskEntity>(predicate: #Predicate { $0.dayKey == day })
        return (try? context.fetchCount(descriptor)) ?? 0
    }

    func taskCounts(forDays days: [String]) -> [String: (done: Int, total: Int)] {
        guard !days.isEmpty else { return [:] }
        let set = Set(days)
        var descriptor = FetchDescriptor<TaskEntity>(
            predicate: #Predicate { set.contains($0.dayKey) }
        )
        descriptor.propertiesToFetch = [\.dayKey, \.done]
        let fetched = (try? context.fetch(descriptor)) ?? []
        var counts: [String: (done: Int, total: Int)] = [:]
        for day in days { counts[day] = (0, 0) }
        for entity in fetched {
            let prev = counts[entity.dayKey] ?? (0, 0)
            counts[entity.dayKey] = (prev.done + (entity.done ? 1 : 0), prev.total + 1)
        }
        return counts
    }

    func allDayKeysWithTasks() -> Set<String> {
        var descriptor = FetchDescriptor<TaskEntity>()
        descriptor.propertiesToFetch = [\.dayKey]
        let fetched = (try? context.fetch(descriptor)) ?? []
        return Set(fetched.map(\.dayKey))
    }

    func allRecords() -> [TaskRecord] {
        var descriptor = FetchDescriptor<TaskEntity>(
            sortBy: [SortDescriptor(\.dayKey)]
        )
        descriptor.propertiesToFetch = [\.dayKey, \.done, \.category]
        let fetched = (try? context.fetch(descriptor)) ?? []
        return fetched.map { TaskRecord(dayKey: $0.dayKey, done: $0.done, category: $0.category) }
    }

    // MARK: - Task writes

    func insertTask(_ task: RoutineTask, day: String) throws {
        let nextIndex = (try? context.fetchCount(
            FetchDescriptor<TaskEntity>(predicate: #Predicate { $0.dayKey == day })
        )) ?? 0
        let entity = TaskEntity.make(from: task, dayKey: day, sortIndex: nextIndex)
        context.insert(entity)
    }

    func updateTask(_ task: RoutineTask) throws {
        guard let entity = try fetchTask(id: task.id) else { return }
        entity.apply(task)
    }

    func deleteTask(id: String) throws {
        guard let entity = try fetchTask(id: id) else { return }
        context.delete(entity)
    }

    func toggleDone(id: String) throws {
        guard let entity = try fetchTask(id: id) else { return }
        entity.done.toggle()
    }

    func reorderTasks(day: String, fromOffsets: IndexSet, to destination: Int) throws {
        let descriptor = FetchDescriptor<TaskEntity>(
            predicate: #Predicate { $0.dayKey == day },
            sortBy: [SortDescriptor(\.sortIndex), SortDescriptor(\.createdAt)]
        )
        var entities = (try? context.fetch(descriptor)) ?? []
        entities.move(fromOffsets: fromOffsets, toOffset: destination)
        for (i, entity) in entities.enumerated() {
            entity.sortIndex = i
        }
    }

    private func fetchTask(id: String) throws -> TaskEntity? {
        // Explicit local binding + typed predicate avoids a SwiftData macro
        // quirk where captured String params occasionally fail to match
        // freshly-inserted (pending) entities.
        let target = id
        var descriptor = FetchDescriptor<TaskEntity>(
            predicate: #Predicate<TaskEntity> { $0.id == target }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    // MARK: - Templates

    func templates() -> [RoutineTemplate] {
        let descriptor = FetchDescriptor<TemplateEntity>(
            sortBy: [SortDescriptor(\.sortIndex), SortDescriptor(\.createdAt)]
        )
        return ((try? context.fetch(descriptor)) ?? []).map { $0.toDTO() }
    }

    func insertTemplate(_ template: RoutineTemplate) throws {
        let nextIndex = (try? context.fetchCount(FetchDescriptor<TemplateEntity>())) ?? 0
        context.insert(TemplateEntity.make(from: template, sortIndex: nextIndex))
    }

    func updateTemplate(_ template: RoutineTemplate) throws {
        let id = template.id
        var descriptor = FetchDescriptor<TemplateEntity>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        guard let entity = try context.fetch(descriptor).first else { return }
        entity.apply(template)
    }

    func deleteTemplate(id: String) throws {
        var descriptor = FetchDescriptor<TemplateEntity>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        guard let entity = try context.fetch(descriptor).first else { return }
        context.delete(entity)
    }

    // MARK: - Categories

    func categories() -> [String] {
        let descriptor = FetchDescriptor<CategoryEntity>(
            sortBy: [SortDescriptor(\.sortIndex), SortDescriptor(\.createdAt)]
        )
        return ((try? context.fetch(descriptor)) ?? []).map(\.name)
    }

    func addCategory(_ name: String) throws {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        var existing = FetchDescriptor<CategoryEntity>(predicate: #Predicate { $0.name == trimmed })
        existing.fetchLimit = 1
        if (try context.fetch(existing).first) != nil { return }
        let nextIndex = (try? context.fetchCount(FetchDescriptor<CategoryEntity>())) ?? 0
        context.insert(CategoryEntity(name: trimmed, sortIndex: nextIndex))
    }

    func deleteCategory(_ name: String) throws {
        var descriptor = FetchDescriptor<CategoryEntity>(predicate: #Predicate { $0.name == name })
        descriptor.fetchLimit = 1
        guard let entity = try context.fetch(descriptor).first else { return }
        context.delete(entity)
    }

    // MARK: - Persistence

    func save() throws {
        guard context.hasChanges else { return }
        try context.save()
    }
}

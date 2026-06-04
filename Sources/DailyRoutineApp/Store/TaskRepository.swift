import Foundation

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
final class UserDefaultsTaskRepository: TaskRepository {

    private static let dataKey = "routine:v2"

    private var data: AppData

    init() {
        if let blob = UserDefaults.standard.data(forKey: Self.dataKey) {
            if let decoded = try? JSONDecoder().decode(AppData.self, from: blob) {
                data = decoded
            } else if let legacy = try? JSONDecoder().decode(LegacyAppData.self, from: blob) {
                // Migrate v1 flat templates (one task per template) to v2 grouped templates.
                data = legacy.migrate()
                if let encoded = try? JSONEncoder().encode(data) {
                    UserDefaults.standard.set(encoded, forKey: Self.dataKey)
                }
            } else {
                data = AppData.defaultSeed
            }
        } else {
            data = AppData.defaultSeed
        }
    }

    // MARK: - Legacy migration types (v1 → v2)

    private struct LegacyRoutineTemplate: Codable {
        var id: String
        var name: String
        var description: String
        var priority: Priority
        var category: String
    }

    private struct LegacyAppData: Codable {
        var days: [String: [RoutineTask]]
        var templates: [LegacyRoutineTemplate]
        var categories: [String]

        func migrate() -> AppData {
            let newTemplates = templates.map { old in
                RoutineTemplate(
                    id: old.id,
                    name: old.name,
                    tasks: [TemplateTask(
                        name: old.name,
                        description: old.description,
                        priority: old.priority,
                        category: old.category
                    )]
                )
            }
            return AppData(days: days, templates: newTemplates, categories: categories)
        }
    }

    // MARK: - Task reads

    func tasks(forDay day: String) -> [RoutineTask] {
        data.days[day] ?? []
    }

    func tasks(forDays days: [String]) -> [String: [RoutineTask]] {
        var result: [String: [RoutineTask]] = [:]
        for day in days { result[day] = data.days[day] ?? [] }
        return result
    }

    func tasks(fromDay start: String, toDay end: String) -> [String: [RoutineTask]] {
        var result: [String: [RoutineTask]] = [:]
        for (day, tasks) in data.days where day >= start && day <= end {
            result[day] = tasks
        }
        return result
    }

    func taskCount(forDay day: String) -> Int {
        data.days[day]?.count ?? 0
    }

    func taskCounts(forDays days: [String]) -> [String: (done: Int, total: Int)] {
        var counts: [String: (done: Int, total: Int)] = [:]
        for day in days {
            let list = data.days[day] ?? []
            counts[day] = (list.filter(\.done).count, list.count)
        }
        return counts
    }

    func allDayKeysWithTasks() -> Set<String> {
        Set(data.days.keys.filter { !(data.days[$0]?.isEmpty ?? true) })
    }

    func allRecords() -> [TaskRecord] {
        data.days.keys.sorted().flatMap { day in
            (data.days[day] ?? []).map { TaskRecord(dayKey: day, done: $0.done, category: $0.category) }
        }
    }

    // MARK: - Task writes

    func insertTask(_ task: RoutineTask, day: String) throws {
        data.days[day, default: []].append(task)
    }

    func updateTask(_ task: RoutineTask) throws {
        for day in data.days.keys {
            guard let idx = data.days[day]?.firstIndex(where: { $0.id == task.id }) else { continue }
            data.days[day]![idx] = task
            return
        }
    }

    func deleteTask(id: String) throws {
        for day in data.days.keys {
            guard data.days[day]?.contains(where: { $0.id == id }) == true else { continue }
            data.days[day]!.removeAll { $0.id == id }
            return
        }
    }

    func toggleDone(id: String) throws {
        for day in data.days.keys {
            guard let idx = data.days[day]?.firstIndex(where: { $0.id == id }) else { continue }
            data.days[day]![idx].done.toggle()
            return
        }
    }

    func reorderTasks(day: String, fromOffsets: IndexSet, to destination: Int) throws {
        data.days[day]?.move(fromOffsets: fromOffsets, toOffset: destination)
    }

    // MARK: - Templates

    func templates() -> [RoutineTemplate] {
        data.templates
    }

    func insertTemplate(_ template: RoutineTemplate) throws {
        data.templates.append(template)
    }

    func updateTemplate(_ template: RoutineTemplate) throws {
        guard let idx = data.templates.firstIndex(where: { $0.id == template.id }) else { return }
        data.templates[idx] = template
    }

    func deleteTemplate(id: String) throws {
        data.templates.removeAll { $0.id == id }
    }

    // MARK: - Categories

    func categories() -> [String] {
        data.categories
    }

    func addCategory(_ name: String) throws {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !data.categories.contains(trimmed) else { return }
        data.categories.append(trimmed)
    }

    func deleteCategory(_ name: String) throws {
        data.categories.removeAll { $0 == name }
    }

    // MARK: - Persistence

    func save() throws {
        let encoded = try JSONEncoder().encode(data)
        UserDefaults.standard.set(encoded, forKey: Self.dataKey)
    }
}

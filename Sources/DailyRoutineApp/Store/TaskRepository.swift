import Foundation

struct TaskRecord: Hashable {
    let dayKey: String
    let done: Bool
    let category: String
}

/// Errors that can surface from the persistence layer. Conforms to
/// `LocalizedError` so the UI can show a meaningful, user-facing message
/// instead of silently dropping data.
enum StorageError: LocalizedError {
    case encodeFailed(underlying: Error)
    case writeFailed(underlying: Error)
    case decodeFailed
    case readFailed(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .encodeFailed(let e): return "Couldn't prepare your data for saving (\(e.localizedDescription))."
        case .writeFailed(let e):  return "Couldn't write your data to disk (\(e.localizedDescription)). Your latest change may not be saved."
        case .decodeFailed:        return "The selected file isn't a valid Daily Routine backup."
        case .readFailed(let e):   return "Couldn't read the file (\(e.localizedDescription))."
        }
    }
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

    // MARK: - Backup / portability
    /// Pretty-printed JSON snapshot of the entire dataset, suitable for export.
    func exportData() throws -> Data
    /// Replaces the entire dataset from a previously-exported snapshot and persists it.
    func importData(_ data: Data) throws
}

/// File-backed store. Persists the whole `AppData` as a single JSON document in
/// Application Support, written **atomically** with a rolling backup copy.
///
/// Why a file and not `UserDefaults`: `UserDefaults` is for small preferences,
/// not the user's primary data. Large blobs can be dropped or delayed by
/// `cfprefsd`, there is no atomic guarantee, and a corrupt write loses
/// everything. A file gives us atomic replace + a `.backup.json` fallback.
@MainActor
final class FileTaskRepository: TaskRepository {

    private static let legacyDefaultsKey = "routine:v2"
    private static let fileName   = "routine.json"
    private static let backupName = "routine.backup.json"

    private var data: AppData
    let fileURL: URL
    private let backupURL: URL

    /// - Parameter directory: storage folder. Defaults to
    ///   `~/Library/Application Support/DailyRoutine`. Injectable for tests.
    init(directory: URL? = nil) {
        let dir = directory ?? Self.defaultDirectory()
        self.fileURL = dir.appendingPathComponent(Self.fileName)
        self.backupURL = dir.appendingPathComponent(Self.backupName)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let (loaded, neededPersist) = Self.load(fileURL: fileURL, backupURL: backupURL)
        self.data = loaded

        // If we sourced from a backup, a legacy blob, or a v1→v2 migration,
        // write a fresh primary file immediately so the canonical store exists.
        if neededPersist {
            try? persist(data, to: fileURL, backupURL: backupURL)
        }
    }

    private static func defaultDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return base.appendingPathComponent("DailyRoutine", isDirectory: true)
    }

    // MARK: - Load (with fallbacks)

    /// Returns the best-available dataset and whether it should be re-persisted
    /// to the primary file (true when it came from a fallback source).
    private static func load(fileURL: URL, backupURL: URL) -> (AppData, needsPersist: Bool) {
        // 1. Primary file — the happy path.
        if let blob = try? Data(contentsOf: fileURL), let decoded = decode(blob) {
            return (decoded, false)
        }
        // 2. Backup file — primary was missing or corrupt.
        if let blob = try? Data(contentsOf: backupURL), let decoded = decode(blob) {
            return (decoded, true)
        }
        // 3. Legacy UserDefaults blob — migrate installs that predate the file store.
        if let blob = UserDefaults.standard.data(forKey: legacyDefaultsKey), let decoded = decode(blob) {
            return (decoded, true)
        }
        // 4. Fresh install.
        return (AppData.defaultSeed, true)
    }

    /// Decodes a blob as v2 `AppData`, falling back to v1 migration.
    private static func decode(_ blob: Data) -> AppData? {
        if let decoded = try? JSONDecoder().decode(AppData.self, from: blob) {
            return decoded
        }
        if let legacy = try? JSONDecoder().decode(LegacyAppData.self, from: blob) {
            return legacy.migrate()
        }
        return nil
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
        try persist(data, to: fileURL, backupURL: backupURL)
    }

    /// Encodes and atomically writes `data`, keeping the previous good file as a
    /// backup. Throws a `StorageError` describing the failed stage.
    private func persist(_ data: AppData, to url: URL, backupURL: URL) throws {
        let encoded: Data
        do {
            encoded = try JSONEncoder().encode(data)
        } catch {
            throw StorageError.encodeFailed(underlying: error)
        }
        do {
            // Roll the current good file to backup before overwriting, so a
            // failed/corrupt write still leaves us one recoverable copy.
            let fm = FileManager.default
            if fm.fileExists(atPath: url.path) {
                try? fm.removeItem(at: backupURL)
                try? fm.copyItem(at: url, to: backupURL)
            }
            try encoded.write(to: url, options: .atomic)
        } catch {
            throw StorageError.writeFailed(underlying: error)
        }
    }

    // MARK: - Backup / portability

    func exportData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        do {
            return try encoder.encode(data)
        } catch {
            throw StorageError.encodeFailed(underlying: error)
        }
    }

    func importData(_ blob: Data) throws {
        guard let decoded = Self.decode(blob) else { throw StorageError.decodeFailed }
        data = decoded
        try save()
    }
}

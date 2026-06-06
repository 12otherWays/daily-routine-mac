import Foundation
import SwiftUI

private let PREFS_KEY = "routine:prefs"

// AppStore is the single integration point between the SwiftData persistence layer
// and the SwiftUI view tree. Views continue to use it as an `@EnvironmentObject`
// and read narrow data slices through dedicated accessors (`tasks(for:)`,
// `taskCounts(forDays:)` …) rather than touching the storage graph directly.
//
// RAM strategy:
//   • Templates and categories are small and read-heavy — kept fully in memory.
//   • Tasks are queried per visible day, cached in a small per-day dictionary,
//     and evicted on mutation. The full task table is never loaded except for
//     all-time statistics, which use a lightweight record projection.

@MainActor
final class AppStore: ObservableObject {

    // MARK: - UI state

    @Published var activeDay: String        = todayKey()
    @Published var viewMode: ViewMode       = .day
    @Published var drawerTaskId: String?    = nil
    @Published var settingsTab: SettingsTab? = nil
    @Published var templatePickerOpen: Bool = false
    @Published var calendarDrawerOpen: Bool = false
    @Published var isLoading: Bool          = true

    /// Non-nil whenever a persistence operation failed. The UI observes this and
    /// shows an alert so data-loss is never silent.
    @Published var lastError: String?       = nil

    // MARK: - Persisted, in-memory caches

    @Published private(set) var templates:  [RoutineTemplate] = []
    @Published private(set) var categories: [String]          = []
    @Published var prefs: Prefs = .default

    /// Per-day task cache. Populated lazily by `tasks(for:)`; cleared on writes.
    private var dayCache: [String: [RoutineTask]] = [:]
    /// Memoised stats projection. `nil` whenever the underlying data has changed
    /// since the last build; rebuilt on the next read.
    private var cachedStatsInput: StatsInput?
    /// Bumping this `@Published` value is what re-renders the views that depend on tasks.
    @Published private var dataVersion: Int = 0

    // MARK: - Dependencies

    private let repository: TaskRepository
    private var saveWorkItem: DispatchWorkItem?

    init(repository: TaskRepository) {
        self.repository = repository
    }

    // MARK: - Lifecycle

    /// Runs migration (first launch only) and warms the small in-memory caches.
    func bootstrap() {
        templates  = repository.templates()
        categories = repository.categories()
        loadPrefs()
        isLoading = false
    }

    private func loadPrefs() {
        guard
            let data = UserDefaults.standard.data(forKey: PREFS_KEY),
            let decoded = try? JSONDecoder().decode(Prefs.self, from: data)
        else { return }
        prefs = decoded
    }

    func savePrefs() {
        if let encoded = try? JSONEncoder().encode(prefs) {
            UserDefaults.standard.set(encoded, forKey: PREFS_KEY)
        }
    }

    // MARK: - Task reads (lazy, cached)

    func tasks(for day: String) -> [RoutineTask] {
        if let cached = dayCache[day] { return cached }
        let fetched = repository.tasks(forDay: day)
        dayCache[day] = fetched
        return fetched
    }

    func tasks(forDays days: [String]) -> [String: [RoutineTask]] {
        let missing = days.filter { dayCache[$0] == nil }
        if !missing.isEmpty {
            let fetched = repository.tasks(forDays: missing)
            for day in missing { dayCache[day] = fetched[day] ?? [] }
        }
        var result: [String: [RoutineTask]] = [:]
        result.reserveCapacity(days.count)
        for day in days { result[day] = dayCache[day] ?? [] }
        return result
    }

    func taskCount(for day: String) -> Int {
        tasks(for: day).count
    }

    func taskCounts(forDays days: [String]) -> [String: (done: Int, total: Int)] {
        // Build counts from cache where possible; only hit the repository for
        // days that haven't been materialised yet.
        var counts: [String: (done: Int, total: Int)] = [:]
        var missing: [String] = []
        for day in days {
            if let cached = dayCache[day] {
                counts[day] = (cached.filter(\.done).count, cached.count)
            } else {
                missing.append(day)
            }
        }
        if !missing.isEmpty {
            let fetched = repository.taskCounts(forDays: missing)
            for day in missing { counts[day] = fetched[day] ?? (0, 0) }
        }
        return counts
    }

    /// Set of days that contain at least one task. Cheap projection for
    /// year-view dot indicators in the calendar drawer.
    func daysWithTasks() -> Set<String> {
        repository.allDayKeysWithTasks()
    }

    /// Memoised stats input used by Header (streak badge) and Stats view.
    /// Built from a lightweight `TaskRecord` projection, not full DTOs.
    func statsInput() -> StatsInput {
        if let cached = cachedStatsInput { return cached }
        let input = StatsInput(repository.allRecords())
        cachedStatsInput = input
        return input
    }

    // MARK: - Task writes
    //
    // SwiftData row writes are sub-millisecond, so we save synchronously after
    // every structural mutation. That guarantees a later read (which may use
    // a `#Predicate`) sees the change rather than a stale snapshot. We still
    // debounce text edits inside `updateTask` to coalesce keystroke saves.

    func toggleDone(_ taskId: String, for day: String) {
        perform {
            try repository.toggleDone(id: taskId)
            try repository.save()
        }
        invalidate(day: day)
    }

    func updateTask(_ task: RoutineTask, for day: String) {
        perform { try repository.updateTask(task) }
        invalidate(day: day)
        scheduleSave()
    }

    func addBlankTask(to day: String) {
        perform {
            try repository.insertTask(RoutineTask(), day: day)
            try repository.save()
        }
        invalidate(day: day)
    }

    func addTasksFromTemplate(_ template: RoutineTemplate, to day: String) {
        perform {
            for task in template.tasks {
                try repository.insertTask(task.toTask(), day: day)
            }
            try repository.save()
        }
        invalidate(day: day)
    }

    func saveCurrentDayAsTemplate(name: String) {
        let templateTasks = tasks(for: activeDay).map {
            TemplateTask(name: $0.name, description: $0.description, priority: $0.priority, category: $0.category)
        }
        let template = RoutineTemplate(name: name.trimmingCharacters(in: .whitespaces), tasks: templateTasks)
        perform { try repository.insertTemplate(template) }
        templates = repository.templates()
        scheduleSave()
    }

    func deleteTask(_ taskId: String, from day: String) {
        perform {
            try repository.deleteTask(id: taskId)
            try repository.save()
        }
        invalidate(day: day)
    }

    func reorderTasks(in day: String, from offsets: IndexSet, to destination: Int) {
        perform {
            try repository.reorderTasks(day: day, fromOffsets: offsets, to: destination)
            try repository.save()
        }
        invalidate(day: day)
    }

    // MARK: - Template writes

    func addTemplate(_ template: RoutineTemplate) {
        perform { try repository.insertTemplate(template) }
        templates = repository.templates()
        scheduleSave()
    }

    func updateTemplate(_ template: RoutineTemplate) {
        perform { try repository.updateTemplate(template) }
        templates = repository.templates()
        scheduleSave()
    }

    func deleteTemplate(id: String) {
        perform { try repository.deleteTemplate(id: id) }
        templates = repository.templates()
        scheduleSave()
    }

    // MARK: - Category writes

    func addCategory(_ name: String) {
        perform { try repository.addCategory(name) }
        categories = repository.categories()
        scheduleSave()
    }

    func deleteCategory(_ name: String) {
        perform { try repository.deleteCategory(name) }
        categories = repository.categories()
        scheduleSave()
    }

    // MARK: - Backup / portability

    /// Pretty-printed JSON snapshot for "Export Data…". Returns nil on failure
    /// (and records the error for the UI).
    func exportSnapshot() -> Data? {
        do {
            return try repository.exportData()
        } catch {
            recordError(error)
            return nil
        }
    }

    /// Replaces all data from an imported snapshot, then refreshes every cache so
    /// the UI reflects the new dataset immediately.
    func importSnapshot(_ data: Data) {
        perform { try repository.importData(data) }
        guard lastError == nil else { return }
        dayCache.removeAll()
        cachedStatsInput = nil
        templates  = repository.templates()
        categories = repository.categories()
        dataVersion &+= 1
    }

    // MARK: - Navigation

    func goPrev() {
        switch viewMode {
        case .day:
            activeDay = prevDay(activeDay)
        case .week:
            let week = getWeekDays(for: activeDay)
            if let mon = week.first { activeDay = prevDay(mon) }
        case .month:
            let d = date(from: activeDay)
            if let prev = Calendar.current.date(byAdding: .month, value: -1, to: d) {
                activeDay = dateKey(from: prev)
            }
        case .stats:
            break
        }
    }

    func goNext() {
        switch viewMode {
        case .day:
            activeDay = nextDay(activeDay)
        case .week:
            let week = getWeekDays(for: activeDay)
            if let sun = week.last { activeDay = nextDay(sun) }
        case .month:
            let d = date(from: activeDay)
            if let next = Calendar.current.date(byAdding: .month, value: 1, to: d) {
                activeDay = dateKey(from: next)
            }
        case .stats:
            break
        }
    }

    // MARK: - Internal helpers

    private func invalidate(day: String) {
        dayCache.removeValue(forKey: day)
        cachedStatsInput = nil
        // Mutating a @Published value is what fires `objectWillChange` and
        // re-renders every view subscribing to this store.
        dataVersion &+= 1
    }

    private func scheduleSave() {
        saveWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.perform { try self.repository.save() }
        }
        saveWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: item)
    }

    /// Flushes any pending debounced save synchronously. Called on app
    /// termination so an edit typed within the 250ms debounce window before
    /// quitting is never lost.
    func flushPendingSave() {
        guard saveWorkItem != nil else { return }
        saveWorkItem?.cancel()
        saveWorkItem = nil
        perform { try repository.save() }
    }

    /// Runs a throwing persistence op, surfacing any failure to `lastError`
    /// instead of silently dropping it.
    private func perform(_ op: () throws -> Void) {
        do {
            try op()
        } catch {
            recordError(error)
        }
    }

    private func recordError(_ error: Error) {
        lastError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }
}

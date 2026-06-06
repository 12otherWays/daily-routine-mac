import XCTest
@testable import DailyRoutineApp

@MainActor
final class FileTaskRepositoryTests: XCTestCase {

    private var dir: URL!

    override func setUp() {
        super.setUp()
        dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("DRTests-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: dir)
        super.tearDown()
    }

    func testFreshInstallSeedsDefaults() {
        let repo = FileTaskRepository(directory: dir)
        XCTAssertFalse(repo.categories().isEmpty)
        XCTAssertFalse(repo.templates().isEmpty)
    }

    func testInsertAndPersistRoundTrips() throws {
        let repo = FileTaskRepository(directory: dir)
        try repo.insertTask(RoutineTask(id: "t1", name: "Run"), day: "2026-06-06")
        try repo.save()

        // A fresh repo pointed at the same directory must see the saved task.
        let reopened = FileTaskRepository(directory: dir)
        let tasks = reopened.tasks(forDay: "2026-06-06")
        XCTAssertEqual(tasks.count, 1)
        XCTAssertEqual(tasks.first?.name, "Run")
    }

    func testToggleAndDeletePersist() throws {
        let repo = FileTaskRepository(directory: dir)
        try repo.insertTask(RoutineTask(id: "t1", name: "Run"), day: "2026-06-06")
        try repo.toggleDone(id: "t1")
        try repo.save()
        XCTAssertEqual(FileTaskRepository(directory: dir).tasks(forDay: "2026-06-06").first?.done, true)

        try repo.deleteTask(id: "t1")
        try repo.save()
        XCTAssertTrue(FileTaskRepository(directory: dir).tasks(forDay: "2026-06-06").isEmpty)
    }

    func testExportImportRoundTrip() throws {
        let repo = FileTaskRepository(directory: dir)
        try repo.insertTask(RoutineTask(id: "t1", name: "Meditate"), day: "2026-06-06")
        try repo.save()
        let snapshot = try repo.exportData()

        // Import into a separate, fresh store and confirm the data transfers.
        let other = FileTaskRepository(directory: dir.appendingPathComponent("other"))
        try other.importData(snapshot)
        XCTAssertEqual(other.tasks(forDay: "2026-06-06").first?.name, "Meditate")
    }

    func testImportRejectsGarbage() {
        let repo = FileTaskRepository(directory: dir)
        XCTAssertThrowsError(try repo.importData(Data("not json".utf8)))
    }

    func testRecoversFromCorruptPrimaryUsingBackup() throws {
        let repo = FileTaskRepository(directory: dir)
        try repo.insertTask(RoutineTask(id: "t1", name: "Keep me"), day: "2026-06-06")
        try repo.save() // writes primary
        try repo.insertTask(RoutineTask(id: "t2", name: "And me"), day: "2026-06-07")
        try repo.save() // rolls previous primary -> backup, writes new primary

        // Corrupt the primary file on disk.
        let primary = dir.appendingPathComponent("routine.json")
        try Data("corrupt".utf8).write(to: primary)

        // Reopening should fall back to the backup (which still has t1).
        let recovered = FileTaskRepository(directory: dir)
        XCTAssertEqual(recovered.tasks(forDay: "2026-06-06").first?.name, "Keep me")
    }

    func testMigratesLegacyV1Templates() throws {
        // v1 stored templates as flat single-task records (no `tasks` array).
        let legacyJSON = """
        {
          "days": {},
          "templates": [
            { "id": "old1", "name": "Stretch", "description": "5 min", "priority": "low", "category": "Health" }
          ],
          "categories": ["Health"]
        }
        """
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try Data(legacyJSON.utf8).write(to: dir.appendingPathComponent("routine.json"))

        let repo = FileTaskRepository(directory: dir)
        let templates = repo.templates()
        XCTAssertEqual(templates.count, 1)
        XCTAssertEqual(templates.first?.name, "Stretch")
        // The flat record becomes a group containing exactly one task.
        XCTAssertEqual(templates.first?.tasks.count, 1)
        XCTAssertEqual(templates.first?.tasks.first?.category, "Health")
    }
}

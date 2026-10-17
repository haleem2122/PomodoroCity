import XCTest
@testable import PomodoroCity

/// These tests pin down the behaviour that must survive the redesign:
/// costs, rewards, district unlocks, placement rules and save-file compatibility.
final class GameLogicTests: XCTestCase {

    func testStarterResourcesAndBuildings() {
        let s = GameState()
        XCTAssertEqual(s.resources, Resources(wood: 10, stone: 6, metal: 2))
        XCTAssertEqual(s.buildings.count, 8)
        XCTAssertEqual(s.buildings.filter { $0.type == .townHall }.count, 1)
        XCTAssertEqual(s.settings.focusDurationMinutes, 25)
        XCTAssertEqual(s.settings.breakDurationMinutes, 5)
    }

    func testBuildingCostsAreUnchanged() {
        let expected: [BuildingType: (Int, Int, Int)] = [
            .townHall: (0, 0, 0), .cottage: (4, 2, 0), .garden: (2, 1, 0), .park: (3, 2, 0),
            .road: (0, 1, 0), .fountain: (3, 3, 1), .windmill: (5, 3, 1), .library: (6, 5, 1),
            .workshop: (5, 4, 2), .university: (8, 8, 4),
        ]
        XCTAssertEqual(expected.count, BuildingType.allCases.count)
        for (type, c) in expected {
            XCTAssertEqual(type.cost, Resources(wood: c.0, stone: c.1, metal: c.2), "\(type)")
        }
    }

    func testBuildingBonuses() {
        XCTAssertNil(BuildingType.library.bonusForBlock(currentBlock: 3, placedAtBlock: 0))
        XCTAssertEqual(BuildingType.library.bonusForBlock(currentBlock: 4, placedAtBlock: 0), Resources(stone: 1))
        XCTAssertEqual(BuildingType.workshop.bonusForBlock(currentBlock: 6, placedAtBlock: 3), Resources(wood: 1))
        XCTAssertEqual(BuildingType.university.bonusForBlock(currentBlock: 18, placedAtBlock: 10), Resources(metal: 1))
        XCTAssertNil(BuildingType.cottage.bonusForBlock(currentBlock: 4, placedAtBlock: 0))
        XCTAssertNil(BuildingType.library.bonusForBlock(currentBlock: 4, placedAtBlock: 4))
    }

    func testResourceMath() {
        var r = Resources(wood: 5, stone: 2, metal: 0)
        XCTAssertTrue(r.canAfford(Resources(wood: 5, stone: 2, metal: 0)))
        XCTAssertFalse(r.canAfford(Resources(wood: 0, stone: 0, metal: 1)))
        r.deduct(Resources(wood: 4, stone: 2, metal: 0))
        XCTAssertEqual(r, Resources(wood: 1, stone: 0, metal: 0))
        r.add(Resources(wood: 2, stone: 1, metal: 1))
        XCTAssertEqual(r, Resources(wood: 3, stone: 1, metal: 1))
    }

    func testDistrictUnlockThresholds() {
        XCTAssertTrue(DistrictID.startingVillage.isUnlocked(lifetimeHours: 0))
        XCTAssertFalse(DistrictID.forestEdge.isUnlocked(lifetimeHours: 4.99))
        XCTAssertTrue(DistrictID.forestEdge.isUnlocked(lifetimeHours: 5))
        XCTAssertFalse(DistrictID.riverbank.isUnlocked(lifetimeHours: 14.99))
        XCTAssertTrue(DistrictID.riverbank.isUnlocked(lifetimeHours: 15))
        XCTAssertEqual(DistrictID.district(forX: 0, y: 0), .startingVillage)
        XCTAssertEqual(DistrictID.district(forX: 8, y: 0), .forestEdge)
        XCTAssertEqual(DistrictID.district(forX: 15, y: 15), .riverbank)
        XCTAssertNil(DistrictID.district(forX: 16, y: 0))
    }

    func testPlacementRules() {
        var s = GameState()
        XCTAssertTrue(s.canPlace(atX: 0, y: 0))
        XCTAssertFalse(s.canPlace(atX: 3, y: 3), "occupied by town hall")
        XCTAssertFalse(s.canPlace(atX: 9, y: 0), "forest edge locked")
        XCTAssertFalse(s.canPlace(atX: 0, y: 9), "riverbank locked")
        s.totalLifetimeFocusSeconds = 5 * 3600
        XCTAssertTrue(s.canPlace(atX: 9, y: 0))
        XCTAssertFalse(s.canPlace(atX: 0, y: 9))
    }

    func testSaveFileCompatibility() throws {
        // A save written by the ORIGINAL app version. Must keep decoding forever.
        let json = """
        {"version":1,"resources":{"wood":7,"stone":3,"metal":1},
         "buildings":[{"id":"11111111-1111-1111-1111-111111111111","type":"townHall","gridX":3,"gridY":3,"placedAtFocusBlocks":0},
                      {"id":"22222222-2222-2222-2222-222222222222","type":"library","gridX":5,"gridY":5,"placedAtFocusBlocks":4}],
         "completedFocusSeconds":4500,"completedFocusBlocks":3,"totalLifetimeFocusSeconds":4500,
         "sessionHistory":[{"id":"33333333-3333-3333-3333-333333333333","type":"focus","startTime":"2026-10-01T09:00:00Z","endTime":"2026-10-01T09:25:00Z","durationSeconds":1500}],
         "currentStreakDays":2,"bestStreakDays":5,"lastFocusDate":"2026-10-01","milestonesUnlocked":[3],
         "settings":{"focusDurationMinutes":50,"breakDurationMinutes":10,"eveningReminderEnabled":false,
                     "eveningReminderHour":21,"eveningReminderMinute":30,"soundEnabled":false}}
        """
        let dec = JSONDecoder(); dec.dateDecodingStrategy = .iso8601
        let s = try dec.decode(GameState.self, from: Data(json.utf8))
        XCTAssertEqual(s.resources, Resources(wood: 7, stone: 3, metal: 1))
        XCTAssertEqual(s.buildings.map(\.type), [.townHall, .library])
        XCTAssertEqual(s.completedFocusBlocks, 3)
        XCTAssertEqual(s.sessionHistory.count, 1)
        XCTAssertEqual(s.currentStreakDays, 2)
        XCTAssertEqual(s.bestStreakDays, 5)
        XCTAssertEqual(s.milestonesUnlocked, [3])
        XCTAssertEqual(s.settings.focusDurationMinutes, 50)
        XCTAssertFalse(s.settings.soundEnabled)
    }

    func testSaveManagerRoundTripAndBackupRecovery() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("pc-\(UUID().uuidString)")
        let old = SaveManager.shared.customBaseDirectory
        SaveManager.shared.customBaseDirectory = dir
        defer { SaveManager.shared.customBaseDirectory = old; try? FileManager.default.removeItem(at: dir) }

        var s = GameState(); s.resources.wood = 42; s.currentStreakDays = 4
        try SaveManager.shared.save(state: s)
        XCTAssertEqual(try SaveManager.shared.load().resources.wood, 42)

        s.resources.wood = 43
        try SaveManager.shared.save(state: s)           // first save becomes the backup
        try Data("not json".utf8).write(to: SaveManager.shared.saveFileURL)
        XCTAssertEqual(try SaveManager.shared.load().resources.wood, 42, "falls back to backup, never wipes")
    }
}

@MainActor
final class TimerManagerTests: XCTestCase {
    private var dir: URL!
    private var old: URL?

    override func setUp() {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("pc-\(UUID().uuidString)")
        old = SaveManager.shared.customBaseDirectory
        SaveManager.shared.customBaseDirectory = dir
    }
    override func tearDown() {
        SaveManager.shared.customBaseDirectory = old
        try? FileManager.default.removeItem(at: dir)
    }

    func testPlaceBuildingChargesCostAndPersists() throws {
        let t = TimerManager()
        XCTAssertTrue(t.placeBuilding(type: .cottage, atX: 0, y: 0))
        XCTAssertEqual(t.gameState.resources, Resources(wood: 6, stone: 4, metal: 2))
        XCTAssertEqual(try SaveManager.shared.load().buildings.count, 9)
    }

    func testPlaceRejectsUnaffordableOccupiedAndLocked() {
        let t = TimerManager()
        XCTAssertFalse(t.placeBuilding(type: .university, atX: 0, y: 0), "cannot afford")
        XCTAssertFalse(t.placeBuilding(type: .road, atX: 3, y: 3), "occupied")
        XCTAssertFalse(t.placeBuilding(type: .road, atX: 9, y: 0), "locked district")
        XCTAssertEqual(t.gameState.resources, Resources(wood: 10, stone: 6, metal: 2))
    }

    func testMoveIsFreeAndTownHallIsPermanent() {
        let t = TimerManager()
        let cottage = t.gameState.buildings.first { $0.type == .cottage }!
        let before = t.gameState.resources
        XCTAssertTrue(t.moveBuilding(buildingID: cottage.id, toX: 0, y: 0))
        XCTAssertEqual(t.gameState.resources, before)
        let hall = t.gameState.buildings.first { $0.type == .townHall }!
        XCTAssertFalse(t.removeBuilding(buildingID: hall.id))
        XCTAssertTrue(t.removeBuilding(buildingID: cottage.id))
    }

    func testTimerStateMachine() {
        let t = TimerManager()
        XCTAssertEqual(t.timerState, .idle)
        t.startFocus();  XCTAssertEqual(t.timerState, .runningFocus)
        t.pause();       XCTAssertEqual(t.timerState, .pausedFocus)
        t.resume();      XCTAssertEqual(t.timerState, .runningFocus)
        t.reset();       XCTAssertEqual(t.timerState, .idle)
        t.startBreak();  XCTAssertEqual(t.timerState, .runningBreak)
        t.reset()
    }
}

import Foundation

public struct AppSettings: Codable, Equatable {
    public var focusDurationMinutes: Int
    public var breakDurationMinutes: Int
    public var eveningReminderEnabled: Bool
    public var eveningReminderHour: Int
    public var eveningReminderMinute: Int
    public var soundEnabled: Bool

    public init(
        focusDurationMinutes: Int = 25,
        breakDurationMinutes: Int = 5,
        eveningReminderEnabled: Bool = true,
        eveningReminderHour: Int = 20,
        eveningReminderMinute: Int = 0,
        soundEnabled: Bool = true
    ) {
        self.focusDurationMinutes = focusDurationMinutes
        self.breakDurationMinutes = breakDurationMinutes
        self.eveningReminderEnabled = eveningReminderEnabled
        self.eveningReminderHour = eveningReminderHour
        self.eveningReminderMinute = eveningReminderMinute
        self.soundEnabled = soundEnabled
    }
}

public struct GameState: Codable, Equatable {
    public var version: Int
    public var resources: Resources
    public var buildings: [PlacedBuilding]
    public var completedFocusSeconds: TimeInterval
    public var completedFocusBlocks: Int
    public var totalLifetimeFocusSeconds: TimeInterval
    public var sessionHistory: [SessionRecord]
    public var currentStreakDays: Int
    public var bestStreakDays: Int
    public var lastFocusDate: String?
    public var milestonesUnlocked: [Int]
    public var settings: AppSettings

    public init(
        version: Int = 1,
        resources: Resources = Resources.starter,
        buildings: [PlacedBuilding] = GameState.defaultStarterBuildings(),
        completedFocusSeconds: TimeInterval = 0,
        completedFocusBlocks: Int = 0,
        totalLifetimeFocusSeconds: TimeInterval = 0,
        sessionHistory: [SessionRecord] = [],
        currentStreakDays: Int = 0,
        bestStreakDays: Int = 0,
        lastFocusDate: String? = nil,
        milestonesUnlocked: [Int] = [],
        settings: AppSettings = AppSettings()
    ) {
        self.version = version
        self.resources = resources
        self.buildings = buildings
        self.completedFocusSeconds = completedFocusSeconds
        self.completedFocusBlocks = completedFocusBlocks
        self.totalLifetimeFocusSeconds = totalLifetimeFocusSeconds
        self.sessionHistory = sessionHistory
        self.currentStreakDays = currentStreakDays
        self.bestStreakDays = bestStreakDays
        self.lastFocusDate = lastFocusDate
        self.milestonesUnlocked = milestonesUnlocked
        self.settings = settings
    }

    public static func defaultStarterBuildings() -> [PlacedBuilding] {
        return [
            // Permanent Town Hall at the center of Starting Village
            PlacedBuilding(type: .townHall, gridX: 3, gridY: 3, placedAtFocusBlocks: 0),
            // Two starter cottages
            PlacedBuilding(type: .cottage, gridX: 2, gridY: 4, placedAtFocusBlocks: 0),
            PlacedBuilding(type: .cottage, gridX: 4, gridY: 4, placedAtFocusBlocks: 0),
            // Short cobblestone road connecting the village center
            PlacedBuilding(type: .road, gridX: 3, gridY: 2, placedAtFocusBlocks: 0),
            PlacedBuilding(type: .road, gridX: 3, gridY: 4, placedAtFocusBlocks: 0),
            PlacedBuilding(type: .road, gridX: 3, gridY: 5, placedAtFocusBlocks: 0),
            // Starting garden and park scenery
            PlacedBuilding(type: .garden, gridX: 2, gridY: 2, placedAtFocusBlocks: 0),
            PlacedBuilding(type: .park, gridX: 4, gridY: 2, placedAtFocusBlocks: 0)
        ]
    }

    public var lifetimeFocusHours: Double {
        return totalLifetimeFocusSeconds / 3600.0
    }

    public var progressTowardNextBlock: Double {
        let blockTarget: TimeInterval = 25.0 * 60.0
        let remainder = completedFocusSeconds.truncatingRemainder(dividingBy: blockTarget)
        return remainder / blockTarget
    }

    public var secondsTowardNextBlock: TimeInterval {
        let blockTarget: TimeInterval = 25.0 * 60.0
        return completedFocusSeconds.truncatingRemainder(dividingBy: blockTarget)
    }

    /// Checks if a tile is occupied by an existing building.
    public func buildingAt(gridX: Int, gridY: Int) -> PlacedBuilding? {
        return buildings.first { $0.gridX == gridX && $0.gridY == gridY }
    }

    /// Checks if a tile is valid for building placement.
    public func canPlace(atX x: Int, y: Int, excludingBuildingID: UUID? = nil) -> Bool {
        guard let district = DistrictID.district(forX: x, y: y) else { return false }
        guard district.isUnlocked(lifetimeHours: lifetimeFocusHours) else { return false }

        // Check if another building already occupies this spot
        if let existing = buildingAt(gridX: x, gridY: y) {
            if let excluding = excludingBuildingID, existing.id == excluding {
                return true
            }
            return false
        }
        return true
    }
}

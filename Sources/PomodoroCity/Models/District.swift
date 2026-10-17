import Foundation

public enum DistrictID: String, Codable, CaseIterable, Identifiable {
    case startingVillage
    case forestEdge
    case riverbank

    public var id: String { rawValue }

    public var name: String {
        switch self {
        case .startingVillage: return "Starting Village"
        case .forestEdge: return "Forest Edge"
        case .riverbank: return "Riverbank"
        }
    }

    public var requiredLifetimeHours: Double {
        switch self {
        case .startingVillage: return 0.0
        case .forestEdge: return 5.0
        case .riverbank: return 15.0
        }
    }

    public var description: String {
        switch self {
        case .startingVillage:
            return "The cozy cradle of your town with the Town Hall and initial homes."
        case .forestEdge:
            return "Wooded glades and rich timberlands unlocked after 5 lifetime focus hours."
        case .riverbank:
            return "Fresh waterfront lands alongside the winding river, unlocked after 15 lifetime focus hours."
        }
    }

    /// Determines which district contains the given tile coordinate.
    public static func district(forX x: Int, y: Int) -> DistrictID? {
        if x >= 0 && x <= 7 && y >= 0 && y <= 7 {
            return .startingVillage
        } else if x >= 8 && x <= 15 && y >= 0 && y <= 7 {
            return .forestEdge
        } else if x >= 0 && x <= 15 && y >= 8 && y <= 15 {
            return .riverbank
        }
        return nil
    }

    public func isUnlocked(lifetimeHours: Double) -> Bool {
        return lifetimeHours >= requiredLifetimeHours
    }
}

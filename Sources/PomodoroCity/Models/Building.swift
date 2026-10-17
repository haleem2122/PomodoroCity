import Foundation

public enum BuildingType: String, Codable, CaseIterable, Identifiable {
    case townHall
    case cottage
    case garden
    case park
    case road
    case fountain
    case windmill
    case library
    case workshop
    case university

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .townHall: return "Town Hall"
        case .cottage: return "Cottage"
        case .garden: return "Garden"
        case .park: return "Park"
        case .road: return "Stone Road"
        case .fountain: return "Fountain"
        case .windmill: return "Windmill"
        case .library: return "Library"
        case .workshop: return "Workshop"
        case .university: return "University"
        }
    }

    public var description: String {
        switch self {
        case .townHall: return "Heart of your settlement. Permanent civic center."
        case .cottage: return "A cozy timber dwelling with a smoking chimney."
        case .garden: return "Lush flowerbeds and ornamental bushes."
        case .park: return "A serene green space with shady pine trees."
        case .road: return "Cobblestone pathway for easy travel."
        case .fountain: return "A refreshing stone water fountain."
        case .windmill: return "A graceful windmill turning slowly in the breeze."
        case .library: return "A quiet archive. Grants +1 Stone every 4 completed focus blocks."
        case .workshop: return "Crafting tools and timber. Grants +1 Wood every 3 completed focus blocks."
        case .university: return "Hall of higher learning. Grants +1 Metal every 8 completed focus blocks."
        }
    }

    public var isPermanent: Bool {
        return self == .townHall
    }

    public var cost: Resources {
        switch self {
        case .townHall: return Resources(wood: 0, stone: 0, metal: 0)
        case .cottage: return Resources(wood: 4, stone: 2, metal: 0)
        case .garden: return Resources(wood: 2, stone: 1, metal: 0)
        case .park: return Resources(wood: 3, stone: 2, metal: 0)
        case .road: return Resources(wood: 0, stone: 1, metal: 0)
        case .fountain: return Resources(wood: 3, stone: 3, metal: 1)
        case .windmill: return Resources(wood: 5, stone: 3, metal: 1)
        case .library: return Resources(wood: 6, stone: 5, metal: 1)
        case .workshop: return Resources(wood: 5, stone: 4, metal: 2)
        case .university: return Resources(wood: 8, stone: 8, metal: 4)
        }
    }

    public var bonusDescription: String? {
        switch self {
        case .library: return "+1 Stone every 4 blocks"
        case .workshop: return "+1 Wood every 3 blocks"
        case .university: return "+1 Metal every 8 blocks"
        default: return nil
        }
    }

    /// Evaluates any bonus produced for a specific completed global focus block.
    /// `placedAtBlock` is the total focus blocks completed when this building was constructed.
    public func bonusForBlock(currentBlock: Int, placedAtBlock: Int) -> Resources? {
        guard currentBlock > placedAtBlock else { return nil }
        let blocksSinceConstruction = currentBlock - placedAtBlock

        switch self {
        case .library:
            if blocksSinceConstruction % 4 == 0 {
                return Resources(wood: 0, stone: 1, metal: 0)
            }
        case .workshop:
            if blocksSinceConstruction % 3 == 0 {
                return Resources(wood: 1, stone: 0, metal: 0)
            }
        case .university:
            if blocksSinceConstruction % 8 == 0 {
                return Resources(wood: 0, stone: 0, metal: 1)
            }
        default:
            return nil
        }
        return nil
    }

    public var iconName: String {
        switch self {
        case .townHall: return "building.columns.fill"
        case .cottage: return "house.fill"
        case .garden: return "leaf.fill"
        case .park: return "tree.fill"
        case .road: return "point.topleft.down.curvedto.point.bottomright.up"
        case .fountain: return "drop.fill"
        case .windmill: return "wind"
        case .library: return "books.vertical.fill"
        case .workshop: return "hammer.fill"
        case .university: return "graduationcap.fill"
        }
    }
}

public struct PlacedBuilding: Codable, Identifiable, Equatable {
    public var id: UUID
    public var type: BuildingType
    public var gridX: Int
    public var gridY: Int
    public var placedAtFocusBlocks: Int

    public init(id: UUID = UUID(), type: BuildingType, gridX: Int, gridY: Int, placedAtFocusBlocks: Int) {
        self.id = id
        self.type = type
        self.gridX = gridX
        self.gridY = gridY
        self.placedAtFocusBlocks = placedAtFocusBlocks
    }
}

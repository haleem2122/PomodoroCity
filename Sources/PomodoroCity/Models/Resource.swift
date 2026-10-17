import Foundation

public struct Resources: Codable, Equatable {
    public var wood: Int
    public var stone: Int
    public var metal: Int

    public init(wood: Int = 0, stone: Int = 0, metal: Int = 0) {
        self.wood = wood
        self.stone = stone
        self.metal = metal
    }

    public static let starter = Resources(wood: 10, stone: 6, metal: 2)

    public func canAfford(_ cost: Resources) -> Bool {
        return wood >= cost.wood && stone >= cost.stone && metal >= cost.metal
    }

    public mutating func deduct(_ cost: Resources) {
        wood = max(0, wood - cost.wood)
        stone = max(0, stone - cost.stone)
        metal = max(0, metal - cost.metal)
    }

    public mutating func add(_ addition: Resources) {
        wood += addition.wood
        stone += addition.stone
        metal += addition.metal
    }
}

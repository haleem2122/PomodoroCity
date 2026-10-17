import SwiftUI

public struct BuildingCatalogueView: View {
    @ObservedObject var timerManager: TimerManager
    @Binding var selectedBuildingType: BuildingType?

    public init(timerManager: TimerManager, selectedBuildingType: Binding<BuildingType?>) {
        self.timerManager = timerManager
        self._selectedBuildingType = selectedBuildingType
    }

    // Filter out Town Hall since it is a starter permanent building
    private var availableBuildings: [BuildingType] {
        return BuildingType.allCases.filter { !$0.isPermanent }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Building Catalogue")
                    .font(.system(size: 14, weight: .bold))
                Spacer()
                if selectedBuildingType != nil {
                    Button(action: {
                        selectedBuildingType = nil
                    }) {
                        Text("Cancel Placement")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.bordered)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(availableBuildings) { building in
                        BuildingCard(
                            type: building,
                            canAfford: timerManager.gameState.resources.canAfford(building.cost),
                            isSelected: selectedBuildingType == building,
                            onSelect: {
                                if selectedBuildingType == building {
                                    selectedBuildingType = nil
                                } else {
                                    selectedBuildingType = building
                                }
                            }
                        )
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .windowBackgroundColor).opacity(0.95))
                .shadow(color: Color.black.opacity(0.15), radius: 6, x: 0, y: 3)
        )
    }
}

private struct BuildingCard: View {
    let type: BuildingType
    let canAfford: Bool
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: type.iconName)
                        .font(.system(size: 14))
                        .foregroundColor(isSelected ? .yellow : .accentColor)
                    Text(type.displayName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.primary)
                }

                // Costs
                HStack(spacing: 6) {
                    if type.cost.wood > 0 {
                        Text("\(type.cost.wood)🪵")
                            .font(.system(size: 10, weight: .medium))
                    }
                    if type.cost.stone > 0 {
                        Text("\(type.cost.stone)🪨")
                            .font(.system(size: 10, weight: .medium))
                    }
                    if type.cost.metal > 0 {
                        Text("\(type.cost.metal)⚙️")
                            .font(.system(size: 10, weight: .medium))
                    }
                }

                // Bonus or function badge
                if let bonus = type.bonusDescription {
                    Text(bonus)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.green)
                        .lineLimit(1)
                } else {
                    Text("Decorative")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 130, height: 74)
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor.opacity(0.2) : Color(nsColor: .controlBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(
                                isSelected ? Color.accentColor : (canAfford ? Color.secondary.opacity(0.3) : Color.red.opacity(0.3)),
                                lineWidth: isSelected ? 2 : 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
        .opacity(canAfford ? 1.0 : 0.6)
    }
}

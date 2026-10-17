import SwiftUI

public struct BuildingCatalogueView: View {
    @ObservedObject var timerManager: TimerManager
    @Binding var selectedBuildingType: BuildingType?

    public init(timerManager: TimerManager, selectedBuildingType: Binding<BuildingType?>) {
        self.timerManager = timerManager
        self._selectedBuildingType = selectedBuildingType
    }

    // Town Hall is a permanent starter building, so it is not offered for construction
    private var availableBuildings: [BuildingType] {
        return BuildingType.allCases.filter { !$0.isPermanent }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Building catalogue")
                    .font(Theme.serif(16, .medium))
                    .foregroundColor(Theme.ink)
                Spacer()
                if selectedBuildingType != nil {
                    Button(action: { selectedBuildingType = nil }) {
                        Text("Cancel placement")
                    }
                    .buttonStyle(SmallButtonStyle())
                } else {
                    Text("Choose a building, then click a green plot")
                        .font(Theme.sans(12))
                        .foregroundColor(Theme.muted)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
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
                .padding(.vertical, 2)
                .padding(.horizontal, 1)
            }
        }
        .themedCard(padding: 14, radius: 14)
        .shadow(color: Color.black.opacity(0.12), radius: 12, x: 0, y: 4)
    }
}

private struct BuildingCard: View {
    let type: BuildingType
    let canAfford: Bool
    let isSelected: Bool
    let onSelect: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 8) {
                    Image(systemName: type.iconName)
                        .font(.system(size: 13))
                        .foregroundColor(Theme.sageDeep)
                        .frame(width: 26, height: 26)
                        .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Theme.sageSoft))
                    Text(type.displayName)
                        .font(Theme.sans(12.5, .semibold))
                        .foregroundColor(Theme.ink)
                        .lineLimit(1)
                }

                CostLabel(cost: type.cost)

                if let bonus = type.bonusDescription {
                    Text(bonus)
                        .font(Theme.sans(10.5, .medium))
                        .foregroundColor(Theme.sageDeep)
                        .lineLimit(1)
                } else {
                    Text("Decorative")
                        .font(Theme.sans(10.5))
                        .foregroundColor(Theme.muted)
                }
            }
            .frame(width: 142, alignment: .leading)
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? Theme.sageSoft : (hovering ? Theme.surface : Theme.raised))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isSelected ? Theme.sage : (canAfford ? Theme.line : Theme.danger.opacity(0.35)), lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
        .opacity(canAfford ? 1.0 : 0.55)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.12), value: hovering)
        .help(canAfford ? type.description : "Not enough resources. \(type.description)")
    }
}

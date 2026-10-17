import SwiftUI
import SpriteKit

public struct CityView: View {
    @ObservedObject var timerManager: TimerManager

    @State private var scene: CityScene = {
        let s = CityScene()
        s.scaleMode = .resizeFill
        return s
    }()

    @State private var isConstructionMode: Bool = false
    @State private var selectedBuildingType: BuildingType? = nil
    @State private var selectedTileInfo: (x: Int, y: Int, building: PlacedBuilding?)? = nil
    @State private var bannerMessage: String? = nil

    public init(timerManager: TimerManager) {
        self.timerManager = timerManager
    }

    public var body: some View {
        ZStack {
            // SpriteKit interactive canvas
            SpriteView(scene: scene)
                .ignoresSafeArea()

            VStack(spacing: 10) {
                // Top bar: resources on the left, tools on the right
                HStack(alignment: .center, spacing: 10) {
                    ResourceBar(timerManager: timerManager)

                    Spacer()

                    Button(action: toggleConstructionMode) {
                        HStack(spacing: 6) {
                            Image(systemName: isConstructionMode ? "checkmark" : "hammer")
                                .font(.system(size: 12, weight: .semibold))
                            Text(isConstructionMode ? "Done building" : "Build")
                        }
                    }
                    .buttonStyle(SmallButtonStyle(prominent: isConstructionMode))

                    HStack(spacing: 0) {
                        ToolButton(icon: "plus", help: "Zoom in") { scene.zoomIn() }
                        Rectangle().fill(Theme.line).frame(width: 1, height: 16)
                        ToolButton(icon: "minus", help: "Zoom out") { scene.zoomOut() }
                        Rectangle().fill(Theme.line).frame(width: 1, height: 16)
                        ToolButton(icon: "scope", help: "Reset view") { scene.resetView() }
                    }
                    .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Theme.raised))
                    .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Theme.line, lineWidth: 1))
                }
                .padding(.horizontal, 20)
                .padding(.top, 34)

                // Temporary banner message
                if let msg = bannerMessage {
                    Text(msg)
                        .font(Theme.sans(12.5, .medium))
                        .foregroundColor(Theme.ink)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(Theme.raised))
                        .overlay(Capsule().stroke(Theme.line, lineWidth: 1))
                        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 3)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                Spacer()

                // Inspector card for the selected building
                if let info = selectedTileInfo, let building = info.building {
                    BuildingInspectorCard(
                        building: building,
                        onMove: {
                            if !isConstructionMode {
                                isConstructionMode = true
                                scene.isConstructionMode = true
                            }
                            scene.selectedBuildingToMove = building
                            showMessage("Select any green empty plot to move '\(building.type.displayName)' for free.")
                        },
                        onDemolish: {
                            _ = timerManager.removeBuilding(buildingID: building.id)
                            selectedTileInfo = nil
                            scene.updateState(timerManager.gameState)
                            showMessage("Removed '\(building.type.displayName)'.")
                        },
                        onClose: {
                            selectedTileInfo = nil
                        }
                    )
                    .padding(.horizontal, 20)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                // Building catalogue (construction mode)
                if isConstructionMode {
                    BuildingCatalogueView(
                        timerManager: timerManager,
                        selectedBuildingType: $selectedBuildingType
                    )
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
                    Color.clear.frame(height: 6)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: isConstructionMode)
            .animation(.easeInOut(duration: 0.2), value: selectedTileInfo?.building?.id)
        }
        .onAppear {
            scene.onSelectTile = { x, y, b in
                self.didSelectTile(x: x, y: y, building: b)
            }
            scene.onRequestPlace = { type, x, y in
                self.didRequestPlace(type: type, x: x, y: y)
            }
            scene.onRequestMove = { id, x, y in
                self.didRequestMove(buildingID: id, toX: x, toY: y)
            }
            scene.updateState(timerManager.gameState)
        }
        .onChange(of: timerManager.gameState) { _, newState in
            scene.updateState(newState)
        }
        .onChange(of: selectedBuildingType) { _, newType in
            scene.selectedBuildingTypeToPlace = newType
            if let type = newType {
                showMessage("Click on any highlighted green plot to place \(type.displayName).")
            }
        }
    }

    // MARK: - Actions

    private func toggleConstructionMode() {
        isConstructionMode.toggle()
        scene.isConstructionMode = isConstructionMode
        selectedBuildingType = nil
        scene.selectedBuildingTypeToPlace = nil
        scene.selectedBuildingToMove = nil
        if isConstructionMode {
            showMessage("Build mode on: pick from the catalogue to place, or click a building to move it.")
        } else {
            showMessage("Build mode off: pan and zoom freely, click buildings to inspect.")
        }
    }

    public func didSelectTile(x: Int, y: Int, building: PlacedBuilding?) {
        selectedTileInfo = (x: x, y: y, building: building)
    }

    public func didRequestPlace(type: BuildingType, x: Int, y: Int) {
        if timerManager.placeBuilding(type: type, atX: x, y: y) {
            scene.updateState(timerManager.gameState)
            selectedBuildingType = nil
            scene.selectedBuildingTypeToPlace = nil
            showMessage("Constructed \(type.displayName)!")
        } else {
            showMessage("Cannot place here or not enough resources!")
        }
    }

    public func didRequestMove(buildingID: UUID, toX: Int, toY: Int) {
        if timerManager.moveBuilding(buildingID: buildingID, toX: toX, y: toY) {
            scene.updateState(timerManager.gameState)
            showMessage("Moved building successfully!")
        } else {
            showMessage("Cannot move to that location!")
        }
    }

    private func showMessage(_ text: String) {
        withAnimation {
            bannerMessage = text
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            if bannerMessage == text {
                withAnimation {
                    bannerMessage = nil
                }
            }
        }
    }
}

private struct ToolButton: View {
    let icon: String
    let help: String
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(hovering ? Theme.sageDeep : Theme.ink)
                .frame(width: 32, height: 30)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
        .onHover { hovering = $0 }
    }
}

private struct BuildingInspectorCard: View {
    let building: PlacedBuilding
    let onMove: () -> Void
    let onDemolish: () -> Void
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: building.type.iconName)
                .font(.system(size: 20))
                .foregroundColor(Theme.sageDeep)
                .frame(width: 44, height: 44)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Theme.sageSoft))

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(building.type.displayName)
                        .font(Theme.serif(16, .medium))
                        .foregroundColor(Theme.ink)
                    if building.type.isPermanent {
                        Text("Permanent")
                            .font(Theme.sans(10.5, .semibold))
                            .foregroundColor(Theme.sageDeep)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(Theme.sageSoft))
                    }
                }

                Text(building.type.description)
                    .font(Theme.sans(12))
                    .foregroundColor(Theme.muted)

                if let bonus = building.type.bonusDescription {
                    Text("Bonus: \(bonus) (active)")
                        .font(Theme.sans(11.5, .semibold))
                        .foregroundColor(Theme.sageDeep)
                }
            }

            Spacer()

            // Moving is always free and never charges resources
            Button(action: onMove) {
                Label("Move (free)", systemImage: "arrow.up.and.down.and.arrow.left.and.right")
            }
            .buttonStyle(SmallButtonStyle())

            if !building.type.isPermanent {
                Button(action: onDemolish) {
                    Image(systemName: "trash")
                }
                .buttonStyle(SmallButtonStyle(destructive: true))
                .help("Demolish")
            }

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Theme.muted)
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
        }
        .themedCard(padding: 12)
        .shadow(color: Color.black.opacity(0.12), radius: 10, x: 0, y: 4)
    }
}

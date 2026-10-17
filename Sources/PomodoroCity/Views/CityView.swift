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
            // SpriteKit Interactive Canvas
            SpriteView(scene: scene)
                .ignoresSafeArea()

            // Top Header: Resource Bar & Controls
            VStack(spacing: 8) {
                HStack {
                    ResourceBar(timerManager: timerManager)

                    Spacer()

                    // Construction Mode Toggle Button
                    Button(action: {
                        isConstructionMode.toggle()
                        scene.isConstructionMode = isConstructionMode
                        selectedBuildingType = nil
                        scene.selectedBuildingTypeToPlace = nil
                        scene.selectedBuildingToMove = nil
                        if isConstructionMode {
                            showMessage("Construction Mode ON: Click catalogue to place or click a building to move it.")
                        } else {
                            showMessage("Normal Mode: Pan & zoom freely. Click buildings to inspect.")
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: isConstructionMode ? "hammer.circle.fill" : "hammer.circle")
                                .font(.system(size: 15))
                            Text(isConstructionMode ? "Done Building" : "Build Mode")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(isConstructionMode ? Color.orange : Color(nsColor: .windowBackgroundColor).opacity(0.85))
                        .foregroundColor(isConstructionMode ? .white : .primary)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)

                    // Zoom Controls
                    HStack(spacing: 4) {
                        Button(action: { scene.zoomIn() }) {
                            Image(systemName: "plus.magnifyingglass")
                                .frame(width: 28, height: 28)
                        }
                        Button(action: { scene.zoomOut() }) {
                            Image(systemName: "minus.magnifyingglass")
                                .frame(width: 28, height: 28)
                        }
                        Button(action: { scene.resetView() }) {
                            Image(systemName: "arrow.counterclockwise")
                                .frame(width: 28, height: 28)
                        }
                    }
                    .padding(4)
                    .background(Color(nsColor: .windowBackgroundColor).opacity(0.85))
                    .cornerRadius(8)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)

                // Temporary Banner Message
                if let msg = bannerMessage {
                    Text(msg)
                        .font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color.black.opacity(0.75))
                        )
                        .foregroundColor(.white)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                Spacer()

                // Inspector Card for Selected Building / Tile
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
                    .padding(.horizontal, 16)
                }

                // Bottom Building Catalogue (in Construction Mode)
                if isConstructionMode {
                    BuildingCatalogueView(
                        timerManager: timerManager,
                        selectedBuildingType: $selectedBuildingType
                    )
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
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

    // MARK: - Scene Actions

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

private struct BuildingInspectorCard: View {
    let building: PlacedBuilding
    let onMove: () -> Void
    let onDemolish: () -> Void
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: building.type.iconName)
                .font(.system(size: 26))
                .foregroundColor(.accentColor)
                .frame(width: 44, height: 44)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(8)

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(building.type.displayName)
                        .font(.system(size: 14, weight: .bold))
                    if building.type.isPermanent {
                        Text("Permanent")
                            .font(.system(size: 9, weight: .semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.2))
                            .foregroundColor(.blue)
                            .cornerRadius(4)
                    }
                }

                Text(building.type.description)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                if let bonus = building.type.bonusDescription {
                    Text("Bonus: \(bonus) (Active)")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.green)
                }
            }

            Spacer()

            // Move Button (Always free, never charges resources)
            Button(action: onMove) {
                Label("Move (Free)", systemImage: "arrow.up.and.down.and.arrow.left.and.right")
                    .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.bordered)

            if !building.type.isPermanent {
                Button(action: onDemolish) {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundColor(.red)
                }
                .buttonStyle(.bordered)
            }

            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(nsColor: .windowBackgroundColor).opacity(0.95))
                .shadow(color: Color.black.opacity(0.2), radius: 6, x: 0, y: 3)
        )
    }
}

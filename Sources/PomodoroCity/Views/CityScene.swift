import Foundation
import SpriteKit
import SwiftUI

public class CityScene: SKScene {
    public var onSelectTile: ((Int, Int, PlacedBuilding?) -> Void)?
    public var onRequestPlace: ((BuildingType, Int, Int) -> Void)?
    public var onRequestMove: ((UUID, Int, Int) -> Void)?

    private var worldNode = SKNode()
    private var groundLayer = SKNode()
    private var buildingLayer = SKNode()
    private var overlayLayer = SKNode()
    private var cameraNode = SKCameraNode()

    // Interactive state
    public var isConstructionMode: Bool = false {
        didSet { updateGridOverlay() }
    }
    public var selectedBuildingTypeToPlace: BuildingType? = nil
    public var selectedBuildingToMove: PlacedBuilding? = nil

    private var currentGameState: GameState?
    private var buildingNodes: [UUID: SKNode] = [:]
    private var lastDragLocation: CGPoint?
    private var isDraggingMap: Bool = false

    // Zoom limits
    private let minZoom: CGFloat = 0.5
    private let maxZoom: CGFloat = 2.2

    public override func didMove(to view: SKView) {
        let isDark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        backgroundColor = isDark
            ? NSColor(srgbRed: 0.149, green: 0.165, blue: 0.141, alpha: 1.0)
            : NSColor(srgbRed: 0.914, green: 0.894, blue: 0.839, alpha: 1.0)
        anchorPoint = CGPoint(x: 0.5, y: 0.5)

        // Setup Scene Graph
        removeAllChildren()
        worldNode.removeAllChildren()

        addChild(worldNode)
        worldNode.addChild(groundLayer)
        worldNode.addChild(buildingLayer)
        worldNode.addChild(overlayLayer)

        camera = cameraNode
        addChild(cameraNode)
        cameraNode.setScale(1.0)
        cameraNode.position = CGPoint(x: 0, y: -40)

        if let state = currentGameState {
            renderMap(state: state)
        }
    }

    public func updateState(_ state: GameState) {
        self.currentGameState = state
        if view != nil {
            renderMap(state: state)
        }
    }

    public func renderMap(state: GameState) {
        groundLayer.removeAllChildren()
        buildingLayer.removeAllChildren()
        buildingNodes.removeAll()

        // Render Ground Grid (16x16)
        for x in 0...15 {
            for y in 0...15 {
                guard let district = DistrictID.district(forX: x, y: y) else { continue }
                let isUnlocked = district.isUnlocked(lifetimeHours: state.lifetimeFocusHours)
                let isRiver = (y == 8 || y == 9) && district == .riverbank

                let tilePos = IsometricTileRenderer.gridToScreen(x: x, y: y)

                // Base Pixel Art Ground Sprite
                let tileTex = IsometricTileRenderer.shared.groundTexture(for: district, isRiver: isRiver)
                let tileNode = SKSpriteNode(texture: tileTex)
                tileNode.anchorPoint = CGPoint(x: 0.5, y: 0.64)
                tileNode.position = tilePos
                tileNode.zPosition = -CGFloat(x + y) * 10 - 500
                tileNode.name = "tile_\(x)_\(y)"

                if !isUnlocked {
                    // Dark misty fog-of-war for locked expansion lands
                    tileNode.color = NSColor(red: 0.12, green: 0.15, blue: 0.20, alpha: 1.0)
                    tileNode.colorBlendFactor = 0.70
                }
                groundLayer.addChild(tileNode)
            }
        }

        // Render District Markers / Badges
        renderDistrictBadges(lifetimeHours: state.lifetimeFocusHours)

        // Render Buildings
        for placed in state.buildings {
            let bNode = IsometricTileRenderer.shared.createBuildingNode(type: placed.type)
            let pos = IsometricTileRenderer.gridToScreen(x: placed.gridX, y: placed.gridY)
            bNode.position = pos
            bNode.zPosition = -CGFloat(placed.gridX + placed.gridY) * 10
            bNode.name = "building_\(placed.id.uuidString)"
            buildingLayer.addChild(bNode)
            buildingNodes[placed.id] = bNode
        }

        updateGridOverlay()
    }

    private func renderDistrictBadges(lifetimeHours: Double) {
        // Forest Edge Badge at (12, 0)
        let feUnlocked = DistrictID.forestEdge.isUnlocked(lifetimeHours: lifetimeHours)
        let fePos = IsometricTileRenderer.gridToScreen(x: 12, y: 0)
        addDistrictLabel(
            title: feUnlocked ? "🌲 Forest Edge" : "🔒 Forest Edge (5h required)",
            at: CGPoint(x: fePos.x, y: fePos.y + 35),
            isUnlocked: feUnlocked
        )

        // Riverbank Badge at (8, 12)
        let rbUnlocked = DistrictID.riverbank.isUnlocked(lifetimeHours: lifetimeHours)
        let rbPos = IsometricTileRenderer.gridToScreen(x: 8, y: 12)
        addDistrictLabel(
            title: rbUnlocked ? "🌊 Riverbank" : "🔒 Riverbank (15h required)",
            at: CGPoint(x: rbPos.x, y: rbPos.y + 35),
            isUnlocked: rbUnlocked
        )
    }

    private func addDistrictLabel(title: String, at pos: CGPoint, isUnlocked: Bool) {
        let label = SKLabelNode(text: title)
        label.fontSize = 11
        label.fontName = "HelveticaNeue-Bold"
        label.fontColor = isUnlocked ? NSColor(white: 0.95, alpha: 0.85) : NSColor(red: 1.0, green: 0.75, blue: 0.5, alpha: 0.9)
        label.position = pos
        label.zPosition = 500

        let bg = SKShapeNode(rectOf: CGSize(width: label.frame.width + 16, height: 20), cornerRadius: 5)
        bg.fillColor = NSColor(white: 0, alpha: 0.6)
        bg.strokeColor = isUnlocked ? NSColor(white: 1.0, alpha: 0.2) : NSColor(red: 1.0, green: 0.6, blue: 0.2, alpha: 0.4)
        bg.lineWidth = 1.0
        bg.position = CGPoint(x: 0, y: 3)
        bg.zPosition = -1
        label.addChild(bg)

        groundLayer.addChild(label)
    }

    private func updateGridOverlay() {
        overlayLayer.removeAllChildren()
        guard isConstructionMode, let state = currentGameState else { return }

        let diamondPath = IsometricTileRenderer.groundDiamondPath()

        for x in 0...15 {
            for y in 0...15 {
                guard let district = DistrictID.district(forX: x, y: y) else { continue }
                guard district.isUnlocked(lifetimeHours: state.lifetimeFocusHours) else { continue }

                let isOccupied = state.buildingAt(gridX: x, gridY: y) != nil
                let isRiver = (y == 8 || y == 9) && district == .riverbank
                if isRiver { continue } // Cannot build directly on open water

                let pos = IsometricTileRenderer.gridToScreen(x: x, y: y)
                let guide = SKShapeNode(path: diamondPath)
                guide.position = pos
                guide.zPosition = 300

                if isOccupied {
                    guide.strokeColor = NSColor(white: 1.0, alpha: 0.3)
                    guide.fillColor = NSColor(white: 1.0, alpha: 0.05)
                } else {
                    guide.strokeColor = NSColor(red: 0.3, green: 0.9, blue: 0.4, alpha: 0.7)
                    guide.fillColor = NSColor(red: 0.2, green: 0.8, blue: 0.3, alpha: 0.15)
                }
                guide.lineWidth = 1.5
                overlayLayer.addChild(guide)
            }
        }

        // Highlight selected building for movement
        if let moving = selectedBuildingToMove {
            let pos = IsometricTileRenderer.gridToScreen(x: moving.gridX, y: moving.gridY)
            let movingRing = SKShapeNode(path: diamondPath)
            movingRing.position = pos
            movingRing.strokeColor = NSColor(red: 1.0, green: 0.8, blue: 0.2, alpha: 0.95)
            movingRing.fillColor = NSColor(red: 1.0, green: 0.8, blue: 0.2, alpha: 0.25)
            movingRing.lineWidth = 2.5
            movingRing.zPosition = 400
            overlayLayer.addChild(movingRing)
        }
    }

    // MARK: - Input Handling (Pan, Zoom, Tap)

    public override func mouseDown(with event: NSEvent) {
        lastDragLocation = event.location(in: self)
        isDraggingMap = false
    }

    public override func mouseDragged(with event: NSEvent) {
        let currentPos = event.location(in: self)
        if let lastPos = lastDragLocation {
            let dx = currentPos.x - lastPos.x
            let dy = currentPos.y - lastPos.y

            if hypot(dx, dy) > 2.0 {
                isDraggingMap = true
                cameraNode.position = CGPoint(
                    x: cameraNode.position.x - dx * cameraNode.xScale,
                    y: cameraNode.position.y - dy * cameraNode.yScale
                )
            }
        }
        lastDragLocation = currentPos
    }

    public override func mouseUp(with event: NSEvent) {
        if !isDraggingMap {
            let clickInWorld = event.location(in: worldNode)
            let (x, y) = IsometricTileRenderer.screenToGrid(point: clickInWorld)
            handleTap(gridX: x, gridY: y)
        }
        lastDragLocation = nil
        isDraggingMap = false
    }

    public override func scrollWheel(with event: NSEvent) {
        if event.modifierFlags.contains(.command) || abs(event.deltaZ) > 0 || abs(event.magnification) > 0 {
            // Zoom via trackpad pinch or command-scroll
            let zoomFactor: CGFloat = 1.0 - (event.deltaY * 0.02)
            applyZoom(factor: zoomFactor)
        } else {
            // Smooth pan with two-finger swipe or scroll wheel
            cameraNode.position = CGPoint(
                x: cameraNode.position.x - event.deltaX * 1.5 * cameraNode.xScale,
                y: cameraNode.position.y + event.deltaY * 1.5 * cameraNode.yScale
            )
        }
    }

    public func zoomIn() {
        applyZoom(factor: 0.85)
    }

    public func zoomOut() {
        applyZoom(factor: 1.15)
    }

    public func resetView() {
        let move = SKAction.move(to: CGPoint(x: 0, y: -40), duration: 0.3)
        let scale = SKAction.scale(to: 1.0, duration: 0.3)
        cameraNode.run(SKAction.group([move, scale]))
    }

    private func applyZoom(factor: CGFloat) {
        let newScale = cameraNode.xScale * factor
        let clampedScale = max(minZoom, min(maxZoom, newScale))
        cameraNode.setScale(clampedScale)
    }

    private func handleTap(gridX: Int, gridY: Int) {
        guard gridX >= 0 && gridX <= 15 && gridY >= 0 && gridY <= 15 else { return }
        guard let state = currentGameState else { return }

        let building = state.buildingAt(gridX: gridX, gridY: gridY)

        if isConstructionMode {
            // If we are currently moving a building:
            if let moving = selectedBuildingToMove {
                if state.canPlace(atX: gridX, y: gridY, excludingBuildingID: moving.id) {
                    onRequestMove?(moving.id, gridX, gridY)
                    selectedBuildingToMove = nil
                    updateGridOverlay()
                    return
                } else if building?.id == moving.id {
                    // Tapped self again: cancel move
                    selectedBuildingToMove = nil
                    updateGridOverlay()
                    return
                }
            }

            // If a building catalogue item is queued to place:
            if let typeToPlace = selectedBuildingTypeToPlace {
                if state.canPlace(atX: gridX, y: gridY) {
                    onRequestPlace?(typeToPlace, gridX, gridY)
                    selectedBuildingTypeToPlace = nil
                    return
                }
            }

            // If tapping an existing building in construction mode:
            if let building = building {
                selectedBuildingToMove = building
                updateGridOverlay()
            }
        }

        onSelectTile?(gridX, gridY, building)
    }
}

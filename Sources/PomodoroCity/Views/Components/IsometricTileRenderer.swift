import Foundation
import SpriteKit
import CoreGraphics

// MARK: - Direct Pixel Art Buffer Engine

public final class PixelBuffer {
    public let width: Int
    public let height: Int
    public var pixels: [UInt32]

    public init(width: Int, height: Int, clearColor: UInt32 = 0) {
        self.width = width
        self.height = height
        self.pixels = [UInt32](repeating: clearColor, count: width * height)
    }

    @inline(__always)
    public func setPixel(_ x: Int, _ y: Int, _ color: UInt32) {
        guard x >= 0 && x < width && y >= 0 && y < height else { return }
        pixels[y * width + x] = color
    }

    @inline(__always)
    public func blendPixel(_ x: Int, _ y: Int, _ color: UInt32) {
        guard x >= 0 && x < width && y >= 0 && y < height else { return }
        let srcA = (color >> 24) & 0xFF
        if srcA == 255 {
            pixels[y * width + x] = color
            return
        }
        if srcA == 0 { return }

        let dest = pixels[y * width + x]
        let destA = (dest >> 24) & 0xFF
        let destR = (dest >> 16) & 0xFF
        let destG = (dest >> 8) & 0xFF
        let destB = dest & 0xFF

        let srcR = (color >> 16) & 0xFF
        let srcG = (color >> 8) & 0xFF
        let srcB = color & 0xFF

        let outA = srcA + (destA * (255 - srcA)) / 255
        let outR = (srcR * srcA + destR * (255 - srcA)) / 255
        let outG = (srcG * srcA + destG * (255 - srcA)) / 255
        let outB = (srcB * srcA + destB * (255 - srcA)) / 255

        pixels[y * width + x] = (outA << 24) | (outR << 16) | (outG << 8) | outB
    }

    public func fillRect(x: Int, y: Int, w: Int, h: Int, color: UInt32) {
        for dy in 0..<h {
            let py = y + dy
            guard py >= 0 && py < height else { continue }
            for dx in 0..<w {
                let px = x + dx
                guard px >= 0 && px < width else { continue }
                pixels[py * width + px] = color
            }
        }
    }

    public func drawHLine(x1: Int, x2: Int, y: Int, color: UInt32) {
        guard y >= 0 && y < height else { return }
        let minX = max(0, min(x1, x2))
        let maxX = min(width - 1, max(x1, x2))
        for x in minX...maxX {
            pixels[y * width + x] = color
        }
    }

    public func drawVLine(x: Int, y1: Int, y2: Int, color: UInt32) {
        guard x >= 0 && x < width else { return }
        let minY = max(0, min(y1, y2))
        let maxY = min(height - 1, max(y1, y2))
        for y in minY...maxY {
            pixels[y * width + x] = color
        }
    }

    public func toSKTexture() -> SKTexture {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue
        let data = Data(bytes: pixels, count: pixels.count * 4) as CFData
        guard let provider = CGDataProvider(data: data),
              let cg = CGImage(
                width: width,
                height: height,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: width * 4,
                space: colorSpace,
                bitmapInfo: CGBitmapInfo(rawValue: bitmapInfo),
                provider: provider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
              ) else {
            return SKTexture()
        }
        let texture = SKTexture(cgImage: cg)
        texture.filteringMode = .nearest
        return texture
    }
}

// MARK: - Color Palette Helpers

public func pixelColor(_ r: UInt8, _ g: UInt8, _ b: UInt8, _ a: UInt8 = 255) -> UInt32 {
    let alpha = UInt32(a)
    let red = (UInt32(r) * alpha) / 255
    let green = (UInt32(g) * alpha) / 255
    let blue = (UInt32(b) * alpha) / 255
    return (alpha << 24) | (red << 16) | (green << 8) | blue
}

// MARK: - Authentic Isometric Pixel Art Renderer

public class IsometricTileRenderer {
    public static let shared = IsometricTileRenderer()

    public static let tileWidth: CGFloat = 64.0
    public static let tileHeight: CGFloat = 32.0

    private var tileTextureCache: [String: SKTexture] = [:]
    private var buildingTextureCache: [BuildingType: SKTexture] = [:]

    private init() {}

    // MARK: - Coordinate Transformations (2:1 Isometric Ratio)

    public static func gridToScreen(x: Int, y: Int) -> CGPoint {
        let isoX = CGFloat(x - y) * (tileWidth / 2.0)
        let isoY = -CGFloat(x + y) * (tileHeight / 2.0)
        return CGPoint(x: isoX, y: isoY)
    }

    public static func screenToGrid(point: CGPoint) -> (x: Int, y: Int) {
        let a = point.x / (tileWidth / 2.0)
        let b = -point.y / (tileHeight / 2.0)
        let x = Int(round((b + a) / 2.0))
        let y = Int(round((b - a) / 2.0))
        return (x, y)
    }

    public static func groundDiamondPath() -> CGPath {
        let path = CGMutablePath()
        let hw = tileWidth / 2.0
        let hh = tileHeight / 2.0
        path.move(to: CGPoint(x: 0, y: hh))
        path.addLine(to: CGPoint(x: hw, y: 0))
        path.addLine(to: CGPoint(x: 0, y: -hh))
        path.addLine(to: CGPoint(x: -hw, y: 0))
        path.closeSubpath()
        return path
    }

    // MARK: - Pixel Art Ground Tiles

    public func groundTexture(for district: DistrictID, isRiver: Bool = false) -> SKTexture {
        let key = "\(district.rawValue)_\(isRiver)"
        if let cached = tileTextureCache[key] { return cached }

        // Tile buffer: 64 wide x 44 high (32px diamond top + 12px earth cliff depth)
        let buf = PixelBuffer(width: 64, height: 44)

        // Palette definitions
        let outline = pixelColor(32, 24, 16)
        let cliffLeft = pixelColor(92, 64, 44)
        let cliffLeftDark = pixelColor(70, 48, 32)
        let cliffRight = pixelColor(58, 38, 24)
        let cliffRightDark = pixelColor(42, 26, 16)

        // Draw 3D Earth Cliff Slab below the tile
        for y in 0..<10 {
            let py = 16 + y
            // Left cliff face
            for x in 0...31 {
                let diag = x / 2
                if py >= 16 + diag && py <= 26 + diag {
                    let dither = ((x + y) % 3 == 0) ? cliffLeftDark : cliffLeft
                    buf.setPixel(x, py, dither)
                }
            }
            // Right cliff face
            for x in 32...63 {
                let diag = (63 - x) / 2
                if py >= 16 + diag && py <= 26 + diag {
                    let dither = ((x + y) % 3 == 0) ? cliffRightDark : cliffRight
                    buf.setPixel(x, py, dither)
                }
            }
        }

        // Draw Surface Isometric Diamond
        if isRiver {
            // River Water with specular ripples
            let deepWater = pixelColor(36, 102, 168)
            let midWater = pixelColor(48, 134, 212)
            let lightWater = pixelColor(88, 178, 246)
            let waveWhite = pixelColor(220, 245, 255)

            for py in 0..<32 {
                let span = py < 16 ? (py * 2 + 1) : ((31 - py) * 2 + 1)
                let startX = 32 - span / 2
                let endX = startX + span

                for px in startX..<endX {
                    var col = midWater
                    if (px + py * 2) % 11 == 0 {
                        col = deepWater
                    } else if (px * 3 + py) % 13 == 0 {
                        col = lightWater
                    }
                    if (px % 14 == 0 || px % 14 == 1) && (py == 8 || py == 20) {
                        col = waveWhite
                    }
                    buf.setPixel(px, py, col)
                }
            }
        } else {
            let grassLight: UInt32
            let grassMid: UInt32
            let grassDark: UInt32
            let flowerDot: UInt32

            switch district {
            case .startingVillage:
                grassLight = pixelColor(108, 178, 56)
                grassMid = pixelColor(86, 150, 42)
                grassDark = pixelColor(64, 118, 32)
                flowerDot = pixelColor(255, 235, 120) // Tiny buttercups
            case .forestEdge:
                grassLight = pixelColor(68, 128, 52)
                grassMid = pixelColor(52, 104, 38)
                grassDark = pixelColor(38, 78, 28)
                flowerDot = pixelColor(180, 140, 100) // Pine cones / fallen needles
            case .riverbank:
                grassLight = pixelColor(134, 186, 72)
                grassMid = pixelColor(108, 160, 54)
                grassDark = pixelColor(82, 128, 40)
                flowerDot = pixelColor(225, 205, 140) // River sand grains
            }

            for py in 0..<32 {
                let span = py < 16 ? (py * 2 + 1) : ((31 - py) * 2 + 1)
                let startX = 32 - span / 2
                let endX = startX + span

                for px in startX..<endX {
                    var col = grassMid
                    if (px ^ py) & 3 == 0 {
                        col = grassLight
                    } else if (px + py * 3) % 7 == 0 {
                        col = grassDark
                    }

                    // Occasional pixel tufts & blossoms
                    if (px * 17 + py * 23) % 97 == 0 {
                        col = flowerDot
                    }
                    buf.setPixel(px, py, col)
                }
            }
        }

        // Crisp pixel outline along diamond perimeter
        for py in 0..<16 {
            let leftX = 32 - py * 2
            let rightX = 31 + py * 2
            buf.setPixel(leftX, py, outline)
            buf.setPixel(rightX, py, outline)
        }
        for py in 16..<32 {
            let dy = py - 16
            let leftX = dy * 2
            let rightX = 63 - dy * 2
            buf.setPixel(leftX, py, outline)
            buf.setPixel(rightX, py, outline)
        }

        // Bottom cliff perimeter
        buf.drawHLine(x1: 0, x2: 31, y: 36, color: outline)
        buf.drawHLine(x1: 32, x2: 63, y: 36, color: outline)
        buf.drawVLine(x: 32, y1: 31, y2: 42, color: outline)

        let tex = buf.toSKTexture()
        tileTextureCache[key] = tex
        return tex
    }

    // MARK: - Pixel Art Buildings Generator

    public func createBuildingNode(type: BuildingType) -> SKNode {
        let container = SKNode()

        if let cached = buildingTextureCache[type] {
            let sprite = SKSpriteNode(texture: cached)
            sprite.anchorPoint = anchorPoint(for: type)
            container.addChild(sprite)
            addSpecialEffects(to: container, type: type)
            return container
        }

        let texture: SKTexture
        switch type {
        case .townHall:
            texture = drawPixelTownHall()
        case .cottage:
            texture = drawPixelCottage()
        case .garden:
            texture = drawPixelGarden()
        case .park:
            texture = drawPixelPark()
        case .road:
            texture = drawPixelRoad()
        case .fountain:
            texture = drawPixelFountain()
        case .windmill:
            texture = drawPixelWindmill()
        case .library:
            texture = drawPixelLibrary()
        case .workshop:
            texture = drawPixelWorkshop()
        case .university:
            texture = drawPixelUniversity()
        }

        buildingTextureCache[type] = texture

        let sprite = SKSpriteNode(texture: texture)
        sprite.anchorPoint = anchorPoint(for: type)
        container.addChild(sprite)

        addSpecialEffects(to: container, type: type)
        return container
    }

    private func anchorPoint(for type: BuildingType) -> CGPoint {
        switch type {
        case .road:
            return CGPoint(x: 0.5, y: 0.5)
        case .garden, .park:
            return CGPoint(x: 0.5, y: 0.35)
        case .fountain:
            return CGPoint(x: 0.5, y: 0.32)
        case .cottage, .workshop:
            return CGPoint(x: 0.5, y: 0.28)
        case .library, .windmill:
            return CGPoint(x: 0.5, y: 0.24)
        case .townHall:
            return CGPoint(x: 0.5, y: 0.22)
        case .university:
            return CGPoint(x: 0.5, y: 0.20)
        }
    }

    private func addSpecialEffects(to node: SKNode, type: BuildingType) {
        if type == .cottage || type == .workshop {
            // Animated pixel smoke particles
            let smokeNode = SKNode()
            smokeNode.position = type == .cottage ? CGPoint(x: 14, y: 44) : CGPoint(x: 16, y: 46)
            smokeNode.zPosition = 5
            node.addChild(smokeNode)

            let puffAction = SKAction.run { [weak smokeNode] in
                guard let smokeNode = smokeNode else { return }
                let puff = SKShapeNode(rectOf: CGSize(width: 4, height: 4))
                puff.fillColor = NSColor(white: 0.85, alpha: 0.7)
                puff.strokeColor = .clear
                puff.position = CGPoint(x: CGFloat.random(in: -1...1), y: 0)
                smokeNode.addChild(puff)

                let move = SKAction.moveBy(x: CGFloat.random(in: 4...8), y: CGFloat.random(in: 14...20), duration: 2.2)
                let fade = SKAction.fadeOut(withDuration: 2.2)
                puff.run(SKAction.sequence([SKAction.group([move, fade]), SKAction.removeFromParent()]))
            }
            smokeNode.run(SKAction.repeatForever(SKAction.sequence([puffAction, SKAction.wait(forDuration: 0.8)])))
        }

        if type == .windmill {
            // Rotating pixel sails
            let rotorNode = SKNode()
            rotorNode.position = CGPoint(x: 0, y: 42)
            rotorNode.zPosition = 6
            node.addChild(rotorNode)

            let sailTex = drawPixelWindmillSails()
            let sails = SKSpriteNode(texture: sailTex)
            rotorNode.addChild(sails)

            sails.run(SKAction.repeatForever(SKAction.rotate(byAngle: -.pi * 2, duration: 6.0)))
        }
    }

    // MARK: - Handcrafted Pixel Art Artwork

    /// 1. Cozy Half-Timber Tudor Cottage
    private func drawPixelCottage() -> SKTexture {
        let buf = PixelBuffer(width: 64, height: 64)

        let woodDark = pixelColor(48, 28, 16)
        let woodMid = pixelColor(84, 52, 28)
        let wallPlaster = pixelColor(228, 218, 196)
        let wallShadow = pixelColor(194, 182, 160)
        let roofRed = pixelColor(186, 68, 44)
        let roofRedLight = pixelColor(216, 94, 66)
        let roofRedDark = pixelColor(142, 44, 26)
        let windowGlow = pixelColor(255, 218, 92)
        let stoneDark = pixelColor(72, 68, 62)
        let stoneLight = pixelColor(118, 114, 106)
        let outline = pixelColor(24, 16, 12)

        // Drop shadow on ground
        for y in 6..<16 {
            let span = (y - 6) * 4
            buf.fillRect(x: 32 - span/2, y: y, w: span, h: 1, color: pixelColor(0, 0, 0, 70))
        }

        // Stone Chimney (Right side)
        buf.fillRect(x: 44, y: 16, w: 8, h: 28, color: stoneDark)
        for cy in stride(from: 18, to: 42, by: 4) {
            buf.drawHLine(x1: 44, x2: 51, y: cy, color: stoneLight)
        }
        buf.drawVLine(x: 48, y1: 18, y2: 44, color: stoneDark)
        buf.fillRect(x: 43, y: 44, w: 10, h: 3, color: stoneLight) // Chimney cap

        // Cottage Walls (Box)
        buf.fillRect(x: 16, y: 14, w: 32, h: 20, color: wallPlaster)
        buf.fillRect(x: 32, y: 14, w: 16, h: 20, color: wallShadow) // Shaded right wall

        // Timber Framing (Exposed dark beams)
        buf.fillRect(x: 16, y: 14, w: 32, h: 3, color: woodDark) // Base beam
        buf.fillRect(x: 16, y: 31, w: 32, h: 3, color: woodDark) // Top beam
        buf.fillRect(x: 16, y: 14, w: 3, h: 20, color: woodDark) // Left post
        buf.fillRect(x: 31, y: 14, w: 3, h: 20, color: woodDark) // Center corner
        buf.fillRect(x: 45, y: 14, w: 3, h: 20, color: woodDark) // Right post

        // Diagonal Tudor timber brace
        for i in 0..<12 {
            buf.setPixel(19 + i, 18 + i, woodMid)
            buf.setPixel(20 + i, 18 + i, woodDark)
        }

        // Wooden Door
        buf.fillRect(x: 22, y: 14, w: 7, h: 13, color: woodMid)
        buf.drawVLine(x: 25, y1: 14, y2: 26, color: woodDark)
        buf.setPixel(28, 20, pixelColor(240, 200, 80)) // Brass doorknob

        // Glowing Window with crossbars
        buf.fillRect(x: 36, y: 20, w: 7, h: 8, color: windowGlow)
        buf.drawVLine(x: 39, y1: 20, y2: 27, color: woodDark)
        buf.drawHLine(x1: 36, x2: 42, y: 24, color: woodDark)
        // Window flower box
        buf.fillRect(x: 35, y: 18, w: 9, h: 3, color: woodDark)
        buf.setPixel(36, 21, pixelColor(255, 100, 140)) // Pink blossom
        buf.setPixel(38, 21, pixelColor(255, 60, 80))   // Red blossom
        buf.setPixel(41, 21, pixelColor(255, 100, 140)) // Pink blossom

        // Gable Roof (Isometric triangular slopes)
        for dy in 0..<16 {
            let y = 33 + dy
            let leftSpan = dy * 2
            let rightSpan = dy * 2

            // Left roof slope (light)
            buf.drawHLine(x1: 32 - leftSpan, x2: 32, y: y, color: roofRedLight)
            // Shingle texture rows
            if dy % 3 == 0 {
                buf.drawHLine(x1: 32 - leftSpan, x2: 32, y: y, color: roofRed)
            }

            // Right roof slope (shadow)
            buf.drawHLine(x1: 32, x2: 32 + rightSpan, y: y, color: roofRedDark)
            if dy % 3 == 0 {
                buf.drawHLine(x1: 32, x2: 32 + rightSpan, y: y, color: outline)
            }
        }
        // Roof ridge line
        buf.drawVLine(x: 32, y1: 33, y2: 49, color: roofRedLight)

        return buf.toSKTexture()
    }

    /// 2. Majestic Grand Town Hall
    private func drawPixelTownHall() -> SKTexture {
        let buf = PixelBuffer(width: 80, height: 96)

        let stoneBase = pixelColor(180, 172, 160)
        let stoneShadow = pixelColor(140, 132, 122)
        let stoneGrout = pixelColor(96, 90, 82)
        let pillarWhite = pixelColor(240, 238, 232)
        let slateBlueLight = pixelColor(78, 102, 128)
        let slateBlueDark = pixelColor(38, 52, 70)
        let goldAccent = pixelColor(242, 196, 68)
        let copperGreen = pixelColor(74, 158, 134)
        let windowGlow = pixelColor(255, 224, 110)
        let outline = pixelColor(28, 24, 20)

        // Drop shadow
        for y in 8..<22 {
            let span = (y - 8) * 4
            buf.fillRect(x: 40 - span/2, y: y, w: span, h: 1, color: pixelColor(0, 0, 0, 75))
        }

        // Stepped Foundation Plinth
        buf.fillRect(x: 14, y: 14, w: 52, h: 8, color: stoneBase)
        buf.fillRect(x: 40, y: 14, w: 26, h: 8, color: stoneShadow)
        buf.drawHLine(x1: 14, x2: 65, y: 14, color: outline)
        buf.drawHLine(x1: 14, x2: 65, y: 21, color: stoneGrout)

        // Main Hall Facade
        buf.fillRect(x: 18, y: 22, w: 44, h: 26, color: stoneBase)
        buf.fillRect(x: 40, y: 22, w: 22, h: 26, color: stoneShadow)

        // Brick mortar checker
        for by in stride(from: 24, to: 46, by: 4) {
            buf.drawHLine(x1: 18, x2: 61, y: by, color: stoneGrout)
        }

        // Classical Pillars
        for px in [22, 30, 48, 56] {
            buf.fillRect(x: px, y: 22, w: 4, h: 26, color: pillarWhite)
            buf.fillRect(x: px - 1, y: 46, w: 6, h: 2, color: goldAccent) // Capital
        }

        // Arched Grand Portal Entrance
        buf.fillRect(x: 35, y: 22, w: 10, h: 18, color: outline)
        buf.fillRect(x: 36, y: 22, w: 8, h: 16, color: pixelColor(64, 42, 24))
        buf.drawVLine(x: 40, y1: 22, y2: 37, color: outline)

        // Upper Balcony & Windows
        buf.fillRect(x: 25, y: 32, w: 4, h: 10, color: windowGlow)
        buf.fillRect(x: 51, y: 32, w: 4, h: 10, color: windowGlow)

        // Gabled Slate Roof
        for dy in 0..<14 {
            let y = 48 + dy
            let span = 26 - dy * 2
            buf.drawHLine(x1: 40 - span, x2: 40, y: y, color: slateBlueLight)
            buf.drawHLine(x1: 40, x2: 40 + span, y: y, color: slateBlueDark)
        }

        // Central Bell & Clock Tower
        buf.fillRect(x: 32, y: 56, w: 16, h: 22, color: stoneBase)
        buf.fillRect(x: 40, y: 56, w: 8, h: 22, color: stoneShadow)
        buf.drawVLine(x: 32, y1: 56, y2: 77, color: outline)
        buf.drawVLine(x: 47, y1: 56, y2: 77, color: outline)

        // Clock Face
        buf.fillRect(x: 36, y: 62, w: 8, h: 8, color: pixelColor(255, 255, 255))
        buf.setPixel(40, 66, outline) // Center pivot
        buf.setPixel(40, 68, outline) // Hand 1
        buf.setPixel(42, 66, outline) // Hand 2
        buf.fillRect(x: 35, y: 61, w: 10, h: 1, color: goldAccent)
        buf.fillRect(x: 35, y: 70, w: 10, h: 1, color: goldAccent)

        // Tower Copper Spire
        for sy in 0..<14 {
            let y = 78 + sy
            let halfW = max(1, 6 - sy / 2)
            buf.drawHLine(x1: 40 - halfW, x2: 40, y: y, color: copperGreen)
            buf.drawHLine(x1: 40, x2: 40 + halfW, y: y, color: pixelColor(50, 115, 95))
        }

        // Gold Weather-Vane Peak
        buf.drawVLine(x: 40, y1: 91, y2: 95, color: goldAccent)
        buf.drawHLine(x1: 38, x2: 43, y: 94, color: goldAccent)

        return buf.toSKTexture()
    }

    /// 3. Colorful Artisan Flower Garden
    private func drawPixelGarden() -> SKTexture {
        let buf = PixelBuffer(width: 64, height: 48)

        let soil = pixelColor(82, 54, 34)
        let curb = pixelColor(140, 134, 126)
        let curbLight = pixelColor(176, 170, 162)
        let bushGreen = pixelColor(56, 128, 44)
        let bushLight = pixelColor(82, 168, 62)

        // Diamond Curb Border
        for py in 8..<24 {
            let span = py < 16 ? (py - 8) * 4 : (24 - py) * 4
            buf.fillRect(x: 32 - span/2, y: py, w: span, h: 1, color: soil)
        }

        // Stone boundary border
        for py in 8..<16 {
            let lx = 32 - (py - 8) * 2
            let rx = 31 + (py - 8) * 2
            buf.setPixel(lx, py, curbLight)
            buf.setPixel(rx, py, curb)
        }
        for py in 16..<24 {
            let lx = (py - 16) * 2 + 16
            let rx = 47 - (py - 16) * 2
            buf.setPixel(lx, py, curb)
            buf.setPixel(rx, py, curbLight)
        }

        // Flower Bush Clusters
        let bushPositions = [(22, 14), (32, 18), (42, 13), (26, 20), (38, 21)]
        let flowerColors = [
            pixelColor(255, 60, 90),   // Red Rose
            pixelColor(255, 220, 60),  // Yellow Marigold
            pixelColor(180, 110, 240), // Purple Lavender
            pixelColor(70, 170, 255)   // Blue Hydrangea
        ]

        for (i, pos) in bushPositions.enumerated() {
            // Bush body
            buf.fillRect(x: pos.0 - 4, y: pos.1, w: 8, h: 6, color: bushGreen)
            buf.fillRect(x: pos.0 - 3, y: pos.1 + 4, w: 6, h: 3, color: bushLight)

            // Blooms
            let col = flowerColors[i % flowerColors.count]
            buf.setPixel(pos.0 - 2, pos.1 + 4, col)
            buf.setPixel(pos.0 + 1, pos.1 + 5, col)
            buf.setPixel(pos.0, pos.1 + 2, col)
        }

        return buf.toSKTexture()
    }

    /// 4. Pine Trees & Shaded Park Bench
    private func drawPixelPark() -> SKTexture {
        let buf = PixelBuffer(width: 64, height: 64)

        let benchWood = pixelColor(148, 82, 38)
        let benchIron = pixelColor(32, 28, 26)

        // Left Tall Scots Pine
        drawPixelPine(buf: buf, cx: 22, baseY: 12, height: 38)

        // Right Smaller Pine
        drawPixelPine(buf: buf, cx: 44, baseY: 16, height: 28)

        // Slatted Park Bench
        buf.fillRect(x: 27, y: 12, w: 12, h: 2, color: benchIron)
        buf.fillRect(x: 26, y: 14, w: 14, h: 3, color: benchWood) // Seat
        buf.fillRect(x: 26, y: 18, w: 14, h: 3, color: benchWood) // Backrest
        buf.drawVLine(x: 27, y1: 10, y2: 19, color: benchIron)
        buf.drawVLine(x: 38, y1: 10, y2: 19, color: benchIron)

        return buf.toSKTexture()
    }

    private func drawPixelPine(buf: PixelBuffer, cx: Int, baseY: Int, height: Int) {
        let trunkCol = pixelColor(78, 48, 28)
        let darkCol = pixelColor(34, 76, 40)
        let midCol = pixelColor(48, 112, 56)
        let lightCol = pixelColor(74, 158, 80)

        // Trunk
        buf.fillRect(x: cx - 1, y: baseY, w: 3, h: height / 2, color: trunkCol)

        // Tiered Conical Needle Boughs
        let tiers = 3
        let tierH = height / tiers
        for t in 0..<tiers {
            let ty = baseY + 8 + t * (tierH - 2)
            let maxSpan = 14 - t * 3

            for dy in 0..<tierH {
                let y = ty + dy
                let span = max(1, maxSpan - dy)
                buf.drawHLine(x1: cx - span, x2: cx, y: y, color: lightCol)
                buf.drawHLine(x1: cx, x2: cx + span, y: y, color: (t % 2 == 0) ? midCol : darkCol)
            }
        }
    }

    /// 5. Interlocking Cobblestone Road
    private func drawPixelRoad() -> SKTexture {
        let buf = PixelBuffer(width: 64, height: 36)

        let dirtCrevice = pixelColor(42, 34, 26)
        let stoneBase = pixelColor(148, 142, 136)
        let stoneHighlight = pixelColor(186, 180, 174)
        let stoneShadow = pixelColor(108, 102, 96)

        // Fill background dirt
        for py in 0..<32 {
            let span = py < 16 ? (py * 2 + 1) : ((31 - py) * 2 + 1)
            let startX = 32 - span / 2
            let endX = startX + span
            for px in startX..<endX {
                buf.setPixel(px, py, dirtCrevice)
            }
        }

        // Paving stones pattern (irregular interlocking rounded blocks)
        let stones = [
            (24, 6, 7, 5), (34, 5, 8, 5),
            (16, 12, 8, 6), (26, 11, 10, 6), (38, 11, 9, 6),
            (12, 18, 9, 5), (23, 17, 8, 6), (33, 17, 10, 6), (45, 17, 8, 5),
            (20, 23, 10, 5), (32, 23, 9, 5),
            (27, 28, 8, 4)
        ]

        for s in stones {
            buf.fillRect(x: s.0, y: s.1, w: s.2, h: s.3, color: stoneBase)
            // Top-left highlight
            buf.drawHLine(x1: s.0, x2: s.0 + s.2 - 2, y: s.1 + s.3 - 1, color: stoneHighlight)
            buf.drawVLine(x: s.0, y1: s.1, y2: s.1 + s.3 - 1, color: stoneHighlight)
            // Bottom-right shadow
            buf.drawHLine(x1: s.0 + 1, x2: s.0 + s.2 - 1, y: s.1, color: stoneShadow)
            buf.drawVLine(x: s.0 + s.2 - 1, y1: s.1, y2: s.1 + s.3 - 2, color: stoneShadow)
        }

        return buf.toSKTexture()
    }

    /// 6. Stepped Carved Stone Fountain
    private func drawPixelFountain() -> SKTexture {
        let buf = PixelBuffer(width: 64, height: 56)

        let stone = pixelColor(160, 156, 150)
        let stoneLight = pixelColor(198, 194, 188)
        let stoneDark = pixelColor(112, 108, 104)
        let waterBlue = pixelColor(64, 160, 232)
        let waterLight = pixelColor(140, 215, 255)
        let waterWhite = pixelColor(255, 255, 255)

        // Octagonal Lower Basin
        buf.fillRect(x: 14, y: 10, w: 36, h: 10, color: stone)
        buf.fillRect(x: 16, y: 12, w: 32, h: 7, color: waterBlue)

        // Water specular highlight ripples
        buf.drawHLine(x1: 20, x2: 28, y: 15, color: waterLight)
        buf.drawHLine(x1: 34, x2: 44, y: 14, color: waterLight)

        // Basin rims
        buf.drawHLine(x1: 14, x2: 49, y: 19, color: stoneLight)
        buf.drawHLine(x1: 14, x2: 49, y: 10, color: stoneDark)

        // Center Pillar Pedestal
        buf.fillRect(x: 28, y: 16, w: 8, h: 12, color: stone)
        buf.fillRect(x: 32, y: 16, w: 4, h: 12, color: stoneDark)

        // Upper Tier Bowl
        buf.fillRect(x: 22, y: 26, w: 20, h: 6, color: stone)
        buf.drawHLine(x1: 22, x2: 41, y: 31, color: stoneLight)
        buf.fillRect(x: 24, y: 28, w: 16, h: 3, color: waterBlue)

        // Top Spout Jet
        buf.fillRect(x: 30, y: 32, w: 4, h: 6, color: waterLight)
        buf.setPixel(31, 38, waterWhite)
        buf.setPixel(32, 38, waterWhite)

        // Water droplets cascading down
        buf.setPixel(25, 24, waterWhite)
        buf.setPixel(38, 23, waterWhite)
        buf.setPixel(20, 16, waterWhite)
        buf.setPixel(43, 15, waterWhite)

        return buf.toSKTexture()
    }

    /// 7. Rustic Windmill Tower
    private func drawPixelWindmill() -> SKTexture {
        let buf = PixelBuffer(width: 64, height: 72)

        let stone = pixelColor(172, 164, 152)
        let stoneShadow = pixelColor(128, 120, 110)
        let stoneGrout = pixelColor(88, 80, 72)
        let thatch = pixelColor(186, 136, 76)
        let thatchDark = pixelColor(140, 96, 48)
        let wood = pixelColor(92, 54, 28)

        // Base Tower (Tapered masonry cylinder)
        for dy in 0..<28 {
            let y = 12 + dy
            let halfW = 14 - (dy / 4)
            buf.drawHLine(x1: 32 - halfW, x2: 32, y: y, color: stone)
            buf.drawHLine(x1: 32, x2: 32 + halfW, y: y, color: stoneShadow)
            if dy % 4 == 0 {
                buf.drawHLine(x1: 32 - halfW, x2: 32 + halfW, y: y, color: stoneGrout)
            }
        }

        // Timber Door
        buf.fillRect(x: 28, y: 12, w: 8, h: 12, color: wood)
        buf.drawVLine(x: 32, y1: 12, y2: 23, color: pixelColor(40, 24, 12))

        // Conical Thatched Cap
        for cy in 0..<12 {
            let y = 40 + cy
            let halfW = 10 - cy / 2
            buf.drawHLine(x1: 32 - halfW, x2: 32, y: y, color: thatch)
            buf.drawHLine(x1: 32, x2: 32 + halfW, y: y, color: thatchDark)
        }

        // Center hub
        buf.fillRect(x: 30, y: 40, w: 4, h: 4, color: pixelColor(48, 30, 16))

        return buf.toSKTexture()
    }

    private func drawPixelWindmillSails() -> SKTexture {
        let buf = PixelBuffer(width: 48, height: 48)
        let wood = pixelColor(92, 54, 28)
        let canvas = pixelColor(235, 230, 218)

        let cx = 24
        let cy = 24

        // 4 Sails
        let dirs = [(0, 1), (1, 0), (0, -1), (-1, 0)]
        for d in dirs {
            for step in 3..<22 {
                let px = cx + d.0 * step
                let py = cy + d.1 * step
                buf.setPixel(px, py, wood)

                // Lattice canvas slats
                if d.0 == 0 {
                    // Vertical beam, horizontal canvas slats
                    buf.drawHLine(x1: px + 1, x2: px + 4, y: py, color: canvas)
                    if step % 3 == 0 {
                        buf.setPixel(px + 4, py, wood)
                    }
                } else {
                    // Horizontal beam, vertical canvas slats
                    buf.drawVLine(x: px, y1: py + 1, y2: py + 4, color: canvas)
                    if step % 3 == 0 {
                        buf.setPixel(px, py + 4, wood)
                    }
                }
            }
        }

        return buf.toSKTexture()
    }

    /// 8. Stately Library & Archive
    private func drawPixelLibrary() -> SKTexture {
        let buf = PixelBuffer(width: 64, height: 72)

        let brick = pixelColor(148, 72, 60)
        let brickShadow = pixelColor(112, 52, 42)
        let stoneQuoin = pixelColor(210, 204, 192)
        let slate = pixelColor(52, 64, 76)
        let slateLight = pixelColor(74, 90, 106)
        let windowStained = pixelColor(72, 148, 204)
        let goldEmblem = pixelColor(245, 200, 60)

        // Drop shadow
        buf.fillRect(x: 10, y: 8, w: 44, h: 8, color: pixelColor(0, 0, 0, 70))

        // Main Hall Walls
        buf.fillRect(x: 14, y: 14, w: 36, h: 26, color: brick)
        buf.fillRect(x: 32, y: 14, w: 18, h: 26, color: brickShadow)

        // Corner Stone Quoins
        for qy in stride(from: 14, to: 38, by: 4) {
            buf.fillRect(x: 14, y: qy, w: 3, h: 2, color: stoneQuoin)
            buf.fillRect(x: 47, y: qy, w: 3, h: 2, color: stoneQuoin)
        }

        // Tall Arched Stained Glass Windows
        for wx in [20, 28, 40] {
            buf.fillRect(x: wx, y: 22, w: 5, h: 14, color: windowStained)
            buf.setPixel(wx + 2, 35, stoneQuoin) // Arch top
            buf.drawHLine(x1: wx, x2: wx + 4, y: 28, color: pixelColor(28, 24, 20))
        }

        // Grand Arched Doorway
        buf.fillRect(x: 30, y: 14, w: 8, h: 12, color: pixelColor(64, 38, 20))
        buf.fillRect(x: 29, y: 26, w: 10, h: 2, color: stoneQuoin)

        // High Mansard Slate Roof
        for ry in 0..<18 {
            let y = 40 + ry
            let span = max(2, 20 - ry)
            buf.drawHLine(x1: 32 - span, x2: 32, y: y, color: slateLight)
            buf.drawHLine(x1: 32, x2: 32 + span, y: y, color: slate)
            if ry % 3 == 0 {
                buf.drawHLine(x1: 32 - span, x2: 32 + span, y: y, color: pixelColor(32, 40, 50))
            }
        }

        // Golden Open Book Emblem on roof ridge
        buf.fillRect(x: 29, y: 58, w: 6, h: 4, color: goldEmblem)
        buf.drawVLine(x: 32, y1: 58, y2: 61, color: pixelColor(40, 28, 12))

        return buf.toSKTexture()
    }

    /// 9. Blacksmith & Carpentry Workshop
    private func drawPixelWorkshop() -> SKTexture {
        let buf = PixelBuffer(width: 64, height: 64)

        let timber = pixelColor(96, 58, 32)
        let wallPlaster = pixelColor(218, 208, 186)
        let brickForge = pixelColor(164, 68, 48)
        let ironAnvil = pixelColor(48, 52, 58)
        let anvilLight = pixelColor(96, 102, 112)
        let emberOrange = pixelColor(255, 120, 30)
        let woodLogs = pixelColor(142, 92, 54)
        let logRing = pixelColor(198, 142, 96)

        // Drop shadow
        buf.fillRect(x: 12, y: 8, w: 40, h: 8, color: pixelColor(0, 0, 0, 70))

        // Open Workshop Timber Base
        buf.fillRect(x: 16, y: 14, w: 32, h: 20, color: wallPlaster)
        buf.fillRect(x: 32, y: 14, w: 16, h: 20, color: pixelColor(186, 176, 156))

        // Timber Framing Posts
        buf.fillRect(x: 16, y: 14, w: 3, h: 20, color: timber)
        buf.fillRect(x: 31, y: 14, w: 3, h: 20, color: timber)
        buf.fillRect(x: 45, y: 14, w: 3, h: 20, color: timber)
        buf.fillRect(x: 16, y: 31, w: 32, h: 3, color: timber)

        // Forge Hearth (Left corner)
        buf.fillRect(x: 18, y: 14, w: 10, h: 10, color: brickForge)
        buf.fillRect(x: 20, y: 17, w: 6, h: 5, color: emberOrange) // Glowing coals
        buf.setPixel(22, 20, pixelColor(255, 230, 120)) // White heat

        // Forge Chimney
        buf.fillRect(x: 18, y: 24, w: 6, h: 24, color: brickForge)
        buf.drawHLine(x1: 17, x2: 24, y: 48, color: pixelColor(64, 64, 64))

        // Anvil on Wooden Tree Stump
        buf.fillRect(x: 34, y: 14, w: 6, h: 5, color: timber) // Stump
        buf.fillRect(x: 33, y: 19, w: 8, h: 4, color: ironAnvil) // Anvil horn
        buf.drawHLine(x1: 33, x2: 40, y: 22, color: anvilLight) // Face highlight

        // Stacked Firewood Logs (Outside right)
        for ly in stride(from: 14, to: 22, by: 4) {
            buf.fillRect(x: 48, y: ly, w: 8, h: 3, color: woodLogs)
            buf.setPixel(48, ly + 1, logRing) // End grain
        }

        // Industrial Sawtooth Forge Roof
        for ry in 0..<14 {
            let y = 33 + ry
            let span = max(2, 16 - ry)
            buf.drawHLine(x1: 32 - span, x2: 32, y: y, color: pixelColor(140, 56, 40))
            buf.drawHLine(x1: 32, x2: 32 + span, y: y, color: pixelColor(96, 36, 26))
        }

        return buf.toSKTexture()
    }

    /// 10. Grand Academic University
    private func drawPixelUniversity() -> SKTexture {
        let buf = PixelBuffer(width: 80, height: 88)

        let stone = pixelColor(204, 198, 188)
        let stoneShadow = pixelColor(162, 156, 146)
        let copperDome = pixelColor(68, 164, 138)
        let copperLight = pixelColor(96, 196, 168)
        let copperDark = pixelColor(46, 124, 102)
        let brassGold = pixelColor(240, 194, 64)
        let windowBlue = pixelColor(88, 150, 200)

        // Drop shadow
        buf.fillRect(x: 12, y: 8, w: 56, h: 10, color: pixelColor(0, 0, 0, 75))

        // Quadrangle Foundation & Facade
        buf.fillRect(x: 16, y: 16, w: 48, h: 28, color: stone)
        buf.fillRect(x: 40, y: 16, w: 24, h: 28, color: stoneShadow)

        // Lower Arched Arcade Portico
        for ax in [20, 28, 48, 56] {
            buf.fillRect(x: ax, y: 16, w: 5, h: 12, color: pixelColor(42, 38, 34))
            buf.fillRect(x: ax + 1, y: 28, w: 3, h: 14, color: windowBlue)
        }

        // Grand Central Portal
        buf.fillRect(x: 36, y: 16, w: 8, h: 16, color: pixelColor(48, 32, 20))
        buf.drawHLine(x1: 35, x2: 44, y: 32, color: brassGold)

        // Roof Balustrade & Cornice
        buf.drawHLine(x1: 14, x2: 65, y: 44, color: stone)
        for bx in stride(from: 16, to: 64, by: 4) {
            buf.setPixel(bx, 45, stone)
        }

        // Grand Oxidized Copper Observatory Dome
        for dy in 0..<18 {
            let y = 46 + dy
            let r = 14
            let dx = Int(sqrt(Double(max(0, r * r - (dy - 9) * (dy - 9)))))
            buf.drawHLine(x1: 40 - dx, x2: 40, y: y, color: copperLight)
            buf.drawHLine(x1: 40, x2: 40 + dx, y: y, color: copperDark)
            // Dome rib highlights
            if dx > 4 {
                buf.setPixel(40 - dx / 2, y, copperLight)
                buf.setPixel(40 + dx / 2, y, copperDome)
            }
        }

        // Top Observatory Cupola & Brass Telescope
        buf.fillRect(x: 38, y: 64, w: 5, h: 6, color: stone)
        // Telescope barrel angled up
        buf.setPixel(41, 70, brassGold)
        buf.setPixel(42, 71, brassGold)
        buf.setPixel(43, 72, brassGold)
        buf.setPixel(44, 73, brassGold)

        return buf.toSKTexture()
    }
}

import SwiftUI
import AppKit

// MARK: - Palette (warm cream, charcoal, muted sage; follows system light/dark)

enum Theme {
    static func color(light: UInt32, dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return NSColor(hex: isDark ? dark : light)
        }))
    }

    static let bg        = color(light: 0xEFEADF, dark: 0x171715)   // sidebar / window
    static let surface   = color(light: 0xF8F5EE, dark: 0x212120)   // main content
    static let raised    = color(light: 0xFFFDF8, dark: 0x292926)   // cards
    static let ink       = color(light: 0x2B2A27, dark: 0xECE8DE)
    static let muted     = color(light: 0x6F6B62, dark: 0xA39E92)
    static let line      = color(light: 0xE2DCCD, dark: 0x37362F)
    static let sage      = color(light: 0x7F9A7C, dark: 0x93AD8F)
    static let sageDeep  = color(light: 0x58765A, dark: 0xA9C3A4)
    static let sageSoft  = color(light: 0xE2E9D9, dark: 0x2C3529)
    static let onSage    = color(light: 0xFFFFFF, dark: 0x14180F)
    static let rest      = color(light: 0x6D9AA5, dark: 0x86B1BC)   // break sessions
    static let danger    = color(light: 0xB4574A, dark: 0xD98577)

    static let wood  = Color(nsColor: NSColor(hex: 0x8A6A45))
    static let stone = Color(nsColor: NSColor(hex: 0x9AA0A6))
    static let metal = Color(nsColor: NSColor(hex: 0xC9A24A))

    static func serif(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }
    static func sans(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }
}

extension NSColor {
    convenience init(hex: UInt32) {
        self.init(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: 1)
    }
}

// MARK: - Cards

extension View {
    func themedCard(padding: CGFloat = 16, radius: CGFloat = 12) -> some View {
        self.padding(padding)
            .background(RoundedRectangle(cornerRadius: radius, style: .continuous).fill(Theme.raised))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).stroke(Theme.line, lineWidth: 1))
    }
}

// MARK: - Buttons

struct PillButtonStyle: ButtonStyle {
    enum Kind { case primary, sage, secondary }
    var kind: Kind = .secondary

    func makeBody(configuration: ButtonStyleConfiguration) -> some View {
        PillBody(configuration: configuration, kind: kind)
    }

    private struct PillBody: View {
        let configuration: ButtonStyleConfiguration
        let kind: Kind
        @State private var hovering = false

        private var fg: Color {
            switch kind {
            case .primary: return Theme.bg
            case .sage: return Theme.onSage
            case .secondary: return Theme.ink
            }
        }
        private var fill: Color {
            switch kind {
            case .primary: return Theme.ink
            case .sage: return Theme.sageDeep
            case .secondary: return Theme.raised
            }
        }

        var body: some View {
            configuration.label
                .font(Theme.sans(14, .medium))
                .foregroundColor(fg)
                .padding(.horizontal, 24)
                .padding(.vertical, 11)
                .frame(minWidth: kind == .secondary ? 0 : 150)
                .background(Capsule().fill(fill))
                .overlay(Capsule().stroke(kind == .secondary ? Theme.line : Color.clear, lineWidth: 1))
                .shadow(color: Color.black.opacity(hovering ? 0.14 : 0), radius: 6, x: 0, y: 2)
                .scaleEffect(configuration.isPressed ? 0.98 : 1)
                .offset(y: hovering && !configuration.isPressed ? -1 : 0)
                .onHover { hovering = $0 }
                .animation(.easeOut(duration: 0.12), value: hovering)
                .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
        }
    }
}

struct SmallButtonStyle: ButtonStyle {
    var destructive: Bool = false
    var prominent: Bool = false

    func makeBody(configuration: ButtonStyleConfiguration) -> some View {
        SmallBody(configuration: configuration, destructive: destructive, prominent: prominent)
    }

    private struct SmallBody: View {
        let configuration: ButtonStyleConfiguration
        let destructive: Bool
        let prominent: Bool
        @State private var hovering = false

        var body: some View {
            configuration.label
                .font(Theme.sans(12, .medium))
                .foregroundColor(prominent ? Theme.onSage : (destructive ? Theme.danger : Theme.ink))
                .padding(.horizontal, 11)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(prominent ? Theme.sageDeep : (hovering ? Theme.sageSoft : Theme.raised))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(prominent ? Color.clear : Theme.line, lineWidth: 1)
                )
                .opacity(configuration.isPressed ? 0.8 : 1)
                .onHover { hovering = $0 }
                .animation(.easeOut(duration: 0.12), value: hovering)
        }
    }
}

// MARK: - Small shared views

struct ResourceChip: View {
    let dot: Color
    let label: String
    let amount: Int

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(dot).frame(width: 8, height: 8)
            Text("\(label) \(amount)")
                .font(Theme.sans(12.5, .medium))
                .monospacedDigit()
                .foregroundColor(Theme.ink)
        }
        .padding(.leading, 9)
        .padding(.trailing, 12)
        .padding(.vertical, 5)
        .background(Capsule().fill(Theme.raised))
        .overlay(Capsule().stroke(Theme.line, lineWidth: 1))
    }
}

struct CostLabel: View {
    let cost: Resources
    var body: some View {
        HStack(spacing: 8) {
            if cost.wood > 0 { part(Theme.wood, cost.wood) }
            if cost.stone > 0 { part(Theme.stone, cost.stone) }
            if cost.metal > 0 { part(Theme.metal, cost.metal) }
            if cost.wood == 0 && cost.stone == 0 && cost.metal == 0 {
                Text("Free").font(Theme.sans(11, .medium)).foregroundColor(Theme.muted)
            }
        }
    }
    private func part(_ c: Color, _ n: Int) -> some View {
        HStack(spacing: 3) {
            Circle().fill(c).frame(width: 7, height: 7)
            Text("\(n)").font(Theme.sans(11, .medium)).monospacedDigit().foregroundColor(Theme.ink)
        }
    }
}

struct MeterBar: View {
    let value: Double
    var tint: Color = Theme.sage
    var height: CGFloat = 5

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.line)
                Capsule().fill(tint)
                    .frame(width: max(height, geo.size.width * CGFloat(min(1, max(0, value)))))
                    .opacity(value > 0 ? 1 : 0)
            }
        }
        .frame(height: height)
        .animation(.easeOut(duration: 0.5), value: value)
    }
}

struct PageHeader<Trailing: View>: View {
    let title: String
    let trailing: Trailing

    init(_ title: String, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .center) {
            Text(title)
                .font(Theme.serif(26, .medium))
                .foregroundColor(Theme.ink)
            Spacer()
            trailing
        }
        .padding(.horizontal, 28)
        .padding(.top, 34)
        .padding(.bottom, 10)
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 26, weight: .light))
                .foregroundColor(Theme.sage)
            Text(title).font(Theme.serif(16, .medium)).foregroundColor(Theme.ink)
            Text(message)
                .font(Theme.sans(12.5))
                .foregroundColor(Theme.muted)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
    }
}

struct SectionTitle: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text).font(Theme.serif(17, .medium)).foregroundColor(Theme.ink)
    }
}

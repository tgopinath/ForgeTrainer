import SwiftUI
import UIKit

enum Theme {
    static let accent = dyn(0x4F46E5, 0x8B87FF)
    static let accentSoft = dyn(0xE8E7FF, 0x24224D)
    // System grouped backgrounds: they already adapt to dark mode and Increase Contrast.
    static let bg = Color(.systemGroupedBackground)
    static let surface = Color(.secondarySystemGroupedBackground)
    static let surface2 = dyn(0xEEF0F5, 0x2C2C2E)
    static let line = dyn(0xE3E5EC, 0x38383A)
    static let ink2 = dyn(0x5B6170, 0xAEAEB2)
    // Darkened from 0x8E93A0 (2.9:1) so captions pass WCAG AA (4.7:1 on the page background).
    static let ink3 = dyn(0x666B7A, 0x98989F)
    static let good = dyn(0x16A34A, 0x34D399)
    static let amber = dyn(0xF59E0B, 0xFBBF24)
    static let amberSoft = dyn(0xFEF3C7, 0x3A2E0F)
    static let warn = dyn(0xE11D48, 0xFB7185)

    static let legs = dyn(0xF26B1D, 0xFF8A3D)
    static let push = dyn(0x3B5BFD, 0x7088FF)
    static let pull = dyn(0x0E9F96, 0x2DD4BF)
    static let core = dyn(0x8B5CF6, 0xA78BFA)
    static let cond = dyn(0xEF3E62, 0xFB7185)

    /// Rounded, heavy — numbers and headlines. The size picks the nearest text style, so it scales with Dynamic Type.
    static func display(_ size: CGFloat) -> Font { .system(style(size), design: .rounded, weight: .heavy) }
    static func mono(_ size: CGFloat, _ w: Font.Weight = .semibold) -> Font { .system(style(size), design: .rounded, weight: w).monospacedDigit() }

    /// Default-size point value → the text style that has that size at the default Dynamic Type setting.
    static func style(_ size: CGFloat) -> Font.TextStyle {
        switch size {
        case 32...: .largeTitle
        case 26..<32: .title
        case 21..<26: .title2
        case 19..<21: .title3
        case 16.5..<19: .body
        case 15..<16.5: .subheadline
        case 13..<15: .footnote
        case 12..<13: .caption
        default: .caption2
        }
    }

    /// Light/dark pair; with Increase Contrast the colour moves a quarter of the way toward black (light) or white (dark).
    private static func dyn(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(UIColor { t in
            let isDark = t.userInterfaceStyle == .dark
            let base = UIColor(hex: isDark ? dark : light)
            guard t.accessibilityContrast == .high else { return base }
            return base.mixed(with: isDark ? .white : .black, by: 0.25)
        })
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }

    func mixed(with other: UIColor, by t: CGFloat) -> UIColor {
        var (r1, g1, b1, a1): (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0)
        var (r2, g2, b2, a2): (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0)
        getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        other.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        return UIColor(red: r1 + (r2 - r1) * t, green: g1 + (g2 - g1) * t, blue: b1 + (b2 - b1) * t, alpha: a1)
    }
}

extension Color {
    /// Hero-card gradient for white text: starts dark enough for WCAG AA on every muscle-group colour.
    func heroGradient(_ start: Double = 0.22, _ end: Double = 0.42) -> LinearGradient {
        LinearGradient(colors: [mix(with: .black, by: start), mix(with: .black, by: end)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

enum MuscleGroup: String, CaseIterable, Identifiable {
    case legs, push, pull, core, cond
    var id: String { rawValue }
    var label: String { [.legs: "Legs", .push: "Push", .pull: "Pull", .core: "Core", .cond: "Cardio"][self]! }
    var detail: String {
        [.legs: "Quads, hamstrings, glutes", .push: "Chest, shoulders, triceps", .pull: "Back, biceps",
         .core: "Abs, obliques", .cond: "Heart, lungs, grip"][self]!
    }
    var color: Color { [.legs: Theme.legs, .push: Theme.push, .pull: Theme.pull, .core: Theme.core, .cond: Theme.cond][self]! }
}

extension Pattern {
    var group: MuscleGroup {
        switch self {
        case .squat, .hinge, .lunge: .legs
        case .hpush, .vpush, .armsPush: .push
        case .hpull, .vpull, .armsPull: .pull
        case .core: .core
        case .carry, .cond: .cond
        }
    }
}

extension PlanDay {
    /// The muscle group with the most sets — sets the day's color.
    var mainGroup: MuscleGroup {
        var c: [MuscleGroup: Int] = [:]
        for it in items { c[it.pattern.group, default: 0] += it.sets }
        return c.max { $0.value < $1.value || ($0.value == $1.value && $0.key.rawValue > $1.key.rawValue) }?.key ?? .legs
    }
    var groups: [MuscleGroup] { MuscleGroup.allCases.filter { g in items.contains { $0.pattern.group == g } } }
}

// MARK: - Components

struct Card<Content: View>: View {
    var padding: CGFloat = 18
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: .black.opacity(0.04), radius: 10, y: 3)
    }
}

struct Eyebrow: View {
    let text: String
    var color: Color = Theme.ink3
    var body: some View {
        Text(text.uppercased()).font(.caption.weight(.bold)).tracking(0.8).foregroundStyle(color)
    }
}

struct SectionTitle: View {
    let text: String
    var trailing: String? = nil
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(text).font(.title3.weight(.bold))
            Spacer()
            if let trailing { Text(trailing).font(.footnote).foregroundStyle(Theme.ink3) }
        }
    }
}

struct Tag: View {
    let text: String
    var tint: Color = Theme.ink2
    var fill: Color = Theme.surface2
    var body: some View {
        Text(text).font(.caption.weight(.semibold))
            .padding(.horizontal, 8).padding(.vertical, 3)
            .foregroundStyle(tint).background(fill, in: Capsule())
    }
}

struct GroupChip: View {
    let group: MuscleGroup
    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(group.color).frame(width: 7, height: 7).accessibilityHidden(true)
            Text(group.label).font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 9).padding(.vertical, 4)
        .foregroundStyle(group.color)
        .background(group.color.opacity(0.12), in: Capsule())
    }
}

struct Ring: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var progress: Double
    var color: Color
    var lineWidth: CGFloat = 9
    var body: some View {
        ZStack {
            Circle().stroke(color.opacity(0.16), lineWidth: lineWidth)
            Circle().trim(from: 0, to: max(0.001, min(1, progress)))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .animation(reduceMotion ? nil : .spring(duration: 0.8), value: progress)
    }
}

/// Full-width call to action on coloured hero cards, where the system prominent style can't put
/// coloured text on a white fill. Elsewhere use `.borderedProminent`.
struct BigButtonStyle: ButtonStyle {
    var fill: Color = Theme.accent
    var text: Color = .white
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.bold))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 16).padding(.vertical, 8)
            .frame(maxWidth: .infinity, minHeight: 54)
            .foregroundStyle(text)
            .background(fill, in: Capsule())
            .opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1) : 0.45)
            .contentShape(Capsule())
    }
}

/// The example-data notice shown until the user sets a goal.
struct ExampleBanner: View {
    var action: () -> Void
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "sparkles").font(.title3).foregroundStyle(Theme.amber).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text("You're looking at example data").font(.subheadline.weight(.bold))
                Text("Set your goal to start fresh.").font(.footnote).foregroundStyle(Theme.ink2)
            }
            Spacer(minLength: 0)
            Button("Set goal", action: action).buttonStyle(.borderedProminent).buttonBorderShape(.capsule)
        }
        .padding(14)
        .background(Theme.amberSoft, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

extension Goal {
    var color: Color { [.muscle: Theme.push, .strength: Theme.accent, .fat: Theme.cond, .endurance: Theme.pull, .general: Theme.legs][self]! }
}

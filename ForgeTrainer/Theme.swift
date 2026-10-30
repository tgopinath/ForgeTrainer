import SwiftUI
import UIKit

enum Theme {
    static let accent = dyn(0x4F46E5, 0x8B87FF)
    static let accentSoft = dyn(0xE8E7FF, 0x24224D)
    static let bg = dyn(0xF2F3F7, 0x000000)
    static let surface = dyn(0xFFFFFF, 0x1C1C1E)
    static let surface2 = dyn(0xEEF0F5, 0x2C2C2E)
    static let line = dyn(0xE3E5EC, 0x38383A)
    static let ink2 = dyn(0x5B6170, 0xAEAEB2)
    static let ink3 = dyn(0x8E93A0, 0x8E8E93)
    static let good = dyn(0x16A34A, 0x34D399)
    static let amber = dyn(0xF59E0B, 0xFBBF24)
    static let amberSoft = dyn(0xFEF3C7, 0x3A2E0F)
    static let warn = dyn(0xE11D48, 0xFB7185)

    static let legs = dyn(0xF26B1D, 0xFF8A3D)
    static let push = dyn(0x3B5BFD, 0x7088FF)
    static let pull = dyn(0x0E9F96, 0x2DD4BF)
    static let core = dyn(0x8B5CF6, 0xA78BFA)
    static let cond = dyn(0xEF3E62, 0xFB7185)

    /// Rounded, heavy — numbers and headlines.
    static func display(_ size: CGFloat) -> Font { .system(size: size, weight: .heavy, design: .rounded) }
    static func mono(_ size: CGFloat, _ w: Font.Weight = .semibold) -> Font { .system(size: size, weight: w, design: .rounded).monospacedDigit() }

    private static func dyn(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light) })
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
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
            Circle().fill(group.color).frame(width: 7, height: 7)
            Text(group.label).font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 9).padding(.vertical, 4)
        .foregroundStyle(group.color)
        .background(group.color.opacity(0.12), in: Capsule())
    }
}

struct Ring: View {
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
        .animation(.spring(duration: 0.8), value: progress)
    }
}

struct BigButtonStyle: ButtonStyle {
    var fill: Color = Theme.accent
    var text: Color = .white
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.bold))
            .frame(maxWidth: .infinity, minHeight: 54)
            .foregroundStyle(text)
            .background(fill, in: Capsule())
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(duration: 0.2), value: configuration.isPressed)
    }
}

/// The example-data notice shown until the user sets a goal.
struct ExampleBanner: View {
    var action: () -> Void
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "sparkles").font(.title3).foregroundStyle(Theme.amber)
            VStack(alignment: .leading, spacing: 1) {
                Text("You're looking at example data").font(.subheadline.weight(.bold))
                Text("Set your goal to start fresh.").font(.footnote).foregroundStyle(Theme.ink2)
            }
            Spacer(minLength: 0)
            Button("Set goal", action: action).buttonStyle(.borderedProminent).buttonBorderShape(.capsule).controlSize(.small)
        }
        .padding(14)
        .background(Theme.amberSoft, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

extension Goal {
    var color: Color { [.muscle: Theme.push, .strength: Theme.accent, .fat: Theme.cond, .endurance: Theme.pull, .general: Theme.legs][self]! }
}

import SwiftUI

/// An animated side-view figure that demonstrates an exercise's movement.
/// Poses are defined by joint angles (degrees; 0 = right, 90 = down) so limb lengths stay constant while animating.
struct ExerciseFigure: View {
    let pattern: Pattern
    var exercise: String = ""
    var color: Color = .primary
    var propColor: Color = .secondary
    var animated = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let motion = Motion.for(pattern, exercise: exercise)
        Group {
            if animated && !reduceMotion {
                TimelineView(.animation) { ctx in
                    let p = ctx.date.timeIntervalSinceReferenceDate / motion.period
                    figure(motion, t: (1 - cos(p * 2 * .pi)) / 2)
                }
            } else {
                figure(motion, t: motion.thumb)
            }
        }
        .accessibilityHidden(true)
    }

    private func figure(_ m: Motion, t: Double) -> some View {
        Canvas { ctx, size in
            let pose = Pose.lerp(m.a, m.b, t).solve()
            let frame = m.bounds
            let s = min(size.width / frame.width, size.height / frame.height)
            let ox = (size.width - frame.width * s) / 2 - frame.minX * s
            let oy = (size.height - frame.height * s) / 2 - frame.minY * s
            func P(_ p: CGPoint) -> CGPoint { CGPoint(x: ox + p.x * s, y: oy + p.y * s) }
            let lw = 6.2 * s

            // floor
            var floor = Path()
            floor.move(to: P(CGPoint(x: frame.minX + 2, y: Pose.floorY + 3.5)))
            floor.addLine(to: P(CGPoint(x: frame.maxX - 2, y: Pose.floorY + 3.5)))
            ctx.stroke(floor, with: .color(propColor.opacity(0.35)), style: StrokeStyle(lineWidth: 1.6 * s, lineCap: .round))

            // props behind the body
            m.prop.drawBehind(ctx, pose: pose, P: P, s: s, color: propColor)

            func limb(_ pts: [CGPoint], opacity: Double = 1) {
                var path = Path()
                path.move(to: P(pts[0]))
                for q in pts.dropFirst() { path.addLine(to: P(q)) }
                ctx.stroke(path, with: .color(color.opacity(opacity)), style: StrokeStyle(lineWidth: lw, lineCap: .round, lineJoin: .round))
            }
            if let k2 = pose.knee2, let a2 = pose.ankle2 {
                limb([pose.hip, k2, a2] + (m.a.grounded ? [CGPoint(x: a2.x + 6, y: a2.y)] : []), opacity: 0.45)
            }
            limb([pose.hip, pose.shoulder])
            limb([pose.hip, pose.knee, pose.ankle] + (m.a.grounded ? [CGPoint(x: pose.ankle.x + 6, y: pose.ankle.y)] : []))
            limb([pose.shoulder, pose.elbow, pose.hand])
            let hr = 6.6 * s
            ctx.fill(Path(ellipseIn: CGRect(x: P(pose.head).x - hr, y: P(pose.head).y - hr, width: hr * 2, height: hr * 2)), with: .color(color))

            m.prop.drawFront(ctx, pose: pose, P: P, s: s, color: propColor)
        }
    }
}

/// A rounded tile with a figure, tinted by muscle group.
struct FigureTile: View {
    let pattern: Pattern
    var exercise: String = ""
    var size: CGFloat = 56
    var animated = false

    var body: some View {
        let c = pattern.group.color
        ExerciseFigure(pattern: pattern, exercise: exercise, color: c, propColor: c.opacity(0.7), animated: animated)
            .padding(size * 0.12)
            .frame(width: size, height: size)
            .background(c.opacity(0.13), in: RoundedRectangle(cornerRadius: size * 0.28, style: .continuous))
    }
}

// MARK: - Pose model

struct Pose {
    static let floorY: CGFloat = 90
    static let L = (torso: 27.0, neck: 9.0, thigh: 21.0, shin: 21.0, upper: 15.0, fore: 14.0)

    /// grounded: root.x = ankle x, root.y = jump height. Otherwise root = hip position.
    var root: CGPoint
    var grounded = true
    var torso: Double, thigh: Double, shin: Double, upper: Double, fore: Double
    var thigh2: Double? = nil
    var shin2: Double? = nil

    struct Solved { var head, shoulder, elbow, hand, hip, knee, ankle: CGPoint; var knee2, ankle2: CGPoint? }

    static func d(_ deg: Double, _ len: Double) -> CGPoint {
        let r = deg * .pi / 180
        return CGPoint(x: cos(r) * len, y: sin(r) * len)
    }

    func solve() -> Solved {
        let L = Pose.L
        let hip, knee, ankle: CGPoint
        if grounded {
            ankle = CGPoint(x: root.x, y: Pose.floorY - root.y)
            knee = ankle - Pose.d(shin, L.shin)
            hip = knee - Pose.d(thigh, L.thigh)
        } else {
            hip = root
            knee = hip + Pose.d(thigh, L.thigh)
            ankle = knee + Pose.d(shin, L.shin)
        }
        let shoulder = hip + Pose.d(torso, L.torso)
        let head = shoulder + Pose.d(torso, L.neck)
        let elbow = shoulder + Pose.d(upper, L.upper)
        let hand = elbow + Pose.d(fore, L.fore)
        var k2: CGPoint?, a2: CGPoint?
        if let t2 = thigh2, let s2 = shin2 {
            k2 = hip + Pose.d(t2, L.thigh)
            a2 = k2! + Pose.d(s2, L.shin)
        }
        return Solved(head: head, shoulder: shoulder, elbow: elbow, hand: hand, hip: hip, knee: knee, ankle: ankle, knee2: k2, ankle2: a2)
    }

    static func lerp(_ a: Pose, _ b: Pose, _ t: Double) -> Pose {
        func m(_ x: Double, _ y: Double) -> Double { x + (y - x) * t }
        var p = a
        p.root = CGPoint(x: m(a.root.x, b.root.x), y: m(a.root.y, b.root.y))
        p.torso = m(a.torso, b.torso); p.thigh = m(a.thigh, b.thigh); p.shin = m(a.shin, b.shin)
        p.upper = m(a.upper, b.upper); p.fore = m(a.fore, b.fore)
        if let x = a.thigh2, let y = b.thigh2 { p.thigh2 = m(x, y) }
        if let x = a.shin2, let y = b.shin2 { p.shin2 = m(x, y) }
        return p
    }
}

private func + (a: CGPoint, b: CGPoint) -> CGPoint { CGPoint(x: a.x + b.x, y: a.y + b.y) }
private func - (a: CGPoint, b: CGPoint) -> CGPoint { CGPoint(x: a.x - b.x, y: a.y - b.y) }

// MARK: - Props

enum Prop {
    case none, plate, dumbbell, bench, cableBar, cableHandle, seatCableBar, pullBar

    func drawBehind(_ ctx: GraphicsContext, pose: Pose.Solved, P: (CGPoint) -> CGPoint, s: CGFloat, color: Color) {
        let st = StrokeStyle(lineWidth: 2.2 * s, lineCap: .round)
        switch self {
        case .bench:
            let top = pose.hip.y + 4.5
            let r = CGRect(x: P(CGPoint(x: pose.shoulder.x - 12, y: top)).x, y: P(CGPoint(x: 0, y: top)).y,
                           width: (pose.hip.x - pose.shoulder.x + 16) * s, height: 3.5 * s)
            ctx.fill(Path(roundedRect: r, cornerRadius: 1.5 * s), with: .color(color.opacity(0.8)))
            for x in [pose.shoulder.x - 6, pose.hip.x] {
                var leg = Path(); leg.move(to: P(CGPoint(x: x, y: top + 3))); leg.addLine(to: P(CGPoint(x: x, y: Pose.floorY + 3)))
                ctx.stroke(leg, with: .color(color.opacity(0.8)), style: st)
            }
        case .seatCableBar:
            let r = CGRect(x: P(CGPoint(x: pose.hip.x - 9, y: pose.hip.y + 4)).x, y: P(CGPoint(x: 0, y: pose.hip.y + 4)).y,
                           width: 16 * s, height: (Pose.floorY + 3 - pose.hip.y - 4) * s)
            ctx.fill(Path(roundedRect: r, cornerRadius: 2 * s), with: .color(color.opacity(0.35)))
            fallthrough
        case .cableBar, .cableHandle:
            var cable = Path(); cable.move(to: P(pose.hand)); cable.addLine(to: P(CGPoint(x: pose.hand.x, y: -4)))
            ctx.stroke(cable, with: .color(color.opacity(0.55)), style: StrokeStyle(lineWidth: 1.2 * s))
        default: break
        }
    }

    func drawFront(_ ctx: GraphicsContext, pose: Pose.Solved, P: (CGPoint) -> CGPoint, s: CGFloat, color: Color) {
        let h = P(pose.hand)
        switch self {
        case .plate:
            let r = 7.5 * s
            ctx.fill(Path(ellipseIn: CGRect(x: h.x - r, y: h.y - r, width: r * 2, height: r * 2)), with: .color(color))
            let i = 1.8 * s
            ctx.fill(Path(ellipseIn: CGRect(x: h.x - i, y: h.y - i, width: i * 2, height: i * 2)), with: .color(.white.opacity(0.9)))
        case .dumbbell:
            let w = 10 * s, hh = 5.5 * s
            ctx.fill(Path(roundedRect: CGRect(x: h.x - w / 2, y: h.y - hh / 2, width: w, height: hh), cornerRadius: 2 * s), with: .color(color))
        case .cableBar, .seatCableBar, .pullBar:
            var bar = Path(); bar.move(to: CGPoint(x: h.x - 10 * s, y: h.y)); bar.addLine(to: CGPoint(x: h.x + 10 * s, y: h.y))
            ctx.stroke(bar, with: .color(color), style: StrokeStyle(lineWidth: 2.6 * s, lineCap: .round))
        case .cableHandle:
            let r = 3 * s
            ctx.stroke(Path(ellipseIn: CGRect(x: h.x - r, y: h.y - r, width: r * 2, height: r * 2)), with: .color(color), lineWidth: 2 * s)
        default: break
        }
    }
}

// MARK: - Movement library

struct Motion {
    var a: Pose
    var b: Pose
    var period: Double = 2.6
    var prop: Prop = .none
    /// Which moment of the movement a still thumbnail shows (0 = pose a, 1 = pose b).
    var thumb: Double = 0.85

    /// Union of both keyframes so the figure doesn't drift while animating.
    var bounds: CGRect {
        var pts: [CGPoint] = []
        for p in [a.solve(), b.solve(), Pose.lerp(a, b, 0.5).solve()] {
            pts += [p.head, p.shoulder, p.elbow, p.hand, p.hip, p.knee, p.ankle, CGPoint(x: p.ankle.x + 6, y: p.ankle.y)]
            if let k = p.knee2, let an = p.ankle2 { pts += [k, an] }
        }
        let xs = pts.map(\.x), ys = pts.map(\.y)
        var r = CGRect(x: xs.min()! - 9, y: ys.min()! - 9, width: xs.max()! - xs.min()! + 18, height: Pose.floorY + 6 - (ys.min()! - 9))
        let side = max(r.width, r.height)
        r = r.insetBy(dx: -(side - r.width) / 2, dy: 0)
        r.origin.y -= (side - r.height)
        r.size.height = side
        return r
    }

    static func `for`(_ p: Pattern, exercise: String) -> Motion {
        let eq = ExerciseLibrary.equipment(for: exercise)
        let weight: Prop = eq == .gym ? .plate : eq == .db ? .dumbbell : .none
        let g = CGPoint(x: 50, y: 0)
        switch p {
        case .squat:
            let bw = eq == .bw
            let up: (Double, Double) = bw ? (0, 0) : (62, -118)
            return Motion(a: Pose(root: g, torso: -90, thigh: 88, shin: 92, upper: up.0, fore: up.1),
                          b: Pose(root: g, torso: -58, thigh: 8, shin: 112, upper: bw ? 0 : 76, fore: bw ? 0 : -104),
                          prop: exercise == "Leg Press" ? .none : (bw ? .none : weight))
        case .hinge:
            if exercise == "Glute Bridge" {
                return Motion(a: Pose(root: CGPoint(x: 52, y: 86), grounded: false, torso: 182, thigh: -18, shin: 78, upper: 175, fore: 180),
                              b: Pose(root: CGPoint(x: 52, y: 74), grounded: false, torso: 165, thigh: 12, shin: 82, upper: 155, fore: 180))
            }
            return Motion(a: Pose(root: g, torso: -90, thigh: 90, shin: 90, upper: 90, fore: 90),
                          b: Pose(root: g, torso: -25, thigh: 55, shin: 80, upper: 92, fore: 90), prop: weight)
        case .hpush:
            if eq == .bw {
                return Motion(a: Pose(root: CGPoint(x: 58, y: 66), grounded: false, torso: 196, thigh: 15, shin: 15, upper: 90, fore: 90),
                              b: Pose(root: CGPoint(x: 58, y: 76), grounded: false, torso: 186, thigh: 10, shin: 10, upper: 30, fore: 145))
            }
            return Motion(a: Pose(root: CGPoint(x: 62, y: 62), grounded: false, torso: 180, thigh: 20, shin: 95, upper: -90, fore: -90),
                          b: Pose(root: CGPoint(x: 62, y: 62), grounded: false, torso: 180, thigh: 20, shin: 95, upper: 160, fore: -45),
                          prop: .bench, thumb: 0.1)
        case .hpull:
            let cable = exercise == "Seated Cable Row"
            if eq == .bw {
                return Motion(a: Pose(root: CGPoint(x: 48, y: 76), grounded: false, torso: 205, thigh: 5, shin: 30, upper: -90, fore: -90),
                              b: Pose(root: CGPoint(x: 48, y: 66), grounded: false, torso: 195, thigh: 15, shin: 40, upper: 150, fore: -60),
                              prop: .pullBar)
            }
            if cable {
                return Motion(a: Pose(root: CGPoint(x: 40, y: 72), grounded: false, torso: -80, thigh: 0, shin: 80, upper: 10, fore: 0),
                              b: Pose(root: CGPoint(x: 40, y: 72), grounded: false, torso: -95, thigh: 0, shin: 80, upper: 120, fore: -20),
                              prop: .none)
            }
            return Motion(a: Pose(root: g, torso: -25, thigh: 55, shin: 80, upper: 92, fore: 90),
                          b: Pose(root: g, torso: -25, thigh: 55, shin: 80, upper: 192, fore: 95), prop: weight, thumb: 1)
        case .vpush:
            if eq == .bw {
                return Motion(a: Pose(root: CGPoint(x: 50, y: 50), grounded: false, torso: 155, thigh: 70, shin: 75, upper: 90, fore: 90),
                              b: Pose(root: CGPoint(x: 50, y: 50), grounded: false, torso: 140, thigh: 70, shin: 75, upper: 45, fore: 120))
            }
            return Motion(a: Pose(root: g, torso: -90, thigh: 86, shin: 94, upper: 62, fore: -118),
                          b: Pose(root: g, torso: -92, thigh: 86, shin: 94, upper: -68, fore: -78), prop: weight, thumb: 1)
        case .vpull:
            if exercise == "Pull-up" {
                return Motion(a: Pose(root: CGPoint(x: 50, y: 70), grounded: false, torso: -90, thigh: 95, shin: 110, upper: -88, fore: -90),
                              b: Pose(root: CGPoint(x: 50, y: 50), grounded: false, torso: -90, thigh: 100, shin: 120, upper: 130, fore: -60),
                              prop: .pullBar)
            }
            if eq == .gym {
                return Motion(a: Pose(root: CGPoint(x: 45, y: 69), grounded: false, torso: -95, thigh: 0, shin: 92, upper: -80, fore: -92),
                              b: Pose(root: CGPoint(x: 45, y: 69), grounded: false, torso: -95, thigh: 0, shin: 92, upper: 115, fore: -70),
                              prop: .seatCableBar)
            }
            if eq == .db {
                return Motion(a: Pose(root: CGPoint(x: 62, y: 62), grounded: false, torso: 180, thigh: 20, shin: 95, upper: -90, fore: -90),
                              b: Pose(root: CGPoint(x: 62, y: 62), grounded: false, torso: 180, thigh: 20, shin: 95, upper: -165, fore: -170),
                              prop: .bench, thumb: 0.6)
            }
            return Motion(a: Pose(root: g, torso: -112, thigh: 72, shin: 100, upper: -10, fore: -5),
                          b: Pose(root: g, torso: -94, thigh: 80, shin: 96, upper: 150, fore: -30), prop: .cableHandle)
        case .lunge:
            return Motion(a: Pose(root: CGPoint(x: 60, y: 0), torso: -90, thigh: 85, shin: 95, upper: 90, fore: 90, thigh2: 95, shin2: 85),
                          b: Pose(root: CGPoint(x: 60, y: 0), torso: -90, thigh: 0, shin: 90, upper: 90, fore: 90, thigh2: 126, shin2: 175),
                          prop: eq == .bw ? .none : .dumbbell)
        case .core:
            if exercise == "DB Dead Bug" {
                return Motion(a: Pose(root: CGPoint(x: 55, y: 84), grounded: false, torso: 180, thigh: -90, shin: 0, upper: -90, fore: -90),
                              b: Pose(root: CGPoint(x: 55, y: 84), grounded: false, torso: 180, thigh: -10, shin: -5, upper: -170, fore: -175),
                              prop: .dumbbell, thumb: 0.1)
            }
            if exercise == "Cable Pallof Press" {
                return Motion(a: Pose(root: g, torso: -90, thigh: 96, shin: 90, upper: 80, fore: -60),
                              b: Pose(root: g, torso: -90, thigh: 96, shin: 90, upper: 0, fore: 0), prop: .cableHandle)
            }
            return Motion(a: Pose(root: CGPoint(x: 55, y: 80), grounded: false, torso: 190, thigh: 12, shin: 12, upper: 90, fore: 180),
                          b: Pose(root: CGPoint(x: 55, y: 77), grounded: false, torso: 186, thigh: 12, shin: 12, upper: 90, fore: 180),
                          period: 3.2)
        case .armsPush:
            if eq == .bw {
                return Motion(a: Pose(root: CGPoint(x: 44, y: 66), grounded: false, torso: -75, thigh: 0, shin: 90, upper: 150, fore: 95),
                              b: Pose(root: CGPoint(x: 44, y: 76), grounded: false, torso: -75, thigh: -5, shin: 95, upper: 165, fore: 40),
                              prop: .bench)
            }
            if eq == .db {
                return Motion(a: Pose(root: CGPoint(x: 62, y: 62), grounded: false, torso: 180, thigh: 20, shin: 95, upper: -100, fore: -90),
                              b: Pose(root: CGPoint(x: 62, y: 62), grounded: false, torso: 180, thigh: 20, shin: 95, upper: -100, fore: -165),
                              prop: .bench, thumb: 0.7)
            }
            return Motion(a: Pose(root: g, torso: -84, thigh: 90, shin: 90, upper: 95, fore: -40),
                          b: Pose(root: g, torso: -84, thigh: 90, shin: 90, upper: 95, fore: 88), prop: eq == .gym ? .cableBar : .dumbbell)
        case .armsPull:
            return Motion(a: Pose(root: g, torso: -90, thigh: 90, shin: 90, upper: 92, fore: 88),
                          b: Pose(root: g, torso: -90, thigh: 90, shin: 90, upper: 88, fore: -55), prop: eq == .bw ? .none : .dumbbell)
        case .carry:
            if eq == .bw {
                return Motion(a: Pose(root: CGPoint(x: 55, y: 72), grounded: false, torso: 190, thigh: 60, shin: 10, upper: 85, fore: 95),
                              b: Pose(root: CGPoint(x: 55, y: 72), grounded: false, torso: 190, thigh: 80, shin: 0, upper: 100, fore: 80),
                              period: 1.1)
            }
            return Motion(a: Pose(root: g, torso: -88, thigh: 70, shin: 100, upper: 90, fore: 90, thigh2: 110, shin2: 80),
                          b: Pose(root: g, torso: -88, thigh: 110, shin: 80, upper: 90, fore: 90, thigh2: 70, shin2: 100),
                          period: 1.2, prop: .dumbbell)
        case .cond:
            return Motion(a: Pose(root: g, torso: -58, thigh: 8, shin: 112, upper: 5, fore: 0),
                          b: Pose(root: CGPoint(x: 50, y: 9), torso: -90, thigh: 92, shin: 95, upper: -95, fore: -90),
                          period: 1.3, prop: eq == .db ? .dumbbell : .none, thumb: 0.05)
        }
    }
}

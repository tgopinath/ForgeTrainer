import Foundation

enum Pattern: String, Codable, CaseIterable {
    case squat, hinge, hpush, hpull, vpush, vpull, lunge, core, armsPush, armsPull, carry, cond

    var label: String {
        switch self {
        case .squat: "Squat"
        case .hinge: "Hinge"
        case .hpush: "Push"
        case .hpull: "Row"
        case .vpush: "Press"
        case .vpull: "Pull"
        case .lunge: "Single-leg"
        case .core: "Core"
        case .armsPush: "Triceps"
        case .armsPull: "Biceps"
        case .carry: "Carry"
        case .cond: "Conditioning"
        }
    }
    var isLower: Bool { [.squat, .hinge, .lunge].contains(self) }
    var isUnloaded: Bool { self == .cond }
}

struct Exercise: Identifiable, Hashable {
    var id: String { name }
    let name: String
    let equipment: Equipment
    let cue: String
}

enum ExerciseLibrary {
    static let all: [Pattern: [Exercise]] = [
        .squat: [
            .init(name: "Back Squat", equipment: .gym, cue: "Brace hard, sit between the hips, knees track over toes."),
            .init(name: "Leg Press", equipment: .gym, cue: "Feet mid-plate, lower until the hips start to tuck."),
            .init(name: "Goblet Squat", equipment: .db, cue: "Bell at your chest, elbows inside the knees at the bottom."),
            .init(name: "Tempo Air Squat", equipment: .bw, cue: "3 seconds down, pause, drive up."),
        ],
        .hinge: [
            .init(name: "Romanian Deadlift", equipment: .gym, cue: "Soft knees, push hips back, bar stays on the thighs."),
            .init(name: "Trap-bar Deadlift", equipment: .gym, cue: "Chest tall, push the floor away."),
            .init(name: "DB Romanian Deadlift", equipment: .db, cue: "Dumbbells slide down the legs, flat back."),
            .init(name: "Glute Bridge", equipment: .bw, cue: "Ribs down, squeeze glutes for 2 seconds at the top."),
        ],
        .hpush: [
            .init(name: "Bench Press", equipment: .gym, cue: "Shoulder blades pinned, bar to the lower chest."),
            .init(name: "DB Bench Press", equipment: .db, cue: "Elbows about 45°, stretch at the bottom."),
            .init(name: "Push-up", equipment: .bw, cue: "Body in one line, chest to fist height."),
        ],
        .hpull: [
            .init(name: "Barbell Row", equipment: .gym, cue: "Hinge to 45°, pull to the belly button."),
            .init(name: "Seated Cable Row", equipment: .gym, cue: "Lead with the elbows, pause at the ribs."),
            .init(name: "One-arm DB Row", equipment: .db, cue: "Hand on bench, row toward the hip."),
            .init(name: "Inverted Row", equipment: .bw, cue: "Under a sturdy table, pull chest to the edge."),
        ],
        .vpush: [
            .init(name: "Overhead Press", equipment: .gym, cue: "Glutes tight, press and push the head through."),
            .init(name: "Seated DB Press", equipment: .db, cue: "Start at ear height, press slightly in."),
            .init(name: "Pike Push-up", equipment: .bw, cue: "Hips high, head travels in front of the hands."),
        ],
        .vpull: [
            .init(name: "Lat Pulldown", equipment: .gym, cue: "Pull the elbows to your back pockets."),
            .init(name: "Pull-up", equipment: .gym, cue: "Dead-hang start, chin clears the bar."),
            .init(name: "DB Pullover", equipment: .db, cue: "Long arms, feel the lats stretch."),
            .init(name: "Towel Door Row", equipment: .bw, cue: "Towel round a door handle, lean back and pull."),
        ],
        .lunge: [
            .init(name: "Bulgarian Split Squat", equipment: .gym, cue: "Back foot on a bench, front shin vertical."),
            .init(name: "DB Reverse Lunge", equipment: .db, cue: "Step back long, back knee kisses the floor."),
            .init(name: "Walking Lunge", equipment: .bw, cue: "Tall torso, push through the front heel."),
        ],
        .core: [
            .init(name: "Cable Pallof Press", equipment: .gym, cue: "Resist the rotation, press and hold 2s."),
            .init(name: "DB Dead Bug", equipment: .db, cue: "Low back glued down, slow opposite limbs."),
            .init(name: "Plank", equipment: .bw, cue: "Squeeze glutes, push the floor away. Log reps as seconds."),
        ],
        .armsPush: [
            .init(name: "Cable Triceps Pushdown", equipment: .gym, cue: "Elbows pinned, full lockout."),
            .init(name: "DB Skull Crusher", equipment: .db, cue: "Lower to the temples, elbows still."),
            .init(name: "Bench Dip", equipment: .bw, cue: "Shoulders down, 90° at the elbow."),
        ],
        .armsPull: [
            .init(name: "EZ-bar Curl", equipment: .gym, cue: "No swinging, slow on the way down."),
            .init(name: "DB Hammer Curl", equipment: .db, cue: "Neutral grip, squeeze at the top."),
            .init(name: "Towel Isometric Curl", equipment: .bw, cue: "Stand on a towel, pull up hard for the count."),
        ],
        .carry: [
            .init(name: "Farmer Carry", equipment: .gym, cue: "Heavy, tall and quick. Reps = metres ÷ 10."),
            .init(name: "DB Suitcase Carry", equipment: .db, cue: "One side loaded, don't lean."),
            .init(name: "Bear Crawl", equipment: .bw, cue: "Knees an inch off the floor, small steps."),
        ],
        .cond: [
            .init(name: "Rower Intervals", equipment: .gym, cue: "30s hard / 30s easy. Reps = rounds."),
            .init(name: "DB Thruster Finisher", equipment: .db, cue: "Squat into a press, steady breathing."),
            .init(name: "Burpee Intervals", equipment: .bw, cue: "20s on / 40s off. Reps = rounds."),
        ],
    ]

    static func options(_ p: Pattern, for eq: Equipment) -> [Exercise] {
        (all[p] ?? []).filter { eq.allowed.contains($0.equipment) }
    }
    static func pick(_ p: Pattern, for eq: Equipment) -> String {
        for e in eq.allowed { if let f = all[p]?.first(where: { $0.equipment == e }) { return f.name } }
        return all[p]?.first?.name ?? p.label
    }
    static func equipment(for name: String) -> Equipment {
        for list in all.values { if let f = list.first(where: { $0.name == name }) { return f.equipment } }
        return .bw
    }
    static func pattern(for name: String) -> Pattern {
        for (p, list) in all where list.contains(where: { $0.name == name }) { return p }
        return .core
    }
    static func cue(for name: String) -> String {
        for list in all.values { if let f = list.first(where: { $0.name == name }) { return f.cue } }
        return ""
    }
}

// MARK: - Plan builder

enum PlanBuilder {
    private struct Template { let name: String; let focus: String; let patterns: [Pattern] }
    private static let t: [String: Template] = [
        "fullA": .init(name: "Full Body A", focus: "Squat · push · row", patterns: [.squat, .hpush, .hpull, .core]),
        "fullB": .init(name: "Full Body B", focus: "Hinge · press · pull", patterns: [.hinge, .vpush, .vpull, .lunge]),
        "fullC": .init(name: "Full Body C", focus: "Single-leg · push · carry", patterns: [.lunge, .hpush, .vpull, .carry]),
        "upperA": .init(name: "Upper A", focus: "Chest · back · arms", patterns: [.hpush, .hpull, .vpush, .armsPull, .armsPush]),
        "lowerA": .init(name: "Lower A", focus: "Squat-led legs", patterns: [.squat, .hinge, .lunge, .core]),
        "upperB": .init(name: "Upper B", focus: "Shoulders · lats", patterns: [.vpush, .vpull, .hpush, .hpull, .armsPush]),
        "lowerB": .init(name: "Lower B", focus: "Hinge-led legs", patterns: [.hinge, .squat, .lunge, .carry]),
        "push": .init(name: "Push", focus: "Chest · shoulders · triceps", patterns: [.hpush, .vpush, .armsPush, .core]),
        "pull": .init(name: "Pull", focus: "Back · biceps", patterns: [.vpull, .hpull, .armsPull, .carry]),
        "legs": .init(name: "Legs", focus: "Quads · hamstrings · glutes", patterns: [.squat, .hinge, .lunge, .core]),
    ]
    private static let splits: [Int: [String]] = [
        1: ["fullA"], 2: ["fullA", "fullB"], 3: ["fullA", "fullB", "fullC"],
        4: ["upperA", "lowerA", "upperB", "lowerB"],
        5: ["push", "pull", "legs", "upperB", "lowerB"],
        6: ["push", "pull", "legs", "push", "pull", "legs"],
        7: ["push", "pull", "legs", "upperA", "lowerA", "fullC", "fullA"],
    ]
    /// Monday-first ordering of Calendar weekdays.
    static let weekOrder = [2, 3, 4, 5, 6, 7, 1]

    static func splitName(forDays n: Int) -> String {
        n <= 3 ? "full-body sessions" : n == 4 ? "upper / lower split" : "push / pull / legs split"
    }

    static func build(_ p: Profile) -> Plan {
        let g = p.goal
        let days = weekOrder.filter { p.days.contains($0) }
        let split = splits[max(1, min(7, days.count))] ?? splits[3]!
        let adj = p.level == .beginner ? -1 : p.level == .advanced ? 1 : 0
        let planDays: [PlanDay] = split.map { key in
            let tpl = t[key]!
            var items = tpl.patterns.enumerated().map { i, pat in
                PlanItem(
                    pattern: pat,
                    exercise: ExerciseLibrary.pick(pat, for: p.equipment),
                    sets: max(2, g.sets + adj - (i >= 3 ? 1 : 0)),
                    reps: pat == .core ? (g == .strength ? "30s" : "40s") : pat == .carry ? "4" : g.reps,
                    rest: (pat == .core || pat == .carry) ? min(g.rest, 60) : g.rest)
            }
            if g.finisher {
                items.append(PlanItem(pattern: .cond, exercise: ExerciseLibrary.pick(.cond, for: p.equipment),
                                      sets: p.level == .beginner ? 4 : 6, reps: "1", rest: 30))
            }
            return PlanDay(name: tpl.name, focus: tpl.focus, items: items)
        }
        var schedule: [Int: Int] = [:]
        for (i, wd) in days.enumerated() { schedule[wd] = i }
        return Plan(days: planDays, schedule: schedule)
    }
}

extension String {
    /// Top of a rep range ("8-12" → 12, "40s" → 40).
    var repsTop: Int {
        let nums = split(whereSeparator: { !$0.isNumber }).compactMap { Int($0) }
        return nums.last ?? 10
    }
}

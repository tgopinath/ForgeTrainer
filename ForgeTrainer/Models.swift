import Foundation

// MARK: - Goal & profile

enum Goal: String, Codable, CaseIterable, Identifiable {
    case muscle, strength, fat, endurance, general
    var id: String { rawValue }

    var label: String {
        switch self {
        case .muscle: "Build muscle"
        case .strength: "Get stronger"
        case .fat: "Lose fat"
        case .endurance: "Endurance"
        case .general: "Stay fit"
        }
    }
    var blurb: String {
        switch self {
        case .muscle: "Hypertrophy · 8–12 reps"
        case .strength: "Heavy · 3–6 reps"
        case .fat: "Circuits + finishers"
        case .endurance: "High reps, short rest"
        case .general: "Balanced full body"
        }
    }
    var symbol: String {
        switch self {
        case .muscle: "figure.strengthtraining.traditional"
        case .strength: "dumbbell.fill"
        case .fat: "flame.fill"
        case .endurance: "figure.run"
        case .general: "heart.fill"
        }
    }
    var sets: Int { [.muscle: 4, .strength: 5, .fat: 3, .endurance: 3, .general: 3][self]! }
    var reps: String { [.muscle: "8-12", .strength: "5", .fat: "12-15", .endurance: "15-20", .general: "10"][self]! }
    var rest: Int { [.muscle: 90, .strength: 180, .fat: 45, .endurance: 30, .general: 60][self]! }
    var finisher: Bool { self == .fat || self == .endurance }
}

enum Level: String, Codable, CaseIterable, Identifiable {
    case beginner, intermediate, advanced
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
}

enum Equipment: String, Codable, CaseIterable, Identifiable {
    case gym, db, bw
    var id: String { rawValue }
    var label: String { [.gym: "Full gym", .db: "Dumbbells", .bw: "Bodyweight"][self]! }
    /// Which library tags this setup can use, best first.
    var allowed: [Equipment] { [.gym: [.gym, .db, .bw], .db: [.db, .bw], .bw: [.bw]][self]! }
}

enum WeightUnit: String, Codable, CaseIterable, Identifiable {
    case kg, lb
    var id: String { rawValue }
}

struct Profile: Codable, Equatable {
    var name: String = ""
    var goal: Goal = .muscle
    var level: Level = .intermediate
    /// Calendar weekday numbers: 1 = Sunday … 7 = Saturday.
    var days: Set<Int> = [2, 4, 6]
    var equipment: Equipment = .gym
    var unit: WeightUnit = .kg
    var startWeight: Double = 78
    var targetWeight: Double = 74
    var targetDate: Date = Calendar.current.date(byAdding: .day, value: 84, to: .now)!
    var waterGoal: Int = 8
    var remindersOn: Bool = false
    var reminderHour: Int = 18
    var reminderMinute: Int = 0
}

// MARK: - Plan

struct PlanItem: Codable, Identifiable, Equatable {
    var id = UUID()
    var pattern: Pattern
    var exercise: String
    var sets: Int
    var reps: String
    var rest: Int
}

struct PlanDay: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var focus: String
    var items: [PlanItem]

    var workingSets: Int { items.reduce(0) { $0 + $1.sets } }
    var estimatedMinutes: Int { items.reduce(0) { $0 + $1.sets * (45 + $1.rest) } / 60 + 6 }
}

struct Plan: Codable, Equatable {
    var days: [PlanDay]
    /// weekday (1…7) → index into `days`
    var schedule: [Int: Int]
}

// MARK: - Logging

struct LoggedSet: Codable, Equatable {
    var weight: Double
    var reps: Int
}

struct LoggedExercise: Codable, Equatable {
    var exercise: String
    var pattern: Pattern
    var sets: [LoggedSet]
}

struct Session: Codable, Identifiable, Equatable {
    var id = UUID()
    var date: Date
    var dayName: String
    var minutes: Int
    var volume: Double
    var setsDone: Int
    var setsPlanned: Int
    var exercises: [LoggedExercise]
}

struct WeightEntry: Codable, Identifiable, Equatable {
    var id = UUID()
    var date: Date
    var weight: Double
}

struct Habit: Codable, Equatable {
    var water: Int = 0
    var sleep: Double = 0
    var energy: Int = 0
}

struct LastLift: Codable, Equatable {
    var weight: Double
    var reps: Int
    var hitAllTargets: Bool
}

struct ActiveSet: Codable, Equatable, Identifiable {
    var id = UUID()
    var weight: String
    var reps: String
    var done: Bool = false
}

struct ActiveWorkout: Codable, Equatable {
    var dayIndex: Int
    var started: Date
    var sets: [UUID: [ActiveSet]]
}

struct ChatMessage: Codable, Identifiable, Equatable {
    enum Role: String, Codable { case user, coach }
    var id = UUID()
    var role: Role
    var text: String
}

struct AppData: Codable {
    var version = 1
    var isExample: Bool
    var profile: Profile
    var plan: Plan
    var sessions: [Session] = []
    var weights: [WeightEntry] = []
    var lastLifts: [String: LastLift] = [:]
    /// "yyyy-MM-dd" → habit
    var habits: [String: Habit] = [:]
    var active: ActiveWorkout?
    var chat: [ChatMessage] = []
}

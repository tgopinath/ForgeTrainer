import Foundation
import Observation

@MainActor
@Observable
final class Store {
    var data: AppData {
        didSet { scheduleSave() }
    }
    /// Index of a workout the user picked instead of today's scheduled one.
    var swappedDay: Int?

    private let url: URL = {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("forge-trainer.json")
    }()
    private var saveTask: Task<Void, Never>?

    init() {
        if CommandLine.arguments.contains("-uiTestReset") { try? FileManager.default.removeItem(at: url) }
        if let raw = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder.forge.decode(AppData.self, from: raw) {
            data = decoded
        } else {
            data = Store.exampleData()
        }
        #if DEBUG
        // Portfolio screenshots: the sample trainee, without the example-data banner.
        if CommandLine.arguments.contains("-portfolioDemo") {
            data = Store.exampleData()
            data.isExample = false
        }
        #endif
    }

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled, let self else { return }
            self.saveNow()
        }
    }

    func saveNow() {
        trim()
        guard let raw = try? JSONEncoder.forge.encode(data) else { return }
        try? raw.write(to: url, options: [.atomic, .completeFileProtection])
    }

    private func trim() {
        if data.sessions.count > 500 { data.sessions.removeFirst(data.sessions.count - 500) }
        if data.chat.count > 40 { data.chat.removeFirst(data.chat.count - 40) }
        let cutoff = Day.key(Calendar.current.date(byAdding: .day, value: -120, to: .now)!)
        for k in data.habits.keys where k < cutoff { data.habits.removeValue(forKey: k) }
    }

    // MARK: Profile & plan

    var profile: Profile { data.profile }
    var plan: Plan { data.plan }
    var unit: String { data.profile.unit.rawValue }

    func startFresh(with p: Profile) {
        data = AppData(isExample: false, profile: p, plan: PlanBuilder.build(p),
                       weights: [WeightEntry(date: .now, weight: p.startWeight)])
        swappedDay = nil
        Reminders.sync(profile: p)
    }

    /// Saves goal edits. Rebuilds the plan when anything that shapes it changed.
    @discardableResult
    func updateGoal(_ p: Profile, currentWeight: Double) -> Bool {
        let old = data.profile
        var p = p
        let rebuild = old.goal != p.goal || old.level != p.level || old.equipment != p.equipment || old.days != p.days
        if old.goal != p.goal { p.startWeight = currentWeight }
        data.profile = p
        if currentWeight != self.currentWeight { logWeight(currentWeight) }
        if rebuild { data.plan = PlanBuilder.build(p); data.active = nil }
        swappedDay = nil
        Reminders.sync(profile: p)
        return rebuild
    }

    func rebuildPlan() { data.plan = PlanBuilder.build(data.profile) }

    func item(_ id: UUID) -> (day: Int, index: Int)? {
        for (d, day) in data.plan.days.enumerated() {
            if let i = day.items.firstIndex(where: { $0.id == id }) { return (d, i) }
        }
        return nil
    }

    // MARK: Today

    var scheduledIndexToday: Int? { data.plan.schedule[Calendar.current.component(.weekday, from: .now)] }
    var todaysIndex: Int? { swappedDay ?? scheduledIndexToday }
    var todaysDay: PlanDay? { todaysIndex.map { data.plan.days[$0] } }
    var sessionsToday: [Session] { data.sessions.filter { Calendar.current.isDateInToday($0.date) } }

    func nextTraining() -> (day: PlanDay, label: String)? {
        for i in 1...7 {
            let d = Calendar.current.date(byAdding: .day, value: i, to: .now)!
            if let idx = data.plan.schedule[Calendar.current.component(.weekday, from: d)] {
                return (data.plan.days[idx], i == 1 ? "tomorrow" : d.formatted(.dateTime.weekday(.wide)))
            }
        }
        return nil
    }

    var habitToday: Habit {
        get { data.habits[Day.key(.now)] ?? Habit() }
        set { data.habits[Day.key(.now)] = newValue }
    }

    // MARK: Weight & goal progress

    var currentWeight: Double { data.weights.last?.weight ?? data.profile.startWeight }

    func logWeight(_ w: Double) {
        if let i = data.weights.firstIndex(where: { Calendar.current.isDateInToday($0.date) }) {
            data.weights[i].weight = w
        } else {
            data.weights.append(WeightEntry(date: .now, weight: w))
        }
        data.weights.sort { $0.date < $1.date }
    }

    var goalPercent: Double {
        let span = data.profile.startWeight - data.profile.targetWeight
        guard span != 0 else { return 1 }
        return min(1, max(0, (data.profile.startWeight - currentWeight) / span))
    }
    var daysLeft: Int {
        Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: .now),
                                        to: Calendar.current.startOfDay(for: data.profile.targetDate)).day ?? 0
    }

    // MARK: Consistency

    var thisWeek: [(weekday: Int, planned: Bool, done: Bool, isToday: Bool)] {
        let mon = Day.monday(of: .now)
        return PlanBuilder.weekOrder.enumerated().map { i, wd in
            let date = Calendar.current.date(byAdding: .day, value: i, to: mon)!
            let done = data.sessions.contains { Calendar.current.isDate($0.date, inSameDayAs: date) }
            return (wd, data.plan.schedule[wd] != nil, done, Calendar.current.isDateInToday(date))
        }
    }
    var sessionsThisWeek: Int { thisWeek.filter(\.done).count }

    /// Consecutive completed weeks (before this one) that hit the weekly target.
    var weekStreak: Int {
        let target = data.profile.days.count
        var streak = 0
        var mon = Calendar.current.date(byAdding: .day, value: -7, to: Day.monday(of: .now))!
        for _ in 0..<52 {
            let end = Calendar.current.date(byAdding: .day, value: 7, to: mon)!
            let days = Set(data.sessions.filter { $0.date >= mon && $0.date < end }.map { Day.key($0.date) })
            if days.count >= target { streak += 1 } else { break }
            mon = Calendar.current.date(byAdding: .day, value: -7, to: mon)!
        }
        return streak
    }

    var volumeLast7Days: Double {
        let from = Calendar.current.date(byAdding: .day, value: -6, to: Calendar.current.startOfDay(for: .now))!
        return data.sessions.filter { $0.date >= from }.reduce(0) { $0 + $1.volume }
    }

    var bestLifts: [(exercise: String, set: LoggedSet)] {
        var best: [String: LoggedSet] = [:]
        for s in data.sessions {
            for e in s.exercises where !e.pattern.isUnloaded {
                for st in e.sets where st.weight > 0 {
                    if let b = best[e.exercise], b.weight > st.weight || (b.weight == st.weight && b.reps >= st.reps) { continue }
                    best[e.exercise] = st
                }
            }
        }
        return best.map { ($0.key, $0.value) }.sorted { $0.set.weight > $1.set.weight }
    }

    /// Sets per muscle group over the last `weeks` weeks (oldest first), for the stacked chart.
    func weeklySetsByGroup(weeks: Int = 8) -> [(week: Date, group: MuscleGroup, sets: Int)] {
        let cal = Calendar.current
        let thisMon = Day.monday(of: .now)
        var out: [(Date, MuscleGroup, Int)] = []
        for w in stride(from: weeks - 1, through: 0, by: -1) {
            let start = cal.date(byAdding: .day, value: -7 * w, to: thisMon)!
            let end = cal.date(byAdding: .day, value: 7, to: start)!
            var c: [MuscleGroup: Int] = [:]
            for s in data.sessions where s.date >= start && s.date < end {
                for e in s.exercises { c[e.pattern.group, default: 0] += e.sets.count }
            }
            for g in MuscleGroup.allCases { out.append((start, g, c[g] ?? 0)) }
        }
        return out
    }

    /// Planned weekly sets per muscle group.
    var plannedSetsByGroup: [(group: MuscleGroup, sets: Int)] {
        var c: [MuscleGroup: Int] = [:]
        for idx in data.plan.schedule.values {
            for it in data.plan.days[idx].items { c[it.pattern.group, default: 0] += it.sets }
        }
        return MuscleGroup.allCases.compactMap { g in c[g].map { (g, $0) } }
    }

    func lastSession(of exercise: String) -> LoggedExercise? {
        for s in data.sessions.reversed() { if let e = s.exercises.first(where: { $0.exercise == exercise }) { return e } }
        return nil
    }

    // MARK: Workout logging

    func suggestedWeight(_ it: PlanItem) -> Double? {
        guard !it.pattern.isUnloaded, let last = data.lastLifts[it.exercise] else { return nil }
        guard last.hitAllTargets else { return last.weight }
        let lb = data.profile.unit == .lb
        let step = (it.pattern.isLower ? 5.0 : 2.5) * (lb ? 2 : 1)
        return (last.weight + step).rounded(toNearest: lb ? 5 : 1.25)
    }

    func startWorkout(_ dayIndex: Int) {
        let day = data.plan.days[dayIndex]
        var sets: [UUID: [ActiveSet]] = [:]
        for it in day.items {
            let w = suggestedWeight(it).map { $0.clean } ?? ""
            sets[it.id] = (0..<it.sets).map { _ in ActiveSet(weight: w, reps: "") }
        }
        data.active = ActiveWorkout(dayIndex: dayIndex, started: .now, sets: sets)
    }

    func discardWorkout() { data.active = nil }

    /// Returns the saved session, or nil if no set was ticked.
    func finishWorkout() -> Session? {
        guard let a = data.active else { return nil }
        let day = data.plan.days[a.dayIndex]
        var volume = 0.0, done = 0, planned = 0
        var logged: [LoggedExercise] = []
        for it in day.items {
            let rows = a.sets[it.id] ?? []
            planned += rows.count
            let ds = rows.filter(\.done).map {
                LoggedSet(weight: Double($0.weight.replacingOccurrences(of: ",", with: ".")) ?? 0,
                          reps: Int($0.reps) ?? it.reps.repsTop)
            }
            guard !ds.isEmpty else { continue }
            done += ds.count
            volume += ds.reduce(0) { $0 + $1.weight * Double($1.reps) }
            let timed = it.reps.contains("s")
            let all = ds.count >= it.sets && ds.allSatisfy { timed || $0.reps >= it.reps.repsTop }
            data.lastLifts[it.exercise] = LastLift(weight: ds.map(\.weight).max() ?? 0, reps: ds.last!.reps, hitAllTargets: all)
            logged.append(LoggedExercise(exercise: it.exercise, pattern: it.pattern, sets: ds))
        }
        guard done > 0 else { return nil }
        let s = Session(date: .now, dayName: day.name,
                        minutes: max(1, Int(Date.now.timeIntervalSince(a.started) / 60)),
                        volume: volume.rounded(), setsDone: done, setsPlanned: planned, exercises: logged)
        data.sessions.append(s)
        data.active = nil
        swappedDay = nil
        return s
    }

    // MARK: Example data

    static func exampleData() -> AppData {
        var p = Profile()
        p.name = "Alex"
        p.startWeight = 79.2
        p.targetWeight = 75
        let plan = PlanBuilder.build(p)
        var d = AppData(isExample: true, profile: p, plan: plan)
        let base: [String: Double] = ["Back Squat": 70, "Bench Press": 55, "Barbell Row": 50, "Romanian Deadlift": 70,
                                      "Overhead Press": 35, "Lat Pulldown": 50, "Bulgarian Split Squat": 16,
                                      "Farmer Carry": 24, "Cable Pallof Press": 10]
        let cal = Calendar.current
        for back in stride(from: 34, through: 1, by: -1) {
            let date = cal.date(byAdding: .day, value: -back, to: .now)!
            guard let idx = plan.schedule[cal.component(.weekday, from: date)], back % 11 != 0 else { continue }
            let day = plan.days[idx]
            let week = Double((34 - back) / 7)
            var vol = 0.0
            let ex: [LoggedExercise] = day.items.map { it in
                let w = it.pattern.isUnloaded ? 0 : ((base[it.exercise] ?? 12) + week * (it.pattern.isLower ? 2.5 : 1.25)).rounded(toNearest: 2.5)
                let r = it.reps.repsTop - back % 3
                let sets = Array(repeating: LoggedSet(weight: w, reps: r), count: it.sets)
                vol += sets.reduce(0) { $0 + $1.weight * Double($1.reps) }
                d.lastLifts[it.exercise] = LastLift(weight: w, reps: r, hitAllTargets: back % 3 == 0)
                return LoggedExercise(exercise: it.exercise, pattern: it.pattern, sets: sets)
            }
            d.sessions.append(Session(date: date, dayName: day.name, minutes: 52 + (back % 4) * 4, volume: vol.rounded(),
                                      setsDone: day.workingSets, setsPlanned: day.workingSets, exercises: ex))
        }
        for back in stride(from: 35, through: 0, by: -4) {
            let w = (79.2 - Double(35 - back) * 0.07 + (back % 8 == 0 ? -0.1 : 0.2)).rounded(toNearest: 0.1)
            d.weights.append(WeightEntry(date: cal.date(byAdding: .day, value: -back, to: .now)!, weight: w))
        }
        d.habits[Day.key(.now)] = Habit(water: 3, sleep: 7, energy: 4)
        return d
    }
}

// MARK: - Helpers

enum Day {
    static func key(_ d: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: d)
        return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
    }
    static func monday(of d: Date) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2
        return cal.dateInterval(of: .weekOfYear, for: d)!.start
    }
    static func shortName(_ weekday: Int) -> String { Calendar.current.shortWeekdaySymbols[weekday - 1] }
}

extension Double {
    func rounded(toNearest step: Double) -> Double { (self / step).rounded() * step }
    /// "62.5", "60" — no trailing zero.
    var clean: String { String(format: "%g", self) }
    var grouped: String { formatted(.number.precision(.fractionLength(0...1))) }
}

extension JSONEncoder {
    static let forge: JSONEncoder = { let e = JSONEncoder(); e.dateEncodingStrategy = .iso8601; return e }()
}
extension JSONDecoder {
    static let forge: JSONDecoder = { let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601; return d }()
}

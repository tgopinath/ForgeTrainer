import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// The AI coach. Uses Apple's on-device model (Apple Intelligence, iOS 26+) when the
/// device supports it; otherwise falls back to built-in tips drawn from the user's data.
@MainActor
enum Coach {
    static var isOnDeviceAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) { return SystemLanguageModel.default.isAvailable }
        #endif
        return false
    }

    static var unavailableReason: String {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available: return ""
            case .unavailable(.deviceNotEligible): return "This iPhone doesn't support Apple Intelligence, so the coach uses built-in tips."
            case .unavailable(.appleIntelligenceNotEnabled): return "Turn on Apple Intelligence in Settings for full coach answers. Using built-in tips for now."
            case .unavailable(.modelNotReady): return "Apple Intelligence is still downloading. Using built-in tips for now."
            default: return "Apple Intelligence isn't available, so the coach uses built-in tips."
            }
        }
        #endif
        return "Full coach answers need iOS 26 with Apple Intelligence. Using built-in tips for now."
    }

    static func instructions() -> String {
        """
        You are Forge, a friendly, direct personal trainer inside a workout app. Answer using the trainee's data \
        you are given. Be specific to their plan and numbers, practical and brief (under 150 words unless asked for \
        detail). Use short bullet lists where helpful. Never diagnose injuries; suggest seeing a professional for pain.
        """
    }

    static func context(_ s: Store) -> String {
        let p = s.profile
        let df = Date.FormatStyle.dateTime.day().month(.abbreviated)
        let plan = s.plan.days.enumerated().map { i, d in
            let wds = s.plan.schedule.filter { $0.value == i }.keys.sorted().map(Day.shortName).joined(separator: "/")
            return "\(d.name) (\(wds)): " + d.items.map { "\($0.exercise) \($0.sets)x\($0.reps)" }.joined(separator: ", ")
        }.joined(separator: "\n")
        let recent = s.data.sessions.suffix(5).map { x in
            "\(x.date.formatted(df)) \(x.dayName): \(x.setsDone)/\(x.setsPlanned) sets, \(x.minutes) min; " +
            x.exercises.map { e in "\(e.exercise) " + e.sets.map { $0.weight > 0 ? "\($0.weight.clean)x\($0.reps)" : "\($0.reps)" }.joined(separator: ",") }.joined(separator: "; ")
        }.joined(separator: "\n")
        let h = s.habitToday
        return """
        TRAINEE: \(p.name.isEmpty ? "no name given" : p.name), \(p.level.rawValue), equipment: \(p.equipment.label), units: \(p.unit.rawValue).
        GOAL: \(p.goal.label). Weight \(s.currentWeight.clean) (started \(p.startWeight.clean)), target \(p.targetWeight.clean), \(s.daysLeft) days left.
        THIS WEEK: \(s.sessionsThisWeek)/\(p.days.count) sessions. Today's workout: \(s.todaysDay?.name ?? "rest day").
        TODAY'S CHECK-IN: water \(h.water)/\(p.waterGoal) glasses, sleep \(h.sleep.clean) h, energy \(h.energy)/5.
        PLAN:
        \(plan)
        RECENT SESSIONS:
        \(recent.isEmpty ? "none yet" : recent)
        """
    }

    /// Streams the answer through `onText` (the whole answer so far) and returns the final text.
    static func ask(_ question: String, store: Store, onText: @escaping (String) -> Void) async throws -> String {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *), SystemLanguageModel.default.isAvailable {
            let session = LanguageModelSession(instructions: instructions())
            let prompt = context(store) + "\n\nTRAINEE'S QUESTION:\n" + question
            var text = ""
            for try await snap in session.streamResponse(to: prompt) {
                text = snap.content
                onText(text)
            }
            return text
        }
        #endif
        let text = builtInAnswer(question, store: store)
        onText(text)
        return text
    }

    // MARK: Built-in tips (no model available)

    static func builtInAnswer(_ q: String, store s: Store) -> String {
        let lower = q.lowercased()
        let p = s.profile
        let u = p.unit.rawValue
        if lower.contains("sore") || lower.contains("tired") || lower.contains("adjust") {
            let day = s.todaysDay?.name ?? "today's session"
            return """
            For \(day) while you're sore:
            • Drop one set from each exercise and keep 2–3 reps in reserve.
            • Use about 10% less weight than suggested.
            • Spend 5 minutes warming up the sore area first.
            Mild soreness is normal. Sharp or joint pain is not. Skip that movement and check with a professional.
            """
        }
        if lower.contains("eat") || lower.contains("food") || lower.contains("nutrition") || lower.contains("protein") {
            let kg = p.unit == .kg ? s.currentWeight : s.currentWeight / 2.2046
            let protein = Int((kg * (p.goal == .fat ? 2.0 : 1.8)).rounded())
            let calories: String = switch p.goal {
            case .fat: "a 300–500 kcal daily deficit"
            case .muscle: "a small 200–300 kcal surplus"
            default: "roughly maintenance calories"
            }
            return """
            For \(p.goal.label.lowercased()):
            • Protein: about \(protein) g a day, spread over 3–4 meals.
            • Calories: aim for \(calories).
            • Have a carb + protein meal 1–3 hours before training.
            • Water: hit your \(p.waterGoal) glasses — you're at \(s.habitToday.water) today.
            """
        }
        if lower.contains("week") || lower.contains("review") {
            let done = s.sessionsThisWeek, target = p.days.count
            let vol = s.volumeLast7Days.grouped
            return """
            Your week so far:
            • \(done) of \(target) sessions done.
            • \(vol) \(u) lifted in the last 7 days.
            • Current weight \(s.currentWeight.clean) \(u), target \(p.targetWeight.clean) \(u) (\(Int(s.goalPercent * 100))% there).
            \(done >= target ? "You've hit your target — great consistency." : "Book your next session in your calendar so it doesn't slip.")
            """
        }
        if lower.contains("progress") || lower.contains("faster") || lower.contains("plateau") {
            return """
            To progress faster:
            • Finish every set at the target reps — Forge then suggests more weight next time.
            • Keep form strict; add reps before weight.
            • Sleep 7–9 hours. You logged \(s.habitToday.sleep.clean) h last night.
            • Stay consistent: \(s.weekStreak) week streak so far. Aim to keep it going.
            """
        }
        return """
        I can give full answers when Apple Intelligence is available. Meanwhile, try the suggested questions — \
        I can review your week, adjust a workout when you're sore, give food guidance, or help you progress faster.
        """
    }
}

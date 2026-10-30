import SwiftUI

struct TodayView: View {
    @Environment(Store.self) private var store
    @Binding var tab: AppTab
    @Binding var toast: String?
    @State private var detail: PlanItem?

    private var greeting: String {
        let h = Calendar.current.component(.hour, from: .now)
        let part = h < 12 ? "Good morning" : h < 17 ? "Good afternoon" : "Good evening"
        return store.profile.name.isEmpty ? part : "\(part), \(store.profile.name)"
    }

    var body: some View {
        Page {
            if store.data.isExample { ExampleBanner { tab = .goal } }

            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                        .font(.subheadline.weight(.medium)).foregroundStyle(Theme.ink3)
                    Text(greeting).font(.title.weight(.bold)).lineLimit(1).minimumScaleFactor(0.7)
                }
                Spacer()
                Button { tab = .goal } label: {
                    Image(systemName: store.profile.goal.symbol)
                        .font(.headline).foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(store.profile.goal.color, in: Circle())
                }
                .accessibilityLabel("Your goal")
            }
            .padding(.top, 4)

            WeekCircles()

            if let done = store.sessionsToday.last, store.swappedDay == nil {
                DoneHero(session: done) { store.swappedDay = 0 }
            } else if let day = store.todaysDay, let idx = store.todaysIndex {
                WorkoutHero(day: day, swapped: store.swappedDay != nil, onStart: { start(idx) }, menu: { dayMenu })
                exerciseStrip(day)
            } else {
                RestHero(next: store.nextTraining(), menu: { dayMenu })
            }

            RingsCard()
            HabitsCard(requireReal: requireReal)
        }
        .sheet(item: $detail) { ExerciseDetailSheet(item: $0).environment(store) }
    }

    private func start(_ idx: Int) {
        guard requireReal() else { return }
        store.startWorkout(idx)
        Task { _ = await Reminders.requestPermission() }
    }

    private func requireReal() -> Bool {
        guard store.data.isExample else { return true }
        tab = .goal
        toast = "Set your goal first — then the log is yours"
        return false
    }

    private var dayMenu: some View {
        Menu {
            Section("Switch workout") {
                ForEach(Array(store.plan.days.enumerated()), id: \.element.id) { i, d in
                    Button(d.name) { store.swappedDay = i }
                }
            }
            if store.swappedDay != nil { Button("Back to today's plan") { store.swappedDay = nil } }
        } label: {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.subheadline.weight(.bold))
                .frame(width: 36, height: 36)
                .background(.white.opacity(0.22), in: Circle())
                .foregroundStyle(.white)
        }
        .accessibilityLabel("Switch workout")
    }

    /// A swipeable row of exercise figures — tap one for how-to and targets.
    private func exerciseStrip(_ day: PlanDay) -> some View {
        ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: 12) {
                ForEach(day.items) { it in
                    Button { detail = it } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            FigureTile(pattern: it.pattern, exercise: it.exercise, size: 96)
                            Text(it.exercise).font(.footnote.weight(.semibold)).foregroundStyle(.primary)
                                .lineLimit(2, reservesSpace: true).multilineTextAlignment(.leading)
                            Text("\(it.sets) × \(it.reps)").font(Theme.mono(12, .medium)).foregroundStyle(Theme.ink3)
                        }
                        .frame(width: 96, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(it.exercise)
                }
            }
            .padding(.horizontal, 16)
        }
        .scrollIndicators(.hidden)
        .padding(.horizontal, -16)
    }
}

struct ExerciseRow: View {
    @Environment(Store.self) private var store
    let item: PlanItem
    var index: Int? = nil

    var body: some View {
        HStack(spacing: 14) {
            FigureTile(pattern: item.pattern, exercise: item.exercise, size: 52)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.exercise).font(.body.weight(.semibold)).foregroundStyle(.primary)
                HStack(spacing: 6) {
                    Text("\(item.sets) × \(item.reps)").font(Theme.mono(14))
                    if let w = store.suggestedWeight(item) {
                        Text("·").foregroundStyle(Theme.ink3)
                        Text("\(w.clean) \(store.unit)").font(Theme.mono(14))
                    }
                }
                .foregroundStyle(Theme.ink2)
            }
            Spacer(minLength: 4)
            Image(systemName: "chevron.right").font(.footnote.weight(.bold)).foregroundStyle(Theme.ink3)
        }
        .padding(10)
        .contentShape(Rectangle())
    }
}

// MARK: - Hero cards

struct WorkoutHero<M: View>: View {
    @Environment(Store.self) private var store
    let day: PlanDay
    let swapped: Bool
    var onStart: () -> Void
    @ViewBuilder var menu: () -> M

    var body: some View {
        let c = day.mainGroup.color
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Eyebrow(text: swapped ? "Swapped workout" : "Today", color: .white.opacity(0.75))
                    Text(day.name).font(Theme.display(34)).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.7)
                    Text(day.focus).font(.subheadline.weight(.medium)).foregroundStyle(.white.opacity(0.8))
                }
                Spacer()
                menu()
            }
            HStack(alignment: .bottom) {
                Text("\(day.estimatedMinutes) min  ·  \(day.items.count) exercises")
                    .font(.subheadline.weight(.semibold)).foregroundStyle(.white.opacity(0.9))
                Spacer()
                ExerciseFigure(pattern: day.items.first?.pattern ?? .squat, exercise: day.items.first?.exercise ?? "",
                               color: .white, propColor: .white.opacity(0.75))
                    .frame(width: 120, height: 120)
            }
            Button(action: onStart) {
                Label("Start workout", systemImage: "play.fill")
            }
            .buttonStyle(BigButtonStyle(fill: .white, text: c.mix(with: .black, by: 0.15)))
        }
        .padding(20)
        .background(
            LinearGradient(colors: [c, c.mix(with: .black, by: 0.3)], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: c.opacity(0.35), radius: 16, y: 8)
    }

    private func heroStat(_ icon: String, _ text: String) -> some View {
        Label(text, systemImage: icon)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .labelStyle(.titleAndIcon)
    }
}

struct DoneHero: View {
    @Environment(Store.self) private var store
    let session: Session
    var another: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Eyebrow(text: "Done for today", color: .white.opacity(0.8))
                    Text(session.dayName).font(Theme.display(32)).foregroundStyle(.white)
                    Text("Recovery is part of the plan. Eat protein, drink water, sleep well.")
                        .font(.subheadline).foregroundStyle(.white.opacity(0.85))
                }
                Spacer()
                Image(systemName: "checkmark.seal.fill").font(.system(size: 44)).foregroundStyle(.white)
            }
            HStack(spacing: 10) {
                pill("\(session.setsDone)", "sets")
                pill(session.volume.grouped, store.unit)
                pill("\(session.minutes)", "min")
            }
            Button("Log another workout", action: another)
                .buttonStyle(BigButtonStyle(fill: .white.opacity(0.2)))
        }
        .padding(20)
        .background(LinearGradient(colors: [Theme.good, Theme.good.mix(with: .black, by: 0.3)], startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private func pill(_ v: String, _ u: String) -> some View {
        VStack(spacing: 0) {
            Text(v).font(Theme.display(22))
            Text(u).font(.caption.weight(.semibold)).opacity(0.8)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity).padding(.vertical, 10)
        .background(.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 16))
    }
}

struct RestHero<M: View>: View {
    let next: (day: PlanDay, label: String)?
    @ViewBuilder var menu: () -> M

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Eyebrow(text: "Rest day", color: .white.opacity(0.8))
                Text("Recover & recharge").font(Theme.display(28)).foregroundStyle(.white)
                Text("Muscles grow between sessions. A 20–30 min walk or light mobility helps.")
                    .font(.subheadline).foregroundStyle(.white.opacity(0.85))
                if let next {
                    Text("Next: \(next.day.name) \(next.label)").font(.subheadline.weight(.bold)).foregroundStyle(.white).padding(.top, 4)
                }
            }
            Spacer()
            VStack(spacing: 12) {
                menu()
                Image(systemName: "moon.zzz.fill").font(.system(size: 40)).foregroundStyle(.white.opacity(0.9))
            }
        }
        .padding(20)
        .background(LinearGradient(colors: [Theme.core, Theme.core.mix(with: .black, by: 0.35)], startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}

// MARK: - Week & rings

struct WeekCircles: View {
    @Environment(Store.self) private var store

    var body: some View {
        let mon = Day.monday(of: .now)
        HStack(spacing: 0) {
            ForEach(Array(store.thisWeek.enumerated()), id: \.element.weekday) { i, d in
                let date = Calendar.current.date(byAdding: .day, value: i, to: mon)!
                let color = store.plan.schedule[d.weekday].map { store.plan.days[$0].mainGroup.color } ?? Theme.ink3
                VStack(spacing: 6) {
                    Text(Day.shortName(d.weekday).prefix(1)).font(.caption.weight(.bold)).foregroundStyle(d.isToday ? .primary : Theme.ink3)
                    ZStack {
                        if d.done {
                            Circle().fill(Theme.good)
                            Image(systemName: "checkmark").font(.caption.weight(.heavy)).foregroundStyle(.white)
                        } else if d.planned {
                            Circle().stroke(color, lineWidth: 2.5)
                            Text("\(Calendar.current.component(.day, from: date))").font(Theme.mono(13, .bold)).foregroundStyle(color)
                        } else {
                            Circle().fill(Theme.surface2)
                            Text("\(Calendar.current.component(.day, from: date))").font(Theme.mono(13, .medium)).foregroundStyle(Theme.ink3)
                        }
                    }
                    .frame(width: 36, height: 36)
                    .padding(3)
                    .overlay(Circle().stroke(d.isToday ? Color.primary : .clear, lineWidth: 1.5))
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(Day.shortName(d.weekday)): \(d.done ? "trained" : d.planned ? "planned" : "rest")")
            }
        }
    }
}

struct RingsCard: View {
    @Environment(Store.self) private var store

    var body: some View {
        let p = store.profile
        let remaining = abs(store.currentWeight - p.targetWeight).rounded(toNearest: 0.1)
        let week = Double(store.sessionsThisWeek) / Double(max(1, p.days.count))
        Card {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 0) {
                    ring(progress: store.goalPercent, color: Theme.accent, value: "\(Int(store.goalPercent * 100))%",
                         label: "Goal", sub: remaining > 0.05 ? "\(remaining.clean) \(store.unit) to go" : "Reached!")
                        .accessibilityHint("\(store.daysLeft) days left")
                    ring(progress: week, color: Theme.good, value: "\(store.sessionsThisWeek)/\(p.days.count)",
                         label: "This week", sub: "sessions")
                    ring(progress: min(1, Double(store.weekStreak) / 4), color: Theme.amber, value: "\(store.weekStreak)",
                         label: "Streak", sub: store.weekStreak == 1 ? "week" : "weeks", icon: "flame.fill")
                }
            }
        }
    }

    private func ring(progress: Double, color: Color, value: String, label: String, sub: String, icon: String? = nil) -> some View {
        VStack(spacing: 8) {
            ZStack {
                Ring(progress: progress, color: color, lineWidth: 9)
                VStack(spacing: 0) {
                    if let icon { Image(systemName: icon).font(.caption).foregroundStyle(color) }
                    Text(value).font(Theme.display(18)).minimumScaleFactor(0.7)
                }
            }
            .frame(width: 78, height: 78)
            VStack(spacing: 0) {
                Text(label).font(.footnote.weight(.bold))
                Text(sub).font(.caption).foregroundStyle(Theme.ink3).lineLimit(1).minimumScaleFactor(0.8)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Habits

struct HabitsCard: View {
    @Environment(Store.self) private var store
    var requireReal: () -> Bool

    var body: some View {
        let h = store.habitToday
        let goal = store.profile.waterGoal
        HStack(spacing: 10) {
            // Tap adds a glass; long-press resets.
            chip(icon: "drop.fill", color: Theme.push, value: "\(h.water)/\(goal)", label: "Water",
                 progress: Double(h.water) / Double(max(1, goal)))
                .onTapGesture { if requireReal() { store.habitToday.water = min(goal, h.water + 1) } }
                .onLongPressGesture { if requireReal() { store.habitToday.water = 0 } }
                .accessibilityAddTraits(.isButton)
                .accessibilityHint("Tap to add a glass")
            Menu {
                ForEach([5.0, 5.5, 6, 6.5, 7, 7.5, 8, 8.5, 9, 10], id: \.self) { v in
                    Button("\(v.clean) hours") { if requireReal() { store.habitToday.sleep = v } }
                }
            } label: {
                chip(icon: "moon.fill", color: Theme.core, value: h.sleep > 0 ? "\(h.sleep.clean)h" : "–", label: "Sleep",
                     progress: h.sleep / 8)
            }
            .buttonStyle(.plain)
            Menu {
                ForEach((1...5).reversed(), id: \.self) { n in
                    Button(["", "Drained", "Low", "OK", "Good", "Great"][n]) { if requireReal() { store.habitToday.energy = n } }
                }
            } label: {
                chip(icon: "bolt.fill", color: Theme.amber, value: h.energy > 0 ? "\(h.energy)/5" : "–", label: "Energy",
                     progress: Double(h.energy) / 5)
            }
            .buttonStyle(.plain)
        }
        .sensoryFeedback(.selection, trigger: h)
    }

    private func chip(icon: String, color: Color, value: String, label: String, progress: Double) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Ring(progress: progress, color: color, lineWidth: 4)
                Image(systemName: icon).font(.caption.weight(.bold)).foregroundStyle(color)
            }
            .frame(width: 34, height: 34)
            VStack(alignment: .leading, spacing: 0) {
                Text(value).font(Theme.mono(15, .bold)).foregroundStyle(.primary)
                Text(label).font(.caption2.weight(.semibold)).foregroundStyle(Theme.ink3)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12).padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Exercise detail

struct ExerciseDetailSheet: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    let item: PlanItem

    var body: some View {
        let c = item.pattern.group.color
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ExerciseFigure(pattern: item.pattern, exercise: item.exercise, color: c, propColor: c.opacity(0.7))
                    .frame(height: 220)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background(c.opacity(0.12), in: RoundedRectangle(cornerRadius: 28, style: .continuous))

                VStack(alignment: .leading, spacing: 8) {
                    Text(item.exercise).font(.title.weight(.bold))
                    HStack {
                        GroupChip(group: item.pattern.group)
                        Tag(text: item.pattern.label)
                        Tag(text: ExerciseLibrary.equipment(for: item.exercise).label)
                    }
                    Text(item.pattern.group.detail).font(.subheadline).foregroundStyle(Theme.ink2)
                }

                HStack(spacing: 10) {
                    stat("Target", "\(item.sets) × \(item.reps)")
                    stat("Rest", "\(item.rest)s")
                    stat("Try", store.suggestedWeight(item).map { "\($0.clean) \(store.unit)" } ?? "—")
                }

                VStack(alignment: .leading, spacing: 6) {
                    Label("How to", systemImage: "lightbulb.fill").font(.headline).foregroundStyle(c)
                    Text(ExerciseLibrary.cue(for: item.exercise)).font(.body)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.surface2, in: RoundedRectangle(cornerRadius: 18))

                if let last = store.lastSession(of: item.exercise) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Last time").font(.headline)
                        HStack(spacing: 8) {
                            ForEach(Array(last.sets.enumerated()), id: \.offset) { _, s in
                                VStack(spacing: 0) {
                                    Text(s.weight > 0 ? s.weight.clean : "\(s.reps)").font(Theme.mono(15, .bold))
                                    Text(s.weight > 0 ? "× \(s.reps)" : "reps").font(.caption2).foregroundStyle(Theme.ink3)
                                }
                                .frame(maxWidth: .infinity).padding(.vertical, 8)
                                .background(Theme.surface2, in: RoundedRectangle(cornerRadius: 12))
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func stat(_ l: String, _ v: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(l).font(.caption.weight(.semibold)).foregroundStyle(Theme.ink3)
            Text(v).font(Theme.mono(17, .bold)).lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Theme.surface2, in: RoundedRectangle(cornerRadius: 14))
    }
}

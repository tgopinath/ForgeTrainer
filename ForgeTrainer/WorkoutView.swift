import SwiftUI

@Observable
final class RestTimer {
    var end: Date?
    var total: TimeInterval = 0
    var finished = 0 // bumps when a rest ends, drives haptics

    private var task: Task<Void, Never>?

    func start(_ seconds: Int) {
        total = TimeInterval(seconds)
        end = .now.addingTimeInterval(total)
        Reminders.cancelRestEnd()
        Reminders.scheduleRestEnd(after: total)
        arm()
    }
    func add(_ seconds: Int) {
        guard let e = end else { return }
        end = e.addingTimeInterval(TimeInterval(seconds))
        total += TimeInterval(seconds)
        Reminders.cancelRestEnd()
        Reminders.scheduleRestEnd(after: end!.timeIntervalSinceNow)
        arm()
    }
    func skip() {
        task?.cancel(); end = nil
        Reminders.cancelRestEnd()
    }
    private func arm() {
        task?.cancel()
        guard let end else { return }
        task = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(max(0, end.timeIntervalSinceNow)))
            guard !Task.isCancelled, let self else { return }
            self.finished += 1
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            self.end = nil
        }
    }
}

struct WorkoutView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Binding var toast: String?
    @State private var rest = RestTimer()
    @State private var confirmDiscard = false
    @State private var setTicks = 0
    @FocusState private var focused: Bool

    var body: some View {
        if let active = store.data.active, active.dayIndex < store.plan.days.count {
            let day = store.plan.days[active.dayIndex]
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(day.items) { it in exerciseBlock(it) }
                        Button("Discard workout", role: .destructive) { confirmDiscard = true }
                            .frame(maxWidth: .infinity).padding(.top, 8)
                    }
                    .padding(16)
                    .padding(.bottom, 80)
                }
                .scrollDismissesKeyboard(.interactively)
                .background(Theme.bg)
                .safeAreaInset(edge: .top, spacing: 0) { header(day, active) }
                .safeAreaInset(edge: .bottom, spacing: 0) { restBar }
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { focused = false } }
                }
                .confirmationDialog("Discard this workout?", isPresented: $confirmDiscard, titleVisibility: .visible) {
                    Button("Discard workout", role: .destructive) {
                        rest.skip(); store.discardWorkout(); toast = "Workout discarded"
                    }
                } message: { Text("Sets you've logged in this session won't be saved.") }
            }
            .sensoryFeedback(.success, trigger: setTicks)
            .sensoryFeedback(.warning, trigger: rest.finished)
        }
    }

    private func header(_ day: PlanDay, _ a: ActiveWorkout) -> some View {
        let all = a.sets.values.flatMap { $0 }
        let done = all.filter(\.done).count
        return VStack(spacing: 10) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Eyebrow(text: "\(done) of \(all.count) sets")
                    Text(day.name).font(Theme.display(26))
                }
                Spacer()
                TimelineView(.periodic(from: .now, by: 1)) { ctx in
                    Label(Duration.seconds(ctx.date.timeIntervalSince(a.started)).formatted(.time(pattern: .minuteSecond)), systemImage: "timer")
                        .font(Theme.mono(17, .bold))
                        .foregroundStyle(Theme.ink2)
                }
                Button("Finish") { finish() }
                    .buttonStyle(.borderedProminent).buttonBorderShape(.capsule).tint(Theme.good)
            }
            ProgressView(value: Double(done), total: Double(max(1, all.count))).tint(day.mainGroup.color)
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(.bar)
    }

    private func exerciseBlock(_ it: PlanItem) -> some View {
        let rows = store.data.active?.sets[it.id] ?? []
        let c = it.pattern.group.color
        let complete = !rows.isEmpty && rows.allSatisfy(\.done)
        return Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 14) {
                    FigureTile(pattern: it.pattern, exercise: it.exercise, size: 64, animated: !complete)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(it.exercise).font(.headline)
                        Text("\(it.sets) × \(it.reps) · rest \(it.rest)s").font(Theme.mono(14, .medium)).foregroundStyle(Theme.ink2)
                    }
                    Spacer(minLength: 0)
                    if complete {
                        Image(systemName: "checkmark.circle.fill").font(.title).foregroundStyle(Theme.good)
                    }
                }
                Grid(horizontalSpacing: 10, verticalSpacing: 8) {
                    GridRow {
                        Text("SET")
                        Text(it.pattern.isUnloaded ? "LOAD" : store.unit.uppercased())
                        Text("REPS")
                        Text("")
                    }
                    .font(.caption2.weight(.bold)).tracking(0.5).foregroundStyle(Theme.ink3)
                    ForEach(Array(rows.enumerated()), id: \.element.id) { j, r in
                        GridRow {
                            Text("\(j + 1)")
                                .font(Theme.mono(14, .bold))
                                .frame(width: 30, height: 30)
                                .foregroundStyle(r.done ? .white : c)
                                .background(r.done ? c : c.opacity(0.13), in: Circle())
                            field(binding(it.id, j, \.weight), placeholder: it.pattern.isUnloaded ? "—" : "0", keyboard: .decimalPad)
                                .disabled(it.pattern.isUnloaded)
                            field(binding(it.id, j, \.reps), placeholder: "\(it.reps.repsTop)", keyboard: .numberPad)
                            Button { toggle(it, j) } label: {
                                Image(systemName: r.done ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 34, weight: .medium))
                                    .foregroundStyle(r.done ? Theme.good : Theme.ink3.opacity(0.5))
                                    .frame(width: 46, height: 44)
                            }
                            .accessibilityLabel("Mark set \(j + 1) done")
                            .accessibilityAddTraits(r.done ? .isSelected : [])
                        }
                    }
                }
                Button {
                    let last = rows.last
                    store.data.active?.sets[it.id, default: []].append(ActiveSet(weight: last?.weight ?? "", reps: ""))
                } label: {
                    Label("Add set", systemImage: "plus").font(.subheadline.weight(.semibold))
                }
                .tint(c)
            }
        }
    }

    private func field(_ b: Binding<String>, placeholder: String, keyboard: UIKeyboardType) -> some View {
        TextField(placeholder, text: b)
            .keyboardType(keyboard)
            .focused($focused)
            .font(Theme.mono(18, .bold))
            .multilineTextAlignment(.center)
            .frame(minHeight: 44)
            .background(Theme.surface2, in: RoundedRectangle(cornerRadius: 12))
    }

    private func binding(_ id: UUID, _ j: Int, _ kp: WritableKeyPath<ActiveSet, String>) -> Binding<String> {
        Binding(
            get: {
                guard let rows = store.data.active?.sets[id], rows.indices.contains(j) else { return "" }
                return rows[j][keyPath: kp]
            },
            set: { v in
                guard let rows = store.data.active?.sets[id], rows.indices.contains(j) else { return }
                store.data.active?.sets[id]?[j][keyPath: kp] = v
            })
    }

    private func toggle(_ it: PlanItem, _ j: Int) {
        guard var rows = store.data.active?.sets[it.id], rows.indices.contains(j) else { return }
        rows[j].done.toggle()
        if rows[j].done {
            if rows[j].reps.isEmpty { rows[j].reps = String(it.reps.repsTop) }
            if rows.indices.contains(j + 1), rows[j + 1].weight.isEmpty { rows[j + 1].weight = rows[j].weight }
            rest.start(it.rest)
            setTicks += 1
        }
        store.data.active?.sets[it.id] = rows
        focused = false
    }

    private func finish() {
        focused = false
        if let s = store.finishWorkout() {
            rest.skip()
            toast = "Workout saved · \(s.setsDone) sets · \(s.volume.grouped) \(store.unit)"
        } else {
            toast = "Tick off at least one set, or discard the workout"
        }
    }

    @ViewBuilder private var restBar: some View {
        if let end = rest.end {
            TimelineView(.periodic(from: .now, by: 0.5)) { ctx in
                let left = end.timeIntervalSince(ctx.date)
                HStack(spacing: 12) {
                    ZStack {
                        Circle().stroke(.white.opacity(0.2), lineWidth: 4)
                        Circle().trim(from: 0, to: max(0, left / max(1, rest.total)))
                            .stroke(left <= 10 ? Theme.amber : .white, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                    }
                    .frame(width: 34, height: 34)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(left > 0 ? "REST" : "GO!").font(.caption2.weight(.heavy)).opacity(0.7)
                        Text(left > 0 ? Duration.seconds(left.rounded(.up)).formatted(.time(pattern: .minuteSecond)) : "Next set")
                            .font(Theme.mono(20)).monospacedDigit()
                            .foregroundStyle(left > 0 && left <= 10 ? Theme.amber : .white)
                    }
                    Spacer()
                    if left > 0 {
                        Button("+15s") { rest.add(15) }.buttonStyle(.bordered).buttonBorderShape(.capsule).tint(.white)
                    }
                    Button(left > 0 ? "Skip" : "Close") { rest.skip() }.buttonStyle(.bordered).buttonBorderShape(.capsule).tint(.white)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16).padding(.vertical, 12)
                .background(Color(white: 0.1), in: Capsule())
                .shadow(color: .black.opacity(0.25), radius: 14, y: 6)
                .padding(.horizontal, 12).padding(.bottom, 6)
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}

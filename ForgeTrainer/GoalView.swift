import SwiftUI

struct GoalView: View {
    @Environment(Store.self) private var store
    @Binding var tab: AppTab
    @Binding var toast: String?
    @Environment(\.dismiss) private var dismiss

    @State private var draft = Profile()
    @State private var currentText = ""
    @State private var targetText = ""
    @State private var reminderTime = Date.now
    @State private var loaded = false
    @FocusState private var focused: Bool

    var body: some View {
        let isNew = store.data.isExample
        Page {
            PageHeader(eyebrow: isNew ? "Get started" : "Your goal", title: isNew ? "Set your goal" : "Adjust your goal",
                       subtitle: "Forge builds your weekly plan from this — sets, reps, rest times and exercises for your equipment.")

            Card {
                VStack(alignment: .leading, spacing: 22) {
                    group("What's your main goal?") {
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                            ForEach(Goal.allCases) { g in
                                Button { draft.goal = g } label: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Image(systemName: g.symbol).font(.headline).foregroundStyle(.white)
                                            .frame(width: 36, height: 36).background(g.color, in: Circle())
                                        Text(g.label).font(.headline).foregroundStyle(.primary)
                                        Text(g.blurb).font(.caption).foregroundStyle(Theme.ink2)
                                    }
                                    .frame(maxWidth: .infinity, minHeight: 110, alignment: .topLeading)
                                    .padding(12)
                                    .background(draft.goal == g ? g.color.opacity(0.12) : Theme.surface2, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(draft.goal == g ? g.color : .clear, lineWidth: 2.5))
                                }
                                .buttonStyle(.plain)
                                .accessibilityAddTraits(draft.goal == g ? .isSelected : [])
                            }
                        }
                    }

                    group("Training days", hint: "\(draft.days.count) days a week — \(PlanBuilder.splitName(forDays: draft.days.count))") {
                        HStack(spacing: 5) {
                            ForEach(PlanBuilder.weekOrder, id: \.self) { wd in
                                let on = draft.days.contains(wd)
                                Button {
                                    if on { draft.days.remove(wd) } else { draft.days.insert(wd) }
                                } label: {
                                    Text(Day.shortName(wd)).font(.footnote.weight(.semibold))
                                        .frame(maxWidth: .infinity, minHeight: 38)
                                        .foregroundStyle(on ? .white : Theme.ink2)
                                        .background(on ? Theme.accent : Theme.surface2, in: Capsule())
                                }
                                .buttonStyle(.plain)
                                .accessibilityAddTraits(on ? .isSelected : [])
                            }
                        }
                    }

                    group("Experience") {
                        Picker("Experience", selection: $draft.level) { ForEach(Level.allCases) { Text($0.label).tag($0) } }.pickerStyle(.segmented)
                    }
                    group("Equipment") {
                        Picker("Equipment", selection: $draft.equipment) { ForEach(Equipment.allCases) { Text($0.label).tag($0) } }.pickerStyle(.segmented)
                    }

                    group("Body weight target") {
                        Picker("Units", selection: $draft.unit) { ForEach(WeightUnit.allCases) { Text($0.rawValue).tag($0) } }.pickerStyle(.segmented)
                        HStack(spacing: 10) {
                            numberField("Current (\(draft.unit.rawValue))", $currentText, id: "currentWeight")
                            numberField("Target (\(draft.unit.rawValue))", $targetText, id: "targetWeight")
                        }
                        DatePicker("Target date", selection: $draft.targetDate, in: Date.now.addingTimeInterval(86400)..., displayedComponents: .date)
                            .font(.subheadline.weight(.semibold))
                    }

                    group("About you") {
                        TextField("Your name (optional)", text: $draft.name)
                            .focused($focused)
                            .padding(.horizontal, 12).frame(height: 44)
                            .background(Theme.surface2, in: RoundedRectangle(cornerRadius: 14))
                        Stepper("Water goal: \(draft.waterGoal) glasses", value: $draft.waterGoal, in: 1...16)
                            .font(.subheadline.weight(.semibold))
                    }

                    group("Reminders") {
                        Toggle("Remind me on training days", isOn: $draft.remindersOn).font(.subheadline.weight(.semibold))
                        if draft.remindersOn {
                            DatePicker("Time", selection: $reminderTime, displayedComponents: .hourAndMinute)
                                .font(.subheadline.weight(.semibold))
                        }
                    }
                }
            }

            Button(isNew ? "Build my plan" : "Save goal") { save() }
                .buttonStyle(BigButtonStyle())
                .disabled(draft.days.isEmpty)
            if draft.days.isEmpty {
                Text("Pick at least one training day.").font(.footnote).foregroundStyle(Theme.warn)
            } else if !isNew {
                Text("Changing goal, days, level or equipment rebuilds your weekly plan.").font(.footnote).foregroundStyle(Theme.ink3)
            }
        }
        .toolbar { ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { focused = false } } }
        .onAppear(perform: load)
        .onChange(of: store.data.isExample) { loaded = false; load() }
        .onChange(of: draft.remindersOn) { _, on in if on { Task { _ = await Reminders.requestPermission() } } }
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        draft = store.data.isExample ? Profile() : store.profile
        currentText = store.data.isExample ? "" : store.currentWeight.clean
        targetText = store.data.isExample ? "" : draft.targetWeight.clean
        reminderTime = Calendar.current.date(bySettingHour: draft.reminderHour, minute: draft.reminderMinute, second: 0, of: .now) ?? .now
    }

    private func save() {
        focused = false
        guard let cur = Double(currentText.replacingOccurrences(of: ",", with: ".")), cur > 20,
              let tgt = Double(targetText.replacingOccurrences(of: ",", with: ".")), tgt > 20 else {
            toast = "Enter your current and target weight"; return
        }
        var p = draft
        p.targetWeight = tgt
        let c = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
        p.reminderHour = c.hour ?? 18
        p.reminderMinute = c.minute ?? 0
        if store.data.isExample {
            p.startWeight = cur
            store.startFresh(with: p)
            toast = "Your plan is ready"
        } else {
            toast = store.updateGoal(p, currentWeight: cur) ? "Goal saved · plan rebuilt" : "Goal saved"
        }
        loaded = false
        tab = .today
        dismiss()
    }

    private func group<C: View>(_ title: String, hint: String? = nil, @ViewBuilder _ c: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.subheadline.weight(.bold))
            if let hint { Text(hint).font(.caption).foregroundStyle(Theme.ink3) }
            c()
        }
    }

    private func numberField(_ label: String, _ text: Binding<String>, id: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption.weight(.semibold)).foregroundStyle(Theme.ink2)
            TextField("0", text: text)
                .keyboardType(.decimalPad).focused($focused)
                .accessibilityIdentifier(id)
                .font(Theme.mono(16, .medium))
                .padding(.horizontal, 12).frame(height: 44)
                .background(Theme.surface2, in: RoundedRectangle(cornerRadius: 14))
        }
    }
}

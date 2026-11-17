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
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.colorSchemeContrast) private var contrast
    @ScaledMetric(relativeTo: .body) private var iconSize: CGFloat = 32

    var body: some View {
        let isNew = store.data.isExample
        NavigationStack {
            Form {
                Section {
                    Text("Forge builds your weekly plan from this: sets, reps, rest times and exercises for your equipment.")
                        .font(.subheadline).foregroundStyle(Theme.ink2)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 4))
                }

                Section("What's your main goal?") {
                    Picker("Main goal", selection: $draft.goal) {
                        ForEach(Goal.allCases) { g in
                            Label {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(g.label).font(.body.weight(.semibold))
                                    Text(g.blurb).font(.footnote).foregroundStyle(Theme.ink2)
                                }
                            } icon: {
                                Image(systemName: g.symbol).font(.subheadline.weight(.bold)).foregroundStyle(.white)
                                    .frame(width: iconSize, height: iconSize).background(g.color, in: Circle())
                            }
                            .tag(g)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                Section {
                    dayToggles
                } header: {
                    Text("Training days")
                } footer: {
                    if draft.days.isEmpty {
                        Text("Pick at least one training day.").foregroundStyle(Theme.warn)
                    } else {
                        Text("\(draft.days.count) days a week: \(PlanBuilder.splitName(forDays: draft.days.count))")
                    }
                }

                Section("Training") {
                    Picker("Experience", selection: $draft.level) { ForEach(Level.allCases) { Text($0.label).tag($0) } }
                    Picker("Equipment", selection: $draft.equipment) { ForEach(Equipment.allCases) { Text($0.label).tag($0) } }
                }

                Section("Body weight target") {
                    Picker("Units", selection: $draft.unit) { ForEach(WeightUnit.allCases) { Text($0.rawValue).tag($0) } }
                        .pickerStyle(.segmented)
                    numberField("Current weight", $currentText, id: "currentWeight")
                    numberField("Target weight", $targetText, id: "targetWeight")
                    DatePicker("Target date", selection: $draft.targetDate, in: Date.now.addingTimeInterval(86400)..., displayedComponents: .date)
                }

                Section("About you") {
                    TextField("Your name (optional)", text: $draft.name)
                        .textContentType(.givenName)
                        .focused($focused)
                    Stepper("Water goal: \(draft.waterGoal) glasses", value: $draft.waterGoal, in: 1...16)
                }

                Section {
                    Toggle("Remind me on training days", isOn: $draft.remindersOn)
                    if draft.remindersOn {
                        DatePicker("Time", selection: $reminderTime, displayedComponents: .hourAndMinute)
                    }
                } header: {
                    Text("Reminders")
                } footer: {
                    if !isNew { Text("Changing goal, days, level or equipment rebuilds your weekly plan.") }
                }

                Section {
                    Button(isNew ? "Build my plan" : "Save goal") { save() }
                        .buttonStyle(BigButtonStyle())
                        .disabled(draft.days.isEmpty)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(isNew ? "Set your goal" : "Adjust your goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { loaded = false; dismiss() } }
                ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { focused = false } }
            }
        }
        .onAppear(perform: load)
        .onChange(of: store.data.isExample) { loaded = false; load() }
        .onChange(of: draft.remindersOn) { _, on in if on { Task { _ = await Reminders.requestPermission() } } }
    }

    /// Seven day toggles in one row (two rows at accessibility sizes), each at least 44pt tall.
    private var dayToggles: some View {
        let columns = typeSize.isAccessibilitySize ? 4 : 7
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: columns), spacing: 6) {
            ForEach(PlanBuilder.weekOrder, id: \.self) { wd in
                let on = draft.days.contains(wd)
                Toggle(isOn: Binding(get: { on }, set: { if $0 { draft.days.insert(wd) } else { draft.days.remove(wd) } })) {
                    Text(Day.shortName(wd)).font(.footnote.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .toggleStyle(.button)
                .buttonStyle(.plain)
                .foregroundStyle(on ? .white : Theme.ink2)
                .background(on ? Theme.accent : Theme.surface2, in: Capsule())
                .overlay(Capsule().strokeBorder(contrast == .increased && !on ? Theme.ink3 : .clear))
            }
        }
        .padding(.vertical, 4)
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

    private func numberField(_ label: String, _ text: Binding<String>, id: String) -> some View {
        LabeledContent(label) {
            HStack(spacing: 4) {
                TextField("0", text: text)
                    .keyboardType(.decimalPad).focused($focused)
                    .accessibilityIdentifier(id)
                    .accessibilityLabel("\(label) in \(draft.unit.rawValue)")
                    .font(Theme.mono(17, .semibold))
                    .multilineTextAlignment(.trailing)
                Text(draft.unit.rawValue).foregroundStyle(Theme.ink2)
            }
        }
    }
}

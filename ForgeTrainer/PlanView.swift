import SwiftUI

struct PlanView: View {
    @Environment(Store.self) private var store
    @Binding var tab: AppTab
    @State private var confirmRebuild = false
    @State private var editing: PlanItem?

    var body: some View {
        let p = store.profile
        let today = Calendar.current.component(.weekday, from: .now)
        Page {
            if store.data.isExample { ExampleBanner { tab = .goal } }
            VStack(alignment: .leading, spacing: 2) {
                Text("\(p.goal.label) · \(p.equipment.label)").font(.subheadline.weight(.medium)).foregroundStyle(Theme.ink3)
                Text("Your week").font(.title.weight(.bold))
            }
            .padding(.top, 4)

            // week strip
            HStack(spacing: 6) {
                ForEach(PlanBuilder.weekOrder, id: \.self) { wd in
                    let day = store.plan.schedule[wd].map { store.plan.days[$0] }
                    let c = day?.mainGroup.color ?? Theme.ink3
                    VStack(spacing: 6) {
                        Text(Day.shortName(wd).prefix(3)).font(.caption2.weight(.bold)).foregroundStyle(wd == today ? .primary : Theme.ink3)
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(day == nil ? Theme.surface2 : c)
                            .frame(height: 54)
                            .overlay {
                                if let day {
                                    Text(initials(day.name)).font(Theme.display(15)).foregroundStyle(.white)
                                } else {
                                    Image(systemName: "moon.zzz.fill").font(.caption).foregroundStyle(Theme.ink3)
                                }
                            }
                            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(wd == today ? Color.primary : .clear, lineWidth: 2).padding(-3))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.vertical, 4)

            balanceCard

            ForEach(Array(store.plan.days.enumerated()), id: \.element.id) { di, day in
                dayCard(di, day)
            }

            Button { confirmRebuild = true } label: { Label("Rebuild plan from my goal", systemImage: "arrow.clockwise") }
                .buttonStyle(.bordered).buttonBorderShape(.capsule)
                .frame(maxWidth: .infinity)
                .disabled(store.data.isExample)
                .confirmationDialog("Rebuild your plan?", isPresented: $confirmRebuild, titleVisibility: .visible) {
                    Button("Rebuild plan", role: .destructive) { store.rebuildPlan() }
                } message: { Text("This replaces any exercise swaps and set changes you've made.") }
        }
        .sheet(item: $editing) { it in EditItemSheet(itemID: it.id).environment(store) }
    }

    private func initials(_ name: String) -> String {
        let parts = name.split(separator: " ")
        if parts.count == 1 { return String(name.prefix(4)).uppercased() }
        if name.hasPrefix("Full Body") { return "FB" + (parts.last.map(String.init) ?? "") }
        return parts.map { String($0.prefix(1)) }.joined().uppercased()
    }

    private var balanceCard: some View {
        let groups = store.plannedSetsByGroup
        let total = max(1, groups.reduce(0) { $0 + $1.sets })
        return Card {
            VStack(alignment: .leading, spacing: 12) {
                SectionTitle(text: "Balance", trailing: "\(total) sets a week")
                GeometryReader { geo in
                    HStack(spacing: 3) {
                        ForEach(groups, id: \.group) { g in
                            RoundedRectangle(cornerRadius: 4).fill(g.group.color)
                                .frame(width: max(4, (geo.size.width - CGFloat(groups.count - 1) * 3) * CGFloat(g.sets) / CGFloat(total)))
                        }
                    }
                }
                .frame(height: 14)
                FlowChips(groups: groups)
            }
        }
    }

    private func dayCard(_ di: Int, _ day: PlanDay) -> some View {
        let wds = store.plan.schedule.filter { $0.value == di }.keys
            .sorted { PlanBuilder.weekOrder.firstIndex(of: $0)! < PlanBuilder.weekOrder.firstIndex(of: $1)! }
            .map(Day.shortName).joined(separator: " · ")
        let c = day.mainGroup.color
        return VStack(spacing: 0) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(day.name).font(Theme.display(24)).foregroundStyle(.white)
                    Text("\(wds.isEmpty ? "Unscheduled" : wds)  ·  ~\(day.estimatedMinutes) min  ·  \(day.workingSets) sets")
                        .font(.footnote.weight(.semibold)).foregroundStyle(.white.opacity(0.85))
                }
                Spacer()
                ExerciseFigure(pattern: day.items.first?.pattern ?? .squat, exercise: day.items.first?.exercise ?? "",
                               color: .white, propColor: .white.opacity(0.7), animated: false)
                    .frame(width: 52, height: 52)
            }
            .padding(16)
            .background(LinearGradient(colors: [c, c.mix(with: .black, by: 0.25)], startPoint: .leading, endPoint: .trailing))

            VStack(spacing: 0) {
                ForEach(Array(day.items.enumerated()), id: \.element.id) { i, it in
                    if i > 0 { Divider().padding(.leading, 76) }
                    Button { if store.data.isExample { tab = .goal } else { editing = it } } label: { ExerciseRow(item: it) }
                        .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Theme.surface)
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 10, y: 3)
    }
}

struct FlowChips: View {
    let groups: [(group: MuscleGroup, sets: Int)]
    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 8)], alignment: .leading, spacing: 8) {
            ForEach(groups, id: \.group) { g in
                HStack(spacing: 6) {
                    Circle().fill(g.group.color).frame(width: 8, height: 8)
                    Text(g.group.label).font(.caption.weight(.semibold))
                    Text("\(g.sets)").font(Theme.mono(12, .bold)).foregroundStyle(Theme.ink3)
                }
            }
        }
    }
}

struct EditItemSheet: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    let itemID: UUID

    var body: some View {
        NavigationStack {
            if let loc = store.item(itemID) {
                let it = store.data.plan.days[loc.day].items[loc.index]
                let opts = ExerciseLibrary.options(it.pattern, for: store.profile.equipment)
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        ExerciseFigure(pattern: it.pattern, exercise: it.exercise, color: it.pattern.group.color,
                                       propColor: it.pattern.group.color.opacity(0.7))
                            .frame(height: 170).frame(maxWidth: .infinity).padding(.vertical, 14)
                            .background(it.pattern.group.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 24, style: .continuous))

                        Text("Choose exercise").font(.headline)
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                            ForEach(opts) { o in
                                let on = o.name == it.exercise
                                Button {
                                    store.data.plan.days[loc.day].items[loc.index].exercise = o.name
                                } label: {
                                    VStack(alignment: .leading, spacing: 8) {
                                        FigureTile(pattern: it.pattern, exercise: o.name, size: 54)
                                        Text(o.name).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                                            .multilineTextAlignment(.leading).lineLimit(2)
                                        Text(o.equipment.label).font(.caption).foregroundStyle(Theme.ink3)
                                    }
                                    .frame(maxWidth: .infinity, minHeight: 130, alignment: .topLeading)
                                    .padding(12)
                                    .background(Theme.surface2, in: RoundedRectangle(cornerRadius: 18))
                                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(on ? it.pattern.group.color : .clear, lineWidth: 2.5))
                                }
                                .buttonStyle(.plain)
                                .accessibilityAddTraits(on ? .isSelected : [])
                            }
                        }

                        Text("Volume").font(.headline)
                        VStack(spacing: 0) {
                            Stepper(value: Binding(get: { it.sets }, set: { store.data.plan.days[loc.day].items[loc.index].sets = $0 }), in: 1...10) {
                                HStack { Text("Sets"); Spacer(); Text("\(it.sets)").font(Theme.mono(17, .bold)) }
                            }
                            .padding(14)
                            Divider()
                            HStack {
                                Text("Reps")
                                Spacer()
                                TextField("Reps", text: Binding(get: { it.reps }, set: { store.data.plan.days[loc.day].items[loc.index].reps = String($0.prefix(8)) }))
                                    .font(Theme.mono(17, .bold)).multilineTextAlignment(.trailing).frame(width: 90)
                            }
                            .padding(14)
                        }
                        .background(Theme.surface2, in: RoundedRectangle(cornerRadius: 18))
                        Text("Use a range like 8-12, a single number, or seconds like 40s.").font(.footnote).foregroundStyle(Theme.ink3)
                    }
                    .padding(20)
                }
                .navigationTitle(it.pattern.label)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            }
        }
        .presentationDetents([.large])
    }
}

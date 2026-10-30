import SwiftUI
import Charts

struct ProgressTab: View {
    @Environment(Store.self) private var store
    @Binding var tab: AppTab
    @Binding var toast: String?
    @State private var weightText = ""
    @FocusState private var weightFocused: Bool

    var body: some View {
        let u = store.unit
        let recent = Array(store.data.sessions.suffix(4).reversed())
        let n = store.data.sessions.count
        let avg = n == 0 ? 0 : store.data.sessions.suffix(10).reduce(0) { $0 + $1.minutes } / min(10, n)
        Page {
            if store.data.isExample { ExampleBanner { tab = .goal } }
            Text("Progress").font(.title.weight(.bold)).padding(.top, 4)

            Card {
                HStack(spacing: 0) {
                    summary("\(n)", "sessions")
                    Divider().frame(height: 36)
                    summary(store.volumeLast7Days.grouped, "\(u) this week")
                    Divider().frame(height: 36)
                    summary("\(avg)", "min avg")
                }
            }

            Card {
                VStack(alignment: .leading, spacing: 12) {
                    SectionTitle(text: "Sets by muscle", trailing: "8 weeks")
                    setsChart.frame(height: 170)
                    FlowChips(groups: MuscleGroup.allCases.map { ($0, totalSets($0)) }.filter { $0.1 > 0 })
                }
            }

            Card {
                VStack(alignment: .leading, spacing: 12) {
                    SectionTitle(text: "Weight", trailing: "\(store.currentWeight.clean) → \(store.profile.targetWeight.clean) \(u)")
                    weightChart.frame(height: 190)
                    HStack(spacing: 10) {
                        TextField("Today's weight", text: $weightText)
                            .keyboardType(.decimalPad).focused($weightFocused)
                            .font(Theme.mono(17, .semibold))
                            .padding(.horizontal, 14).frame(height: 46)
                            .background(Theme.surface2, in: Capsule())
                            .accessibilityLabel("Today's weight in \(u)").accessibilityIdentifier("weightInput")
                        Button("Log \(u)") { logWeight() }
                            .font(.headline)
                            .buttonStyle(.borderedProminent).buttonBorderShape(.capsule).controlSize(.large)
                    }
                }
            }

            Card {
                VStack(alignment: .leading, spacing: 12) {
                    SectionTitle(text: "Consistency", trailing: "16 weeks")
                    Heatmap(sessions: store.data.sessions)
                }
            }

            Card {
                VStack(alignment: .leading, spacing: 10) {
                    SectionTitle(text: "Best lifts")
                    let bests = Array(store.bestLifts.prefix(4))
                    if bests.isEmpty {
                        Text("Log a weighted set to see your bests.").font(.subheadline).foregroundStyle(Theme.ink3)
                    }
                    ForEach(Array(bests.enumerated()), id: \.element.exercise) { i, b in
                        if i > 0 { Divider().padding(.leading, 62) }
                        HStack(spacing: 12) {
                            FigureTile(pattern: ExerciseLibrary.pattern(for: b.exercise), exercise: b.exercise, size: 48)
                            Text(b.exercise).font(.subheadline.weight(.semibold))
                            Spacer()
                            Text(b.set.weight.clean).font(Theme.display(20)) +
                            Text(" \(u) × \(b.set.reps)").font(.caption.weight(.semibold)).foregroundStyle(Theme.ink3)
                        }
                    }
                }
            }

            Card {
                VStack(alignment: .leading, spacing: 10) {
                    SectionTitle(text: "Recent sessions")
                    if recent.isEmpty {
                        Text("No sessions yet. Your first one will show up here.").font(.subheadline).foregroundStyle(Theme.ink3)
                    }
                    ForEach(Array(recent.enumerated()), id: \.element.id) { i, s in
                        if i > 0 { Divider() }
                        sessionRow(s)
                    }
                }
            }
        }
        .toolbar { ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { weightFocused = false } } }
    }

    private func totalSets(_ g: MuscleGroup) -> Int {
        store.weeklySetsByGroup().filter { $0.group == g }.reduce(0) { $0 + $1.sets }
    }

    private func summary(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(Theme.display(24)).lineLimit(1).minimumScaleFactor(0.6)
            Text(label).font(.caption.weight(.semibold)).foregroundStyle(Theme.ink3)
        }
        .frame(maxWidth: .infinity)
    }

    private func stat(_ icon: String, _ color: Color, _ label: String, _ value: String, _ unit: String) -> some View {
        Card(padding: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: icon).font(.subheadline.weight(.bold)).foregroundStyle(color)
                    .frame(width: 32, height: 32).background(color.opacity(0.13), in: Circle())
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text(value).font(Theme.display(26)).lineLimit(1).minimumScaleFactor(0.6)
                        Text(unit).font(.caption.weight(.semibold)).foregroundStyle(Theme.ink3)
                    }
                    Text(label).font(.caption.weight(.semibold)).foregroundStyle(Theme.ink3)
                }
            }
        }
    }

    private func sessionRow(_ s: Session) -> some View {
        var c: [MuscleGroup: Int] = [:]
        for e in s.exercises { c[e.pattern.group, default: 0] += e.sets.count }
        let total = max(1, c.values.reduce(0, +))
        let parts = MuscleGroup.allCases.compactMap { g in c[g].map { (g, $0) } }
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text(s.dayName).font(.subheadline.weight(.bold))
                    Text(s.date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)) + " · \(s.minutes) min · \(s.setsDone) sets")
                        .font(.caption).foregroundStyle(Theme.ink3)
                }
                Spacer()
                Text("\(s.volume.grouped) \(store.unit)").font(Theme.mono(14, .bold))
            }
            GeometryReader { geo in
                HStack(spacing: 2) {
                    ForEach(parts, id: \.0) { g, n in
                        Capsule().fill(g.color).frame(width: max(3, (geo.size.width - CGFloat(parts.count - 1) * 2) * CGFloat(n) / CGFloat(total)))
                    }
                }
            }
            .frame(height: 6)
        }
        .padding(.vertical, 4)
    }

    private var setsChart: some View {
        let data = store.weeklySetsByGroup()
        return Chart(data, id: \.week) { d in
            BarMark(x: .value("Week", d.week, unit: .weekOfYear), y: .value("Sets", d.sets))
                .foregroundStyle(by: .value("Group", d.group.label))
                .cornerRadius(3)
        }
        .chartForegroundStyleScale(domain: MuscleGroup.allCases.map(\.label), range: MuscleGroup.allCases.map(\.color))
        .chartLegend(.hidden)
        .chartXAxis { AxisMarks(values: .stride(by: .weekOfYear, count: 2)) { _ in AxisValueLabel(format: .dateTime.day().month(.abbreviated)) } }
        .chartYAxis { AxisMarks(position: .leading) { _ in AxisGridLine(); AxisValueLabel() } }
        .accessibilityLabel("Weekly sets by muscle group for the last 8 weeks")
    }

    @ViewBuilder private var weightChart: some View {
        let pts = Array(store.data.weights.suffix(40))
        let target = store.profile.targetWeight
        if pts.count < 2 {
            VStack(spacing: 8) {
                Image(systemName: "chart.line.uptrend.xyaxis").font(.largeTitle).foregroundStyle(Theme.ink3)
                Text("Log your weight a couple of times to see the trend.").font(.subheadline).foregroundStyle(Theme.ink3)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            let vals = pts.map(\.weight) + [target]
            let lo = (vals.min()! - 1).rounded(.down), hi = (vals.max()! + 1).rounded(.up)
            Chart {
                ForEach(pts) { p in
                    AreaMark(x: .value("Date", p.date), yStart: .value("Base", lo), yEnd: .value("Weight", p.weight))
                        .foregroundStyle(LinearGradient(colors: [Theme.accent.opacity(0.28), Theme.accent.opacity(0.02)], startPoint: .top, endPoint: .bottom))
                        .interpolationMethod(.monotone)
                    LineMark(x: .value("Date", p.date), y: .value("Weight", p.weight))
                        .foregroundStyle(Theme.accent)
                        .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                        .interpolationMethod(.monotone)
                }
                if let last = pts.last {
                    PointMark(x: .value("Date", last.date), y: .value("Weight", last.weight))
                        .foregroundStyle(Theme.accent).symbolSize(90)
                        .annotation(position: .top, alignment: .trailing) {
                            Text(last.weight.clean).font(Theme.mono(13, .bold))
                        }
                }
                RuleMark(y: .value("Target", target))
                    .foregroundStyle(Theme.good)
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [6, 5]))
            }
            .chartYScale(domain: lo...hi)
            .chartXAxis { AxisMarks(values: .automatic(desiredCount: 4)) { _ in AxisValueLabel(format: .dateTime.day().month(.abbreviated)) } }
            .chartYAxis { AxisMarks(position: .leading) { _ in AxisGridLine(); AxisValueLabel() } }
            .accessibilityLabel("Body weight trend, latest \(pts.last!.weight.clean) \(store.unit), target \(target.clean)")
        }
    }

    private func logWeight() {
        weightFocused = false
        guard let v = Double(weightText.replacingOccurrences(of: ",", with: ".")), v > 20, v < 400 else {
            toast = "Enter your weight as a number, like 76.4"; return
        }
        guard !store.data.isExample else { tab = .goal; toast = "Set your goal first — then the log is yours"; return }
        store.logWeight(v)
        weightText = ""
        toast = "Logged \(v.clean) \(store.unit)"
    }
}

struct Heatmap: View {
    let sessions: [Session]
    private let weeks = 16

    static func color(_ level: Int) -> Color {
        switch level {
        case 0: Theme.surface2
        case 1: Theme.good.opacity(0.35)
        case 2: Theme.good.opacity(0.65)
        default: Theme.good
        }
    }

    var body: some View {
        let cal = Calendar.current
        let start = cal.date(byAdding: .day, value: -7 * (weeks - 1), to: Day.monday(of: .now))!
        var byDay: [String: Double] = [:]
        for s in sessions { byDay[Day.key(s.date), default: 0] += Double(s.setsDone) }
        let maxV = max(1, byDay.values.max() ?? 1)
        let today = cal.startOfDay(for: .now)
        return HStack(alignment: .top, spacing: 4) {
            ForEach(0..<weeks, id: \.self) { w in
                VStack(spacing: 4) {
                    ForEach(0..<7, id: \.self) { d in
                        let date = cal.date(byAdding: .day, value: w * 7 + d, to: start)!
                        let v = byDay[Day.key(date)] ?? 0
                        let level = v == 0 ? 0 : v < maxV * 0.5 ? 1 : v < maxV * 0.85 ? 2 : 3
                        RoundedRectangle(cornerRadius: 3.5)
                            .fill(date > today ? Color.clear : Heatmap.color(level))
                            .aspectRatio(1, contentMode: .fit)
                    }
                }
            }
        }
        .accessibilityElement()
        .accessibilityLabel("\(Set(sessions.map { Day.key($0.date) }).count) training days logged")
    }
}

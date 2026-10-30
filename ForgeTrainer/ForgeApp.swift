import SwiftUI
import UserNotifications

@main
struct ForgeApp: App {
    @State private var store = Store()
    @Environment(\.scenePhase) private var phase
    private static let notifications = NotificationDelegate()

    init() {
        UNUserNotificationCenter.current().delegate = Self.notifications
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .tint(Theme.accent)
        }
        .onChange(of: phase) { _, p in if p != .active { store.saveNow() } }
    }
}

enum AppTab: Hashable { case today, plan, progress, coach, goal }

struct RootView: View {
    @Environment(Store.self) private var store
    @State private var tab: AppTab = .today
    @State private var toast: String?
    @State private var showGoal = false

    var body: some View {
        if CommandLine.arguments.contains("-figureGallery") { FigureGallery() } else { tabs }
    }

    private var tabs: some View {
        TabView(selection: $tab) {
            Tab("Today", systemImage: "dumbbell.fill", value: .today) { TodayView(tab: $tab, toast: $toast) }
            Tab("Plan", systemImage: "calendar", value: .plan) { PlanView(tab: $tab) }
            Tab("Progress", systemImage: "chart.line.uptrend.xyaxis", value: .progress) { ProgressTab(tab: $tab, toast: $toast) }
            Tab("Coach", systemImage: "sparkles", value: .coach) { CoachView() }
        }
        // Goal isn't a tab: anything that asks for it opens the goal sheet instead.
        .onChange(of: tab) { old, new in
            if new == .goal { showGoal = true; tab = old == .goal ? .today : old }
        }
        .sheet(isPresented: $showGoal) {
            GoalView(tab: $tab, toast: $toast).environment(store)
                .presentationDragIndicator(.visible)
        }
        .fullScreenCover(isPresented: Binding(get: { store.data.active != nil }, set: { if !$0 { store.data.active = nil } })) {
            WorkoutView(toast: $toast).environment(store)
        }
        .overlay(alignment: .top) {
            if let toast {
                Text(toast)
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(.ultraThickMaterial, in: Capsule())
                    .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .task(id: toast) {
                        try? await Task.sleep(for: .seconds(2.4))
                        withAnimation { self.toast = nil }
                    }
            }
        }
        .animation(.spring(duration: 0.3), value: toast)
    }
}

/// Shared page scaffold: background, scroll, side gutter.
struct Page<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) { content }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 32)
        }
        .scrollDismissesKeyboard(.interactively)
        .scrollIndicators(.hidden)
        .background(Theme.bg)
    }
}

struct PageHeader: View {
    let eyebrow: String
    let title: String
    var subtitle: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Eyebrow(text: eyebrow)
            Text(title).font(.largeTitle.weight(.bold)).lineLimit(2).minimumScaleFactor(0.7)
            if let subtitle { Text(subtitle).font(.subheadline).foregroundStyle(Theme.ink2) }
        }
        .padding(.top, 4)
    }
}

/// Debug screen (launch with -figureGallery) showing every exercise animation.
struct FigureGallery: View {
    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 66), spacing: 6)], spacing: 4) {
                ForEach(Pattern.allCases, id: \.self) { p in
                    ForEach(ExerciseLibrary.all[p] ?? []) { e in
                        VStack(spacing: 4) {
                            FigureTile(pattern: p, exercise: e.name, size: 66, animated: false)
                            Text(e.name).font(.system(size: 8, weight: .semibold)).lineLimit(1).multilineTextAlignment(.center)
                        }
                    }
                }
            }
            .padding(12)
        }
    }
}

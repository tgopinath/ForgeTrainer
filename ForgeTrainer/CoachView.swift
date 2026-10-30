import SwiftUI

struct CoachView: View {
    @Environment(Store.self) private var store
    @State private var input = ""
    @State private var streaming: String?
    @State private var task: Task<Void, Never>?
    @FocusState private var focused: Bool

    private let suggestions = ["Review my last week", "I'm sore today — adjust my workout", "What should I eat for my goal?", "How do I progress faster?"]

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Coach").font(.title.weight(.bold)).padding(.top, 4)
                        if !Coach.isOnDeviceAvailable {
                            Label(Coach.unavailableReason, systemImage: "info.circle")
                                .font(.footnote).foregroundStyle(Theme.ink2)
                                .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                                .background(Theme.surface2, in: RoundedRectangle(cornerRadius: 12))
                        }
                        if store.data.chat.isEmpty {
                            bubble(.init(role: .coach, text: "Hi\(store.profile.name.isEmpty ? "" : " \(store.profile.name)")! Your goal is to \(store.profile.goal.label.lowercased()), training \(store.profile.days.count)× a week. Ask me about training, form, recovery or food."))
                        }
                        ForEach(store.data.chat) { bubble($0) }
                        if let streaming {
                            bubble(.init(role: .coach, text: streaming.isEmpty ? "Thinking…" : streaming)).id("stream")
                        }
                        Color.clear.frame(height: 1).id("bottom")
                    }
                    .padding(16)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: streaming) { proxy.scrollTo("bottom", anchor: .bottom) }
                .onChange(of: store.data.chat.count) { withAnimation { proxy.scrollTo("bottom", anchor: .bottom) } }
            }
            composer
        }
        .background(Theme.bg)
    }

    private func bubble(_ m: ChatMessage) -> some View {
        HStack(alignment: .bottom, spacing: 8) {
            if m.role == .user { Spacer(minLength: 40) } else {
                Image(systemName: "figure.strengthtraining.traditional").font(.caption.weight(.bold)).foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(LinearGradient(colors: [Theme.accent, Theme.core], startPoint: .topLeading, endPoint: .bottomTrailing), in: Circle())
            }
            Text(LocalizedStringKey(m.text))
                .font(.subheadline)
                .padding(.horizontal, 14).padding(.vertical, 10)
                .foregroundStyle(m.role == .user ? .white : .primary)
                .background(m.role == .user ? Theme.accent : Theme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .textSelection(.enabled)
            if m.role == .coach { Spacer(minLength: 40) }
        }
    }

    private var composer: some View {
        VStack(spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(suggestions, id: \.self) { s in
                        Button(s) { send(s) }
                            .font(.footnote.weight(.semibold))
                            .buttonStyle(.bordered).buttonBorderShape(.capsule)
                            .disabled(streaming != nil)
                    }
                    if !store.data.chat.isEmpty && streaming == nil {
                        Button("Clear", role: .destructive) { store.data.chat.removeAll() }
                            .font(.footnote.weight(.semibold)).buttonStyle(.bordered).buttonBorderShape(.capsule)
                    }
                }
                .padding(.horizontal, 16)
            }
            HStack(alignment: .bottom, spacing: 8) {
                TextField("Ask your coach…", text: $input, axis: .vertical)
                    .lineLimit(1...5)
                    .focused($focused)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(Theme.surface2, in: RoundedRectangle(cornerRadius: 22))
                    .submitLabel(.send)
                    .onSubmit { send(input) }
                if streaming != nil {
                    Button { task?.cancel() } label: { Image(systemName: "stop.circle.fill").font(.system(size: 34)) }
                        .accessibilityLabel("Stop")
                } else {
                    Button { send(input) } label: { Image(systemName: "arrow.up.circle.fill").font(.system(size: 34)) }
                        .disabled(input.trimmingCharacters(in: .whitespaces).isEmpty)
                        .accessibilityLabel("Send")
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 10)
        .background(.bar)
    }

    private func send(_ q: String) {
        let q = q.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty, streaming == nil else { return }
        input = ""
        focused = false
        store.data.chat.append(.init(role: .user, text: q))
        streaming = ""
        task = Task {
            do {
                let text = try await Coach.ask(q, store: store) { streaming = $0 }
                store.data.chat.append(.init(role: .coach, text: text))
            } catch is CancellationError {
                if let s = streaming, !s.isEmpty { store.data.chat.append(.init(role: .coach, text: s)) }
            } catch {
                if let s = streaming, !s.isEmpty { store.data.chat.append(.init(role: .coach, text: s)) }
                else { store.data.chat.append(.init(role: .coach, text: Coach.builtInAnswer(q, store: store))) }
            }
            streaming = nil
        }
    }
}

import SwiftUI

struct AssistantDrawerView: View {
    @Environment(AppStore.self) private var store
    @Environment(AssistantStore.self) private var assistant
    @State private var draft = ""

    private let suggestions = [
        "Where did this come from?",
        "Is this safe to remove?",
        "Why is this marked likely?",
        "Why is this shared?",
    ]

    var body: some View {
        @Bindable var assistant = assistant

        VStack(spacing: 0) {
            header
            Divider()
            connectionPanel
            Divider()
            messages
            Divider()
            composer
        }
        .frame(width: 340)
        .background(.regularMaterial)
        .task { await assistant.refreshConnection() }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Label("AI Assistant", systemImage: "sparkles")
                    .font(.headline)
                Text(scopeLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            Button {
                assistant.close()
            } label: {
                Image(systemName: "xmark")
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.borderless)
            .help("Close")
        }
        .padding(14)
    }

    @ViewBuilder
    private var connectionPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Circle()
                    .fill(assistant.connectionState.isConnected ? Color.green : Color.caution)
                    .frame(width: 8, height: 8)
                Text(assistant.connectionState.label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Spacer()
            }

            Text("Scrub sends cleanup metadata to ChatGPT/Codex only when you ask.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                if assistant.connectionState.isConnected {
                    Button("Disconnect") { assistant.disconnect() }
                } else {
                    Button("Connect ChatGPT") {
                        Task { await assistant.connect() }
                    }
                    Button("Check") {
                        Task { await assistant.refreshConnection() }
                    }
                }
            }
            .controlSize(.small)
        }
        .padding(14)
    }

    private var messages: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if assistant.messages.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Ask about the selected app, leftover group, or a specific row.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        ForEach(suggestions, id: \.self) { suggestion in
                            Button {
                                Task { await send(suggestion) }
                            } label: {
                                Text(suggestion)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.borderless)
                            .disabled(!assistant.connectionState.isConnected || store.assistantContext(focusedItem: focusedItem) == nil)
                        }
                    }
                    .padding(.vertical, 6)
                }

                ForEach(assistant.messages) { message in
                    MessageBubble(message: message)
                }

                if assistant.isAsking {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text("Thinking…")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 4)
                }
            }
            .padding(14)
        }
    }

    private var composer: some View {
        VStack(spacing: 8) {
            TextField("Ask about this cleanup item", text: $draft, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...4)
                .onSubmit {
                    Task { await send(draft) }
                }
            HStack {
                Button("Clear") {
                    assistant.messages.removeAll()
                }
                .disabled(assistant.messages.isEmpty)
                Spacer()
                Button("Ask") {
                    Task { await send(draft) }
                }
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || assistant.isAsking)
            }
        }
        .padding(14)
    }

    private var focusedItem: RelatedItem? {
        guard let url = assistant.focusedItemURL else { return nil }
        return store.detailItems.first { $0.url == url }
    }

    private var scopeLabel: String {
        if let focused = assistant.focusedItemName {
            return focused
        }
        if let app = store.selectedApp {
            return app.name
        }
        if let orphan = store.selectedOrphan {
            return orphan.displayName
        }
        return "No selection"
    }

    private func send(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        draft = ""
        await assistant.ask(trimmed, context: store.assistantContext(focusedItem: focusedItem))
    }
}

private struct MessageBubble: View {
    let message: AssistantMessage

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(message.role == .user ? "You" : "Assistant")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(message.text)
                .font(.callout)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(message.role == .user ? Color.accentColor.opacity(0.18) : Color.white.opacity(0.06),
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

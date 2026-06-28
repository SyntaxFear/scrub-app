import Foundation

enum AssistantConnectionState: Equatable {
    case disconnected
    case checking
    case connected(String)
    case needsLogin(String)
    case runtimeMissing
    case error(String)

    var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }

    var label: String {
        switch self {
        case .disconnected:
            return "Not connected"
        case .checking:
            return "Checking Codex…"
        case .connected(let status):
            return status
        case .needsLogin(let status):
            return status
        case .runtimeMissing:
            return "Codex runtime not found"
        case .error(let message):
            return message
        }
    }
}

struct AssistantMessage: Identifiable, Equatable {
    enum Role { case user, assistant }
    let id: UUID
    let role: Role
    var text: String
    var isStreaming: Bool

    init(id: UUID = UUID(), role: Role, text: String, isStreaming: Bool = false) {
        self.id = id
        self.role = role
        self.text = text
        self.isStreaming = isStreaming
    }
}

@MainActor
@Observable
final class AssistantStore {
    var isDrawerVisible = false
    var connectionState: AssistantConnectionState = .disconnected
    var messages: [AssistantMessage] = []
    var isAsking = false
    var focusedItemURL: URL?
    var focusedItemName: String?

    private var runtime: CodexRuntime?
    private let enabledKey = "chatGPTAssistantEnabled"

    var isEnabledByUser: Bool {
        get { UserDefaults.standard.bool(forKey: enabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }

    func open(focusedItem: RelatedItem? = nil) {
        focusedItemURL = focusedItem?.url
        focusedItemName = focusedItem?.displayName
        isDrawerVisible = true
        Task { await refreshConnection() }
    }

    func close() {
        isDrawerVisible = false
    }

    func refreshConnection() async {
        connectionState = .checking
        guard let found = CodexAssistantService.findRuntime() else {
            runtime = nil
            connectionState = .runtimeMissing
            return
        }
        runtime = found
        let status = await CodexAssistantService.loginStatus(runtime: found)
        switch status {
        case .chatGPT(let text):
            if isEnabledByUser {
                connectionState = .connected(text)
            } else {
                connectionState = .needsLogin("Codex is signed in with ChatGPT. Connect it to Scrub to use the assistant.")
            }
        case .apiKey(let text):
            connectionState = .needsLogin("\(text). Sign in with ChatGPT in Codex to use subscription-backed recommendations.")
        case .signedOut(let text):
            connectionState = .needsLogin(text)
        }
    }

    func connect() async {
        guard let found = CodexAssistantService.findRuntime() else {
            connectionState = .runtimeMissing
            return
        }
        runtime = found
        let status = await CodexAssistantService.loginStatus(runtime: found)
        switch status {
        case .chatGPT(let text):
            isEnabledByUser = true
            connectionState = .connected(text)
        case .apiKey, .signedOut:
            do {
                try CodexAssistantService.launchChatGPTLogin(runtime: found)
                connectionState = .needsLogin("Complete ChatGPT sign-in, then check connection.")
            } catch {
                connectionState = .error(error.localizedDescription)
            }
        }
    }

    func disconnect() {
        isEnabledByUser = false
        connectionState = .disconnected
        messages.removeAll()
        focusedItemURL = nil
        focusedItemName = nil
    }

    func ask(_ question: String, context: AssistantContext?) async {
        guard let context else {
            messages.append(.init(role: .assistant, text: "Select an app or leftover first."))
            return
        }
        guard connectionState.isConnected, let runtime else {
            isDrawerVisible = true
            await refreshConnection()
            messages.append(.init(role: .assistant, text: "Connect ChatGPT before asking the assistant."))
            return
        }

        isAsking = true
        messages.append(.init(role: .user, text: question))
        let responseID = UUID()
        let streamTarget = self
        messages.append(.init(id: responseID, role: .assistant, text: "", isStreaming: true))
        defer { isAsking = false }

        do {
            let answer = try await CodexAssistantService.askStreaming(
                question: question,
                context: context,
                runtime: runtime
            ) { delta in
                await MainActor.run {
                    streamTarget.append(delta, to: responseID)
                }
            }
            replaceStreamingMessage(responseID, with: answer)
        } catch {
            if messages.first(where: { $0.id == responseID })?.text.isEmpty == true {
                replaceStreamingMessage(responseID, with: "Streaming stalled. Finishing the answer…")
                do {
                    let answer = try await CodexAssistantService.ask(question: question, context: context, runtime: runtime)
                    replaceStreamingMessage(responseID, with: answer)
                } catch {
                    replaceStreamingMessage(responseID, with: error.localizedDescription)
                }
            } else {
                append("\n\n\(error.localizedDescription)", to: responseID)
                replaceStreamingMessage(responseID, with: messages.first(where: { $0.id == responseID })?.text ?? error.localizedDescription)
            }
        }
    }

    private func append(_ delta: String, to messageID: UUID) {
        guard let index = messages.firstIndex(where: { $0.id == messageID }) else { return }
        messages[index].text += delta
    }

    private func replaceStreamingMessage(_ messageID: UUID, with text: String) {
        guard let index = messages.firstIndex(where: { $0.id == messageID }) else {
            messages.append(.init(role: .assistant, text: text))
            return
        }
        messages[index].text = text
        messages[index].isStreaming = false
    }
}

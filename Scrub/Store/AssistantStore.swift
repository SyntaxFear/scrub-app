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
    let id = UUID()
    let role: Role
    let text: String
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
                connectionState = .needsLogin("Complete ChatGPT sign-in in Terminal, then check connection.")
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
        defer { isAsking = false }

        do {
            let answer = try await CodexAssistantService.ask(question: question, context: context, runtime: runtime)
            messages.append(.init(role: .assistant, text: answer))
        } catch {
            messages.append(.init(role: .assistant, text: error.localizedDescription))
        }
    }
}

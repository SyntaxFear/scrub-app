import Foundation

/// Performs the actual deletions. User-domain files are moved to the Trash
/// (reversible). Admin-domain files are removed permanently via a single
/// authenticated shell command (one password prompt for the whole batch).
enum Remover {

    struct Outcome: Sendable {
        var trashed: [URL] = []
        var removedWithAdmin: [URL] = []
        var failures: [(url: URL, message: String)] = []

        var totalRemoved: Int { trashed.count + removedWithAdmin.count }
    }

    enum RemoverError: Error, LocalizedError {
        case authorizationFailed(String)
        var errorDescription: String? {
            switch self {
            case .authorizationFailed(let m): return m
            }
        }
    }

    /// Splits items by domain, validates every path, then performs removals.
    /// Must be called from the main actor because the admin path shows a UI
    /// authorization prompt.
    @MainActor
    static func remove(_ items: [RelatedItem]) -> Outcome {
        var outcome = Outcome()

        var userURLs: [URL] = []
        var adminURLs: [URL] = []

        for item in items {
            do {
                try SafetyGuard.validate(item.url)
            } catch {
                outcome.failures.append((item.url, error.localizedDescription))
                continue
            }
            // An item may be flagged admin, or simply live somewhere the user
            // cannot write — both go through the privileged path.
            if item.domain == .admin || !FileSystem.isUserDeletable(item.url) {
                adminURLs.append(item.url)
            } else {
                userURLs.append(item.url)
            }
        }

        // 1. Trash user files.
        for url in userURLs {
            do {
                try FileSystem.fm.trashItem(at: url, resultingItemURL: nil)
                outcome.trashed.append(url)
            } catch {
                outcome.failures.append((url, error.localizedDescription))
            }
        }

        // 2. Remove admin files with a single authenticated command.
        if !adminURLs.isEmpty {
            do {
                try removeWithPrivileges(adminURLs)
                outcome.removedWithAdmin.append(contentsOf: adminURLs)
            } catch {
                for url in adminURLs {
                    outcome.failures.append((url, error.localizedDescription))
                }
            }
        }

        return outcome
    }

    /// Runs `/bin/rm -rf` over the given paths as root using an authenticated
    /// AppleScript prompt. Every path is re-validated and shell-quoted.
    @MainActor
    private static func removeWithPrivileges(_ urls: [URL]) throws {
        for url in urls { try SafetyGuard.validate(url) }

        let quoted = urls.map { shellQuote($0.path) }.joined(separator: " ")
        let command = "/bin/rm -rf \(quoted)"
        let source = "do shell script \"\(appleScriptEscape(command))\" with administrator privileges"

        var error: NSDictionary?
        guard let script = NSAppleScript(source: source) else {
            throw RemoverError.authorizationFailed("Could not construct the authorization request.")
        }
        script.executeAndReturnError(&error)

        if let error {
            let number = (error[NSAppleScript.errorNumber] as? Int) ?? 0
            // -128 is "user cancelled".
            if number == -128 {
                throw RemoverError.authorizationFailed("Authorization was cancelled.")
            }
            let message = (error[NSAppleScript.errorMessage] as? String) ?? "Authorization failed."
            throw RemoverError.authorizationFailed(message)
        }
    }

    /// Wraps a path in single quotes, escaping any embedded single quotes.
    private static func shellQuote(_ path: String) -> String {
        "'" + path.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    /// Escapes a string for embedding inside an AppleScript double-quoted literal.
    private static func appleScriptEscape(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
         .replacingOccurrences(of: "\"", with: "\\\"")
    }
}

import Foundation
import Security

/// Reads code-signing metadata from an app bundle. The Team Identifier is the
/// key that unlocks several leftover locations that are *not* named after the
/// bundle ID — most importantly Group Containers and some App Scripts, which are
/// frequently prefixed with the developer's 10-character team ID.
enum CodeSignature {

    /// The 10-character Apple Team Identifier the bundle is signed with, or nil
    /// if the bundle is unsigned / ad-hoc / unreadable.
    static func teamIdentifier(forBundleAt url: URL) -> String? {
        var staticCode: SecStaticCode?
        guard SecStaticCodeCreateWithPath(url as CFURL, [], &staticCode) == errSecSuccess,
              let code = staticCode else { return nil }

        var info: CFDictionary?
        let flags = SecCSFlags(rawValue: kSecCSSigningInformation)
        guard SecCodeCopySigningInformation(code, flags, &info) == errSecSuccess,
              let dict = info as? [String: Any] else { return nil }

        let team = dict[kSecCodeInfoTeamIdentifier as String] as? String
        return (team?.isEmpty == false) ? team : nil
    }
}

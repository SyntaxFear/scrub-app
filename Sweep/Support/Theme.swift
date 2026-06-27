import SwiftUI

extension Color {
    /// Scrub's brand orange-red — the identity color carried by the app icon and the
    /// website. The app UI itself uses the system accent color for controls and
    /// selection (the native macOS look), so this stays as the canonical brand token
    /// rather than being applied app-wide.
    static let brand = Color(red: 1.0, green: 0.36, blue: 0.16)

    /// Caution / warning emphasis — admin-required locks, the "running" notice, the
    /// full-disk-access prompt. Deliberately the *system* orange so it stays distinct
    /// from `brand` (warnings shouldn't read as an off-brand near-miss of the accent)
    /// and renders with correct vibrancy in both appearances.
    static let caution = Color(nsColor: .systemOrange)
}

/// Shared layout metrics, so equivalent surfaces stay aligned and consistent instead
/// of drifting across hand-tuned literals.
enum Metrics {
    /// Corner radius for controls, fields, and grouped wells (continuous squircle).
    static let cornerRadius: CGFloat = 11
    /// Horizontal inset for a pane's primary content — keeps the detail header's
    /// leading edge aligned with the table rows beneath it.
    static let contentInset: CGFloat = 20
}

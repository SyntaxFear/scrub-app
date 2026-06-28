import SwiftUI
import AppKit

/// The required sign-in screen — a clean, animated welcome with Apple, Google, and
/// email-code options. Elements stagger in on appear; buttons lift on hover.
struct AuthWallView: View {
    @Environment(AuthStore.self) private var auth
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var email = ""
    @State private var code = ""
    @State private var codeSent = false
    @State private var appeared = false
    @FocusState private var fieldFocused: Bool

    private let panelWidth: CGFloat = 300

    var body: some View {
        ZStack {
            backdrop
            content
            if auth.isBusy { busyOverlay }
        }
        .onAppear {
            appeared = true
            fieldFocused = true
        }
    }

    // MARK: - Background

    private var backdrop: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
            RadialGradient(
                colors: [Color.white.opacity(0.05), .clear],
                center: UnitPoint(x: 0.5, y: 0.18),
                startRadius: 1, endRadius: 480
            )
            .opacity(appeared ? 1 : 0)
            .animation(reduceMotion ? nil : .easeOut(duration: 1.2), value: appeared)
        }
        .ignoresSafeArea()
    }

    // MARK: - Content

    private var content: some View {
        VStack(spacing: 0) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .interpolation(.high)
                .frame(width: 86, height: 86)
                .shadow(color: Color.black.opacity(0.45), radius: 24, y: 10)
                .opacity(appeared ? 1 : 0)
                .scaleEffect(appeared || reduceMotion ? 1 : 0.8)
                .animation(reduceMotion ? .easeOut(duration: 0.25)
                                        : .spring(response: 0.72, dampingFraction: 0.6).delay(0.05),
                           value: appeared)
                .accessibilityHidden(true)

            VStack(spacing: 6) {
                Text("Welcome to Scrub")
                    .font(.system(size: 30, weight: .bold))
                    .tracking(-0.4)
                Text("Sign in to start cleaning up your Mac.")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 20)
            .reveal(appeared, 0.18)

            VStack(spacing: 10) {
                ProviderButton(title: "Continue with Apple", systemImage: "apple.logo", kind: .apple) {
                    auth.signInWithApple()
                }
                if auth.googleAvailable {
                    ProviderButton(title: "Continue with Google", assetIcon: "GoogleG", kind: .glass) {
                        auth.signInWithGoogle()
                    }
                }
                emailSection
            }
            .frame(width: panelWidth)
            .padding(.top, 30)
            .reveal(appeared, 0.3)

            if let error = auth.errorMessage {
                Text(error)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .frame(width: panelWidth)
                    .padding(.top, 16)
            }

            Text("Required to use Scrub. We never read or upload what you delete.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(width: panelWidth)
                .padding(.top, 22)
                .reveal(appeared, 0.46)
        }
        .padding(40)
    }

    // MARK: - Email code

    @ViewBuilder
    private var emailSection: some View {
        HStack(spacing: 10) {
            divider
            Text("or").font(.caption).foregroundStyle(.secondary)
            divider
        }
        .padding(.vertical, 2)

        if !codeSent {
            TextField("you@email.com", text: $email)
                .textFieldStyle(.plain)
                .textContentType(.emailAddress)
                .font(.system(size: 14))
                .focused($fieldFocused)
                .padding(.horizontal, 13)
                .frame(height: 44)
                .background(fieldBackground)
                .clipShape(RoundedRectangle(cornerRadius: Metrics.cornerRadius, style: .continuous))
                .onSubmit(sendCode)

            ProviderButton(title: "Email me a code", systemImage: "envelope",
                           kind: .glass, disabled: email.isEmpty, action: sendCode)
        } else {
            Text("Enter the 6-digit code sent to \(email).")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            TextField("123456", text: $code)
                .textFieldStyle(.plain)
                .textContentType(.oneTimeCode)
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .monospacedDigit()
                .multilineTextAlignment(.center)
                .focused($fieldFocused)
                .frame(height: 44)
                .background(fieldBackground)
                .clipShape(RoundedRectangle(cornerRadius: Metrics.cornerRadius, style: .continuous))
                .onSubmit(verify)
            ProviderButton(title: "Verify & continue", systemImage: "checkmark",
                           kind: .accent, disabled: code.count < 6, action: verify)
            Button("Use a different email") { codeSent = false; code = "" }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 2)
        }
    }

    private var divider: some View {
        Rectangle().fill(Color.white.opacity(0.14)).frame(height: 1)
    }

    private var fieldBackground: some View {
        RoundedRectangle(cornerRadius: Metrics.cornerRadius, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: Metrics.cornerRadius, style: .continuous)
                    .strokeBorder(fieldFocused ? Color.accentColor : Color.white.opacity(0.22),
                                  lineWidth: fieldFocused ? 1.5 : 1)
            )
            .animation(.easeOut(duration: 0.15), value: fieldFocused)
    }

    private var busyOverlay: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial).ignoresSafeArea()
            ProgressView().controlSize(.large)
        }
        // Cover and intercept hits so the provider buttons can't be tapped again
        // while a sign-in is already in flight.
        .contentShape(Rectangle())
    }

    private func sendCode() {
        guard !email.isEmpty else { return }
        Task {
            let sent = await auth.requestEmailCode(email)
            codeSent = sent
            if sent { fieldFocused = true }
        }
    }

    private func verify() {
        Task { await auth.verifyEmailCode(email: email, code: code) }
    }
}

// MARK: - Staggered reveal

private struct Reveal: ViewModifier {
    let active: Bool
    let delay: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func body(content: Content) -> some View {
        content
            .opacity(active ? 1 : 0)
            .offset(y: reduceMotion ? 0 : (active ? 0 : 16))
            .animation(reduceMotion ? .easeOut(duration: 0.25).delay(delay)
                                    : .spring(response: 0.62, dampingFraction: 0.86).delay(delay),
                       value: active)
    }
}

private extension View {
    func reveal(_ active: Bool, _ delay: Double) -> some View {
        modifier(Reveal(active: active, delay: delay))
    }
}

// MARK: - Provider button (Apple-style hover)

private struct ProviderButton: View {
    enum Kind { case apple, glass, accent }
    let title: String
    var systemImage: String = ""
    var assetIcon: String? = nil
    var kind: Kind = .glass
    var disabled: Bool = false
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hovering = false
    @State private var cursorPushed = false
    private var isLive: Bool { hovering && !disabled }

    @ViewBuilder private var iconView: some View {
        if let assetIcon {
            // Template rendering: the logo silhouette takes the button's text color
            // (monochrome), matching the Apple logo's treatment. Decorative — the
            // button title carries the meaning for VoiceOver.
            Image(assetIcon)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 14, height: 14)
                .accessibilityHidden(true)
        } else {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .accessibilityHidden(true)
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                iconView
                Text(title).font(.system(size: 15, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 44)
            .foregroundStyle(foreground)
            .background(fill)
            .overlay(
                RoundedRectangle(cornerRadius: Metrics.cornerRadius, style: .continuous)
                    .strokeBorder(stroke, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: Metrics.cornerRadius, style: .continuous))
            .scaleEffect(isLive && !reduceMotion ? 1.02 : 1)
            .shadow(color: shadowColor, radius: shadowRadius, y: shadowY)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.45 : 1)
        .onHover { h in
            hovering = h
            syncCursor(h && !disabled)
        }
        .onDisappear { syncCursor(false) }
        .animation(.easeOut(duration: 0.16), value: hovering)
    }

    // Balanced cursor push/pop: push exactly once on hover-in, pop exactly once on
    // hover-out or teardown. Replaces the previous unmatched pop() that corrupted the
    // global cursor stack (disabled-hover and mid-hover teardown both leaked).
    private func syncCursor(_ live: Bool) {
        if live && !cursorPushed {
            NSCursor.pointingHand.push(); cursorPushed = true
        } else if !live && cursorPushed {
            NSCursor.pop(); cursorPushed = false
        }
    }

    private var foreground: Color {
        switch kind {
        case .apple:  return .black
        case .glass:  return .primary
        case .accent: return .white
        }
    }

    @ViewBuilder private var fill: some View {
        switch kind {
        case .apple:
            Color.white.opacity(isLive ? 1 : 0.95)
        case .glass:
            // Genuine material — vibrant over the backdrop and opaque to the drop
            // shadow (so no bleed-through halo) — with a faint hover brighten.
            Rectangle().fill(.ultraThinMaterial)
                .overlay(Color.white.opacity(isLive ? 0.10 : 0.04))
        case .accent:
            Color.accentColor.opacity(isLive ? 1 : 0.92)
        }
    }

    private var stroke: Color {
        switch kind {
        case .glass: return Color.white.opacity(isLive ? 0.28 : 0.18)
        default:     return .clear
        }
    }

    private var shadowColor: Color {
        switch kind {
        case .apple:  return Color.black.opacity(0.22)
        case .glass:  return Color.black.opacity(0.28)
        case .accent: return Color.accentColor.opacity(0.4)
        }
    }

    // Glass casts no resting shadow (it would bleed through a translucent fill); it
    // lifts only on hover. Solid buttons keep a soft resting shadow.
    private var shadowRadius: CGFloat {
        switch kind {
        case .glass: return isLive ? 9 : 0
        default:     return isLive ? 14 : 5
        }
    }

    private var shadowY: CGFloat {
        switch kind {
        case .glass: return isLive ? 4 : 0
        default:     return isLive ? 5 : 2
        }
    }
}

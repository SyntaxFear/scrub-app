import SwiftUI
import AppKit

/// The required sign-in screen — a clean, animated welcome with Apple, Google, and
/// email-code options. Elements stagger in on appear; buttons lift on hover.
struct AuthWallView: View {
    @Environment(AuthStore.self) private var auth
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
        .onAppear { appeared = true }
    }

    // MARK: - Background

    private var backdrop: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
            RadialGradient(
                colors: [Color(red: 1.0, green: 0.45, blue: 0.2).opacity(0.18), .clear],
                center: UnitPoint(x: 0.5, y: 0.18),
                startRadius: 1, endRadius: 480
            )
            .opacity(appeared ? 1 : 0)
            .animation(.easeOut(duration: 1.2), value: appeared)
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
                .shadow(color: Color(red: 1, green: 0.32, blue: 0.2).opacity(0.4), radius: 28, y: 12)
                .opacity(appeared ? 1 : 0)
                .scaleEffect(appeared ? 1 : 0.8)
                .animation(.spring(response: 0.72, dampingFraction: 0.6).delay(0.05), value: appeared)

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
                .foregroundStyle(.tertiary)
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
            Text("or").font(.caption).foregroundStyle(.tertiary)
            divider
        }
        .padding(.vertical, 2)

        if !codeSent {
            TextField("you@email.com", text: $email)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .focused($fieldFocused)
                .padding(.horizontal, 13)
                .frame(height: 44)
                .background(fieldBackground)
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
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .multilineTextAlignment(.center)
                .focused($fieldFocused)
                .frame(height: 44)
                .background(fieldBackground)
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
        Rectangle().fill(Color.white.opacity(0.1)).frame(height: 1)
    }

    private var fieldBackground: some View {
        RoundedRectangle(cornerRadius: 11, style: .continuous)
            .fill(Color.white.opacity(0.05))
            .overlay(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .strokeBorder(fieldFocused ? Color.accentColor.opacity(0.8) : Color.white.opacity(0.12),
                                  lineWidth: 1)
            )
            .animation(.easeOut(duration: 0.15), value: fieldFocused)
    }

    private var busyOverlay: some View {
        ZStack {
            Color.black.opacity(0.08).ignoresSafeArea()
            ProgressView().controlSize(.large)
        }
    }

    private func sendCode() {
        guard !email.isEmpty else { return }
        Task { codeSent = await auth.requestEmailCode(email) }
    }

    private func verify() {
        Task { await auth.verifyEmailCode(email: email, code: code) }
    }
}

// MARK: - Staggered reveal

private struct Reveal: ViewModifier {
    let active: Bool
    let delay: Double
    func body(content: Content) -> some View {
        content
            .opacity(active ? 1 : 0)
            .offset(y: active ? 0 : 16)
            .animation(.spring(response: 0.62, dampingFraction: 0.86).delay(delay), value: active)
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

    @State private var hovering = false
    private var isLive: Bool { hovering && !disabled }

    @ViewBuilder private var iconView: some View {
        if let assetIcon {
            Image(assetIcon)
                .renderingMode(.original)
                .resizable()
                .scaledToFit()
                .frame(width: 17, height: 17)
        } else {
            Image(systemName: systemImage).font(.system(size: 15, weight: .semibold))
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                iconView
                Text(title).font(.system(size: 15, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .foregroundStyle(foreground)
            .background(background)
            .overlay(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .strokeBorder(stroke, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            .scaleEffect(isLive ? 1.02 : 1)
            .shadow(color: shadow, radius: isLive ? 16 : 6, y: isLive ? 6 : 3)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.45 : 1)
        .onHover { h in
            hovering = h
            if h && !disabled { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
        .animation(.easeOut(duration: 0.16), value: hovering)
    }

    private var foreground: Color {
        switch kind {
        case .apple:  return .black
        case .glass:  return .primary
        case .accent: return .white
        }
    }

    @ViewBuilder private var background: some View {
        switch kind {
        case .apple:
            Color.white.opacity(isLive ? 1 : 0.95)
        case .glass:
            Color.white.opacity(isLive ? 0.12 : 0.06)
        case .accent:
            LinearGradient(
                colors: [Color(red: 1, green: 0.62, blue: 0.04), Color(red: 1, green: 0.23, blue: 0.19)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .opacity(isLive ? 1 : 0.92)
        }
    }

    private var stroke: Color {
        switch kind {
        case .glass: return Color.white.opacity(isLive ? 0.2 : 0.12)
        default:     return .clear
        }
    }

    private var shadow: Color {
        switch kind {
        case .apple:  return Color.black.opacity(0.25)
        case .glass:  return Color.black.opacity(0.2)
        case .accent: return Color(red: 1, green: 0.3, blue: 0.2).opacity(isLive ? 0.5 : 0.25)
        }
    }
}

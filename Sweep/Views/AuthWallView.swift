import SwiftUI
import AppKit

/// The required sign-in screen, shown until the user authenticates. Offers Apple,
/// Google (when configured), and email-code sign-in.
struct AuthWallView: View {
    @Environment(AuthStore.self) private var auth
    @State private var email = ""
    @State private var code = ""
    @State private var codeSent = false

    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor).ignoresSafeArea()

            VStack(spacing: 24) {
                VStack(spacing: 10) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .frame(width: 72, height: 72)
                    Text("Set up Scrub").font(.largeTitle.weight(.bold))
                    Text("Sign in to start cleaning up your Mac.")
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 10) {
                    AuthProviderButton(title: "Continue with Apple",
                                       systemImage: "apple.logo",
                                       filled: true) {
                        auth.signInWithApple()
                    }

                    if auth.googleAvailable {
                        AuthProviderButton(title: "Continue with Google",
                                           systemImage: "globe",
                                           filled: false) {
                            auth.signInWithGoogle()
                        }
                    }

                    emailSection
                }
                .frame(width: 320)

                if let error = auth.errorMessage {
                    Text(error)
                        .font(.callout)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .frame(width: 320)
                }

                Text("Required to use Scrub. We never read or upload what you delete.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(width: 320)
            }
            .padding(40)

            if auth.isBusy {
                Color.black.opacity(0.04).ignoresSafeArea()
                ProgressView()
            }
        }
    }

    @ViewBuilder
    private var emailSection: some View {
        Divider().padding(.vertical, 4)
        if !codeSent {
            TextField("you@email.com", text: $email)
                .textFieldStyle(.roundedBorder)
                .disableAutocorrection(true)
            Button {
                Task { codeSent = await auth.requestEmailCode(email) }
            } label: {
                Text("Email me a code").frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            .disabled(email.isEmpty || auth.isBusy)
        } else {
            Text("Enter the 6-digit code sent to \(email).")
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField("123456", text: $code)
                .textFieldStyle(.roundedBorder)
                .onSubmit { verify() }
            Button {
                verify()
            } label: {
                Text("Verify & continue").frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)
            .disabled(code.count < 6 || auth.isBusy)
            Button("Use a different email") {
                codeSent = false
                code = ""
            }
            .buttonStyle(.plain)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private func verify() {
        Task { await auth.verifyEmailCode(email: email, code: code) }
    }
}

/// A full-width provider button — filled (Apple) or bordered (Google).
private struct AuthProviderButton: View {
    let title: String
    let systemImage: String
    let filled: Bool
    let action: () -> Void

    private var label: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
            Text(title).fontWeight(.medium)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    var body: some View {
        Group {
            if filled {
                Button(action: action) { label }
                    .buttonStyle(.borderedProminent)
                    .tint(.primary)
            } else {
                Button(action: action) { label }
                    .buttonStyle(.bordered)
            }
        }
        .controlSize(.large)
    }
}

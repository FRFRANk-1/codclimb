// CodClimb/Views/AuthView.swift
import SwiftUI

// MARK: - AuthView  (sign-in / sign-up / forgot password)

struct AuthView: View {
    @EnvironmentObject private var profileStore: UserProfileStore
    @Environment(\.dismiss) private var dismiss

    enum Mode { case signIn, signUp, forgotPassword }

    @State private var mode: Mode = .signIn
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var displayName = ""
    @State private var emailAlerts = true          // opt-in to future notification emails
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var successMessage: String? = nil

    private let firebase = FirebaseService.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    // Logo / header
                    VStack(spacing: 6) {
                        Image(systemName: "mountain.2.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(Theme.Palette.accent)
                        Text(mode == .forgotPassword ? "Reset Password"
                             : mode == .signIn ? "Welcome Back"
                             : "Create Account")
                            .font(Theme.Typography.title)
                            .foregroundStyle(Theme.Palette.textPrimary)
                        Text(mode == .forgotPassword
                             ? "We'll email you a reset link."
                             : mode == .signIn
                             ? "Sign in to see all community reports."
                             : "Join the CodClimb community.")
                            .font(Theme.Typography.callout)
                            .foregroundStyle(Theme.Palette.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 12)

                    // Form fields
                    VStack(spacing: 14) {
                        if mode == .signUp {
                            AuthField(icon: "person", placeholder: "Display name", text: $displayName)
                        }

                        AuthField(icon: "envelope", placeholder: "Email address", text: $email,
                                  keyboardType: .emailAddress)

                        if mode != .forgotPassword {
                            AuthField(icon: "lock", placeholder: "Password", text: $password,
                                      isSecure: true)
                        }

                        if mode == .signUp {
                            AuthField(icon: "lock.rotation", placeholder: "Confirm password",
                                      text: $confirmPassword, isSecure: true)

                            // Email alert opt-in
                            Toggle(isOn: $emailAlerts) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Condition alert emails")
                                        .font(Theme.Typography.callout)
                                        .foregroundStyle(Theme.Palette.textPrimary)
                                    Text("Get emailed when a saved crag hits your score threshold.")
                                        .font(Theme.Typography.caption)
                                        .foregroundStyle(Theme.Palette.textTertiary)
                                }
                            }
                            .tint(Theme.Palette.accent)
                            .padding(Theme.Metrics.cardPadding)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Theme.Palette.surface)
                            )
                        }
                    }

                    // Error / success feedback
                    if let err = errorMessage {
                        Label(err, systemImage: "exclamationmark.triangle")
                            .font(Theme.Typography.callout)
                            .foregroundStyle(Theme.Palette.nogo)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Theme.Palette.nogo.opacity(0.10)))
                    }

                    if let msg = successMessage {
                        Label(msg, systemImage: "checkmark.circle")
                            .font(Theme.Typography.callout)
                            .foregroundStyle(Theme.Palette.good)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Theme.Palette.good.opacity(0.10)))
                    }

                    // Primary action button
                    Button {
                        Task { await primaryAction() }
                    } label: {
                        Group {
                            if isLoading {
                                ProgressView().tint(.white)
                            } else {
                                Text(mode == .forgotPassword ? "Send Reset Link"
                                     : mode == .signIn ? "Sign In"
                                     : "Create Account")
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Theme.Palette.accent)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(isLoading || !isFormValid)
                    .opacity(isFormValid ? 1.0 : 0.55)

                    // Mode switching links
                    modeLinks
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
            .background(Theme.Palette.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
    }

    // MARK: - Mode switching links

    private var modeLinks: some View {
        VStack(spacing: 10) {
            if mode == .signIn {
                Button("Forgot your password?") { withAnimation { mode = .forgotPassword } }
                    .font(Theme.Typography.callout)
                    .foregroundStyle(Theme.Palette.accent)

                HStack(spacing: 4) {
                    Text("New to CodClimb?")
                        .foregroundStyle(Theme.Palette.textSecondary)
                    Button("Create account") { withAnimation { mode = .signUp } }
                        .foregroundStyle(Theme.Palette.accent)
                }
                .font(Theme.Typography.callout)

            } else if mode == .signUp {
                HStack(spacing: 4) {
                    Text("Already have an account?")
                        .foregroundStyle(Theme.Palette.textSecondary)
                    Button("Sign in") { withAnimation { mode = .signIn } }
                        .foregroundStyle(Theme.Palette.accent)
                }
                .font(Theme.Typography.callout)

            } else {
                Button("Back to sign in") { withAnimation { mode = .signIn } }
                    .font(Theme.Typography.callout)
                    .foregroundStyle(Theme.Palette.accent)
            }
        }
    }

    // MARK: - Validation

    private var isFormValid: Bool {
        let trimmedEmail = email.trimmingCharacters(in: .whitespaces)
        switch mode {
        case .forgotPassword:
            return !trimmedEmail.isEmpty && trimmedEmail.contains("@")
        case .signIn:
            return !trimmedEmail.isEmpty && !password.isEmpty
        case .signUp:
            return !trimmedEmail.isEmpty && !password.isEmpty
                && password == confirmPassword && password.count >= 6
                && !displayName.trimmingCharacters(in: .whitespaces).isEmpty
        }
    }

    // MARK: - Actions

    private func primaryAction() async {
        errorMessage = nil
        successMessage = nil
        isLoading = true
        defer { isLoading = false }

        let trimEmail = email.trimmingCharacters(in: .whitespaces)
        let trimName  = displayName.trimmingCharacters(in: .whitespaces)

        do {
            switch mode {
            case .signIn:
                try await firebase.signIn(email: trimEmail, password: password)
                await profileStore.loadCurrentProfile()
                dismiss()

            case .signUp:
                try await firebase.signUp(email: trimEmail, password: password, displayName: trimName)
                // Save the profile, carrying over emailAlerts preference
                await profileStore.saveProfile(displayName: trimName, bio: "")
                // Store the email-alert preference on the profile document
                if emailAlerts {
                    await profileStore.setEmailAlerts(enabled: true, email: trimEmail)
                }
                dismiss()

            case .forgotPassword:
                try await firebase.resetPassword(email: trimEmail)
                successMessage = "Check your inbox — a reset link is on its way."
            }
        } catch let err as NSError {
            errorMessage = friendlyError(err)
        }
    }

    private func friendlyError(_ err: NSError) -> String {
        // Firebase Auth error codes
        switch err.code {
        case 17007: return "An account with this email already exists."
        case 17009: return "Incorrect password. Please try again."
        case 17011: return "No account found with that email."
        case 17026: return "Password must be at least 6 characters."
        case 17008: return "Please enter a valid email address."
        default:    return err.localizedDescription
        }
    }
}

// MARK: - Reusable text field

private struct AuthField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var isSecure: Bool = false

    @State private var isRevealed = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(Theme.Palette.textTertiary)
                .frame(width: 20)

            if isSecure && !isRevealed {
                SecureField(placeholder, text: $text)
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Palette.textPrimary)
            } else {
                TextField(placeholder, text: $text)
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Palette.textPrimary)
                    .keyboardType(keyboardType)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }

            if isSecure {
                Button {
                    isRevealed.toggle()
                } label: {
                    Image(systemName: isRevealed ? "eye.slash" : "eye")
                        .font(.system(size: 16))
                        .foregroundStyle(Theme.Palette.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Theme.Palette.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Theme.Palette.divider, lineWidth: 1)
                )
        )
    }
}

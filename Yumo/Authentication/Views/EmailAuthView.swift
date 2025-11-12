//
//  EmailAuthView.swift
//  Yumo
//

import SwiftUI
import SwiftData

struct EmailAuthView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var authManager: AuthManager
    @ObservedObject private var deepLinkManager = DeepLinkManager.shared

    let isSignUp: Bool
    let userName: String?
    var onSuccess: () -> Void

    @State private var email: String = ""
    @State private var password: String = ""
    @State private var confirmPassword: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var showResetPassword: Bool = false
    @State private var resetEmail: String = ""
    @State private var resetSent: Bool = false
    @State private var isResetting: Bool = false

    private var primaryTextColor: Color {
        colorScheme == .dark ? Color("AppTextPrimary") : .black
    }

    private var secondaryTextColor: Color {
        primaryTextColor.opacity(0.7)
    }

    private var baseBackgroundColor: Color {
        colorScheme == .dark
            ? Color("AppPrimaryDark")
            : Color(red: 244 / 255, green: 245 / 255, blue: 247 / 255)
    }

    private var isFormValid: Bool {
        if isSignUp {
            return !email.isEmpty && !password.isEmpty && password == confirmPassword && password.count >= 6
        } else {
            return !email.isEmpty && !password.isEmpty
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                baseBackgroundColor.ignoresSafeArea()
                _buildDynamicBackground()

                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 8) {
                            Image(systemName: isSignUp ? "person.badge.plus" : "person.circle")
                                .font(.system(size: 60))
                                .foregroundStyle(Color("AppSecondaryAccent"))

                            Text(isSignUp ? "Create Account" : "Welcome Back")
                                .font(.title).bold()
                                .foregroundStyle(primaryTextColor)

                            Text(isSignUp ? "Sign up with your email" : "Sign in to your account")
                                .font(.subheadline)
                                .foregroundStyle(secondaryTextColor)
                        }
                        .padding(.top, 40)

                        // Form
                        VStack(spacing: 16) {
                            // Email Field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Email")
                                    .font(.headline)
                                    .foregroundStyle(primaryTextColor.opacity(0.8))

                                TextField("your@email.com", text: $email)
                                    .textFieldStyle(.plain)
                                    .font(.body)
                                    .foregroundStyle(primaryTextColor)
                                    .padding()
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(primaryTextColor.opacity(0.1))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(primaryTextColor.opacity(0.2), lineWidth: 1)
                                    )
                                    .keyboardType(.emailAddress)
                                    .textContentType(.emailAddress) // Hint keyboard to surface saved emails / autofill
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                            }

                            // Password Field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Password")
                                    .font(.headline)
                                    .foregroundStyle(primaryTextColor.opacity(0.8))

                                SecureField("Password", text: $password)
                                    .textFieldStyle(.plain)
                                    .font(.body)
                                    .foregroundStyle(primaryTextColor)
                                    .padding()
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(primaryTextColor.opacity(0.1))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(primaryTextColor.opacity(0.2), lineWidth: 1)
                                    )
                                    .textContentType(isSignUp ? .newPassword : .password)

                                if isSignUp {
                                    Text("Must be at least 6 characters")
                                        .font(.caption)
                                        .foregroundStyle(secondaryTextColor)
                                } else {
                                    // Forgot Password button (Sign In only)
                                    HStack {
                                        Spacer()
                                        Button {
                                            resetEmail = email
                                            showResetPassword = true
                                        } label: {
                                            Text("Forgot Password?")
                                                .font(.caption)
                                                .foregroundStyle(Color("AppSecondaryAccent"))
                                        }
                                    }
                                }
                            }

                            // Confirm Password (Sign Up only)
                            if isSignUp {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Confirm Password")
                                        .font(.headline)
                                        .foregroundStyle(primaryTextColor.opacity(0.8))

                                    SecureField("Confirm Password", text: $confirmPassword)
                                        .textFieldStyle(.plain)
                                        .font(.body)
                                        .foregroundStyle(primaryTextColor)
                                        .padding()
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(primaryTextColor.opacity(0.1))
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(
                                                    !confirmPassword.isEmpty && password != confirmPassword
                                                        ? Color.red.opacity(0.5)
                                                        : primaryTextColor.opacity(0.2),
                                                    lineWidth: 1
                                                )
                                        )
                                        .textContentType(.newPassword)

                                    if !confirmPassword.isEmpty && password != confirmPassword {
                                        Text("Passwords don't match")
                                            .font(.caption)
                                            .foregroundStyle(.red)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 24)

                        // Error Message
                        if let error = errorMessage {
                            Text(error)
                                .font(.callout)
                                .foregroundStyle(.red)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                        }

                        // Submit Button
                        Button {
                            Task { await submitForm() }
                        } label: {
                            HStack {
                                if isLoading {
                                    ProgressView()
                                        .tint(.black)
                                } else {
                                    Text(isSignUp ? "Create Account" : "Sign In")
                                        .font(.headline).bold()
                                }
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(isFormValid ? Color("AppSecondaryAccent") : Color.gray.opacity(0.3))
                            .foregroundStyle(isFormValid ? .black : primaryTextColor.opacity(0.5))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .disabled(!isFormValid || isLoading)
                        .padding(.horizontal, 24)

                        Spacer()
                    }
                }
            }
            .dismissKeyboardOnTap()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(primaryTextColor)
                    }
                }
            }
            .sheet(isPresented: $showResetPassword) {
                _buildResetPasswordSheet()
            }
            .onChange(of: deepLinkManager.shouldDismissAuthSheets) { _, shouldDismiss in
                if shouldDismiss {
                    print("🔐 EmailAuthView dismissing due to password reset deep link")
                    showResetPassword = false
                    dismiss()
                    deepLinkManager.clearDismissFlag()
                }
            }
        }
    }

    // MARK: - Reset Password Sheet

    @ViewBuilder
    private func _buildResetPasswordSheet() -> some View {
        NavigationStack {
            ZStack {
                baseBackgroundColor.ignoresSafeArea()

                VStack(spacing: 24) {
                    // Icon
                    Image(systemName: resetSent ? "checkmark.circle.fill" : "envelope.badge")
                        .font(.system(size: 60))
                        .foregroundStyle(resetSent ? .green : Color("AppSecondaryAccent"))
                        .padding(.top, 40)

                    // Title & Description
                    VStack(spacing: 8) {
                        Text(resetSent ? "Email Sent" : "Reset Password")
                            .font(.title).bold()
                            .foregroundStyle(primaryTextColor)

                        Text(resetSent
                             ? "Check your inbox for a link to reset your password."
                             : "Enter your email and we'll send you a link to reset your password.")
                            .font(.subheadline)
                            .foregroundStyle(secondaryTextColor)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }

                    if !resetSent {
                        // Email Field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Email")
                                .font(.headline)
                                .foregroundStyle(primaryTextColor.opacity(0.8))

                            TextField("your@email.com", text: $resetEmail)
                                .textFieldStyle(.plain)
                                .font(.body)
                                .foregroundStyle(primaryTextColor)
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(primaryTextColor.opacity(0.1))
                                )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(primaryTextColor.opacity(0.2), lineWidth: 1)
                                    )
                                .keyboardType(.emailAddress)
                                .textContentType(.emailAddress) // Hint keyboard to surface saved emails / autofill
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        }
                        .padding(.horizontal, 24)

                        // Send Button
                        Button {
                            Task { await sendResetEmail() }
                        } label: {
                            HStack {
                                if isResetting {
                                    ProgressView()
                                        .tint(.black)
                                } else {
                                    Text("Send Reset Link")
                                        .font(.headline).bold()
                                }
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(!resetEmail.isEmpty ? Color("AppSecondaryAccent") : Color.gray.opacity(0.3))
                            .foregroundStyle(!resetEmail.isEmpty ? .black : primaryTextColor.opacity(0.5))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .disabled(resetEmail.isEmpty || isResetting)
                        .padding(.horizontal, 24)
                    } else {
                        // Done Button
                        Button {
                            showResetPassword = false
                            resetSent = false
                            resetEmail = ""
                        } label: {
                            Text("Done")
                                .font(.headline).bold()
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color("AppSecondaryAccent"))
                                .foregroundStyle(.black)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .padding(.horizontal, 24)
                    }

                    Spacer()
                }
            }
            .dismissKeyboardOnTap()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showResetPassword = false
                        resetSent = false
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(primaryTextColor)
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Send Reset Email

    private func sendResetEmail() async {
        isResetting = true

        do {
            try await authManager.resetPassword(email: resetEmail)
            await MainActor.run {
                isResetting = false
                resetSent = true
            }
        } catch {
            await MainActor.run {
                isResetting = false
                errorMessage = error.localizedDescription
                showResetPassword = false
            }
        }
    }

    // MARK: - Submit Form

    private func submitForm() async {
        isLoading = true
        errorMessage = nil

        do {
            if isSignUp {
                try await authManager.signUpWithEmail(
                    email: email,
                    password: password,
                    fullName: userName
                )
            } else {
                try await authManager.signInWithEmail(
                    email: email,
                    password: password
                )
            }

            // Complete sign-in with data migration
            if let user = authManager.currentUser {
                await authManager.completeSignIn(user: user, modelContext: modelContext)
            }

            await MainActor.run {
                isLoading = false
                onSuccess()
                dismiss()
            }

        } catch {
            await MainActor.run {
                isLoading = false
                errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Background

    @ViewBuilder
    private func _buildDynamicBackground() -> some View {
        ZStack {
            RadialGradient(
                gradient: Gradient(colors: [Color("AppSecondaryAccent").opacity(0.3), .clear]),
                center: .topLeading,
                startRadius: 50,
                endRadius: 450
            )
            .offset(x: -150, y: -150)

            RadialGradient(
                gradient: Gradient(colors: [Color("AppPrimaryAccent").opacity(0.4), .clear]),
                center: .bottomTrailing,
                startRadius: 100,
                endRadius: 500
            )
            .offset(x: 100, y: 150)
        }
        .blur(radius: 60)
    }
}

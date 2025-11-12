//
//  SetNewPasswordView.swift
//  Yumo
//

import SwiftUI
import Supabase
import Auth

struct SetNewPasswordView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var authManager: AuthManager

    let url: URL?

    @State private var newPassword: String = ""
    @State private var confirmPassword: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var isSuccess: Bool = false
    @State private var sessionRestored: Bool = false

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
        !newPassword.isEmpty && newPassword.count >= 6 && newPassword == confirmPassword
    }

    var body: some View {
        NavigationStack {
            ZStack {
                baseBackgroundColor.ignoresSafeArea()

                VStack(spacing: 24) {
                    // Icon
                    Image(systemName: isSuccess ? "checkmark.circle.fill" : "lock.rotation")
                        .font(.system(size: 60))
                        .foregroundStyle(isSuccess ? .green : Color("AppSecondaryAccent"))
                        .padding(.top, 40)

                    // Title & Description
                    VStack(spacing: 8) {
                        Text(isSuccess ? "Password Updated" : "Set New Password")
                            .font(.title).bold()
                            .foregroundStyle(primaryTextColor)

                        Text(isSuccess
                             ? "Your password has been updated. You can now sign in with your new password."
                             : "Enter your new password below.")
                            .font(.subheadline)
                            .foregroundStyle(secondaryTextColor)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }

                    if !isSuccess {
                        // Password Fields
                        VStack(spacing: 16) {
                            // New Password
                            VStack(alignment: .leading, spacing: 8) {
                                Text("New Password")
                                    .font(.headline)
                                    .foregroundStyle(primaryTextColor.opacity(0.8))

                                SecureField("New Password", text: $newPassword)
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
                                    .textContentType(.newPassword)

                                Text("Must be at least 6 characters")
                                    .font(.caption)
                                    .foregroundStyle(secondaryTextColor)
                            }

                            // Confirm Password
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
                                                !confirmPassword.isEmpty && newPassword != confirmPassword
                                                    ? Color.red.opacity(0.5)
                                                    : primaryTextColor.opacity(0.2),
                                                lineWidth: 1
                                            )
                                    )
                                    .textContentType(.newPassword)

                                if !confirmPassword.isEmpty && newPassword != confirmPassword {
                                    Text("Passwords don't match")
                                        .font(.caption)
                                        .foregroundStyle(.red)
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

                        // Update Button
                        Button {
                            Task { await updatePassword() }
                        } label: {
                            HStack {
                                if isLoading {
                                    ProgressView()
                                        .tint(.black)
                                } else {
                                    Text("Update Password")
                                        .font(.headline).bold()
                                }
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(isFormValid ? Color("AppSecondaryAccent") : Color.gray.opacity(0.3))
                            .foregroundStyle(isFormValid ? .black : primaryTextColor.opacity(0.5))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .disabled(!isFormValid || isLoading || !sessionRestored)
                        .padding(.horizontal, 24)

                        if !sessionRestored {
                            Text("Verifying reset link...")
                                .font(.caption)
                                .foregroundStyle(secondaryTextColor)
                        }
                    } else {
                        // Done Button
                        Button {
                            dismiss()
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
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(primaryTextColor)
                    }
                }
            }
            .task {
                await restoreSession()
            }
        }
    }

    // MARK: - Restore Session from URL

    private func restoreSession() async {
        guard let url = url else {
            errorMessage = "Invalid reset link"
            return
        }

        do {
            // Supabase will parse the token from the URL and restore the session
            try await supabase.auth.session(from: url)
            await MainActor.run {
                sessionRestored = true
            }
            print("✅ Password reset session restored")
        } catch {
            await MainActor.run {
                errorMessage = "Invalid or expired reset link. Please request a new one."
            }
            print("❌ Failed to restore session: \(error)")
        }
    }

    // MARK: - Update Password

    private func updatePassword() async {
        isLoading = true
        errorMessage = nil

        do {
            try await supabase.auth.update(user: .init(password: newPassword))
            await MainActor.run {
                isLoading = false
                isSuccess = true
            }
            print("✅ Password updated successfully")
        } catch {
            await MainActor.run {
                isLoading = false
                errorMessage = error.localizedDescription
            }
            print("❌ Failed to update password: \(error)")
        }
    }
}

//
//  GoogleSignInButtonView.swift
//  Yumo
//

import SwiftUI
import GoogleSignIn

struct GoogleSignInButtonView: View {
    var onSuccess: (_ idToken: String, _ accessToken: String, _ fullName: String?) -> Void
    var onError: ((Error) -> Void)?

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button {
            signInWithGoogle()
        } label: {
            HStack(spacing: 12) {
                // Google "G" logo using colors
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 22, height: 22)

                    Text("G")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.red, .yellow, .green, .blue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }

                Text("Sign in with Google")
                    .font(.system(size: 17, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color.white)
            .foregroundColor(.black.opacity(0.7))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onAppear {
            print("🔵 [GoogleSignInButtonView] Button appeared in view hierarchy")
        }
    }

    private func signInWithGoogle() {
        print("🔵 [GoogleSignInButtonView] Sign in button tapped")

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            print("🔵 [GoogleSignInButtonView] Failed to get root view controller")
            onError?(AuthError.googleSignInFailed)
            return
        }

        // Find the topmost presented view controller
        var topViewController = rootViewController
        while let presented = topViewController.presentedViewController {
            topViewController = presented
        }

        print("🔵 [GoogleSignInButtonView] Starting Google Sign-In flow")

        GIDSignIn.sharedInstance.signIn(withPresenting: topViewController) { result, error in
            if let error = error {
                print("🔵 [GoogleSignInButtonView] Google Sign-In error: \(error.localizedDescription)")

                // Check if user cancelled
                if (error as NSError).code == GIDSignInError.canceled.rawValue {
                    print("🔵 [GoogleSignInButtonView] User cancelled sign-in")
                    onError?(AuthError.googleSignInCancelled)
                } else {
                    onError?(AuthError.googleSignInFailed)
                }
                return
            }

            guard let user = result?.user,
                  let idToken = user.idToken?.tokenString else {
                print("🔵 [GoogleSignInButtonView] Failed to get ID token")
                onError?(AuthError.googleSignInFailed)
                return
            }

            let accessToken = user.accessToken.tokenString
            let fullName = user.profile?.name

            print("🔵 [GoogleSignInButtonView] Sign-in successful for: \(user.profile?.email ?? "Unknown")")

            onSuccess(idToken, accessToken, fullName)
        }
    }
}

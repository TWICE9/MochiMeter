import SwiftUI
import AuthenticationServices

struct SignInWithAppleButtonView: View {

    var onRequest: (ASAuthorizationAppleIDRequest) -> Void
    var onCompletion: (ASAuthorization) -> Void   // expects SUCCESS only

    var body: some View {
        SignInWithAppleButton(
            .signIn,
            onRequest: { request in
                print("🍎 [SignInWithAppleButtonView] Native button onRequest triggered")
                onRequest(request)
            },
            onCompletion: { result in                // 👈 THIS IS A Result<ASAuthorization, Error>
                print("🍎 [SignInWithAppleButtonView] Native button onCompletion triggered")
                switch result {
                case .success(let authorization):    // 👈 Extract the success value
                    print("🍎 [SignInWithAppleButtonView] Authorization succeeded")
                    onCompletion(authorization)
                case .failure(let error):
                    print("🍎 [SignInWithAppleButtonView] Sign in with Apple failed:", error.localizedDescription)
                }
            }
        )
        .signInWithAppleButtonStyle(.white)
        .frame(height: 50)
        .cornerRadius(12)
        .buttonStyle(.borderless)
        .onAppear {
            print("🍎 [SignInWithAppleButtonView] Button appeared in view hierarchy")
        }
    }
}

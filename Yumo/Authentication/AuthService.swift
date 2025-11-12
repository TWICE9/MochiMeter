//
//  AuthService.swift
//  Yumo
//
//  Created by Apple on 19/11/2025.
//


//
//  AuthService.swift
//  Yumo
//

import Foundation
import Supabase
import Auth

protocol AuthService: Sendable {
    func currentSession() async throws -> Session?
    func signInWithApple(idToken: String, nonce: String) async throws -> User
    func signInWithGoogle(idToken: String, accessToken: String) async throws -> User
    func signUpWithEmail(email: String, password: String) async throws -> User
    func signInWithEmail(email: String, password: String) async throws -> User
    func resetPassword(email: String) async throws
    func signOut() async throws
}

actor SupabaseAuthService: AuthService {
    private let client: SupabaseClient

    init(client: SupabaseClient = supabase) {
        self.client = client
    }

    func currentSession() async throws -> Session? {
        do {
            let session = try await client.auth.session
            return session
        } catch {
            return nil
        }
    }

    func signInWithApple(idToken: String, nonce: String) async throws -> User {
        let session = try await client.auth.signInWithIdToken(
            credentials: .init(
                provider: .apple,
                idToken: idToken,
                nonce: nonce
            )
        )
        return session.user
    }

    func signInWithGoogle(idToken: String, accessToken: String) async throws -> User {
        let session = try await client.auth.signInWithIdToken(
            credentials: .init(
                provider: .google,
                idToken: idToken,
                accessToken: accessToken,
                nonce: nil
            )
        )
        return session.user
    }

    func signUpWithEmail(email: String, password: String) async throws -> User {
        let response = try await client.auth.signUp(
            email: email,
            password: password
        )
        return response.user
    }

    func signInWithEmail(email: String, password: String) async throws -> User {
        let session = try await client.auth.signIn(
            email: email,
            password: password
        )
        return session.user
    }

    func resetPassword(email: String) async throws {
        try await client.auth.resetPasswordForEmail(
            email,
            redirectTo: URL(string: "mochimeter://reset-password")
        )
    }

    func signOut() async throws {
        try await client.auth.signOut()
    }
}

// MARK: - Auth Errors
enum AuthError: LocalizedError {
    case signUpFailed
    case signInFailed
    case invalidCredentials
    case googleSignInFailed
    case googleSignInCancelled

    var errorDescription: String? {
        switch self {
        case .signUpFailed:
            return "Failed to create account. Please try again."
        case .signInFailed:
            return "Failed to sign in. Please check your credentials."
        case .invalidCredentials:
            return "Invalid email or password."
        case .googleSignInFailed:
            return "Google sign-in failed. Please try again."
        case .googleSignInCancelled:
            return "Google sign-in was cancelled."
        }
    }
}

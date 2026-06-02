//
//  DeviceTokenManager.swift
//  Yumo
//
//  Saves and manages APNs device tokens in Supabase for push notifications.
//

import Foundation
@preconcurrency import Supabase

actor DeviceTokenManager {
    static let shared = DeviceTokenManager()

    private var lastSavedToken: String?

    private init() {}

    /// Saves the APNs device token to Supabase, linked to the current user.
    /// Called from AppDelegate when the token is received.
    func saveToken(_ token: String) async {
        // Avoid redundant writes if token hasn't changed
        guard token != lastSavedToken else { return }

        guard let userId = await UserSession.shared.getCurrentUserId() else {
            print("📲 Device token received but no user logged in — will save on next login")
            // Store locally so we can save it when the user logs in
            UserDefaults.standard.set(token, forKey: "pending_device_token")
            return
        }

        await uploadToken(token, userId: userId)
    }

    /// Call this after login to push any pending device token
    func savePendingTokenIfNeeded() async {
        guard let token = UserDefaults.standard.string(forKey: "pending_device_token") else { return }
        guard let userId = await UserSession.shared.getCurrentUserId() else { return }

        await uploadToken(token, userId: userId)
        UserDefaults.standard.removeObject(forKey: "pending_device_token")
    }

    private func uploadToken(_ token: String, userId: String) async {
        struct DeviceTokenRecord: Codable {
            let user_id: String
            let token: String
            let platform: String
        }

        let record = DeviceTokenRecord(user_id: userId, token: token, platform: "ios")

        do {
            // Upsert: insert or update if this user+token combo already exists
            try await supabase.database
                .from("device_tokens")
                .upsert(record, onConflict: "user_id,token")
                .execute()

            lastSavedToken = token
            print("📲 Device token saved to Supabase")
        } catch {
            print("❌ Failed to save device token: \(error)")
        }
    }

    /// Removes the device token on logout
    func removeToken() async {
        guard let token = lastSavedToken,
              let userId = await UserSession.shared.getCurrentUserId() else { return }

        do {
            try await supabase.database
                .from("device_tokens")
                .delete()
                .eq("user_id", value: userId)
                .eq("token", value: token)
                .execute()

            lastSavedToken = nil
            print("📲 Device token removed from Supabase")
        } catch {
            print("❌ Failed to remove device token: \(error)")
        }
    }
}

//
//  UserSession.swift
//  Yumo
//
//  Manages the current user ID using App Group UserDefaults
//  This is shared between the main app and widgets
//

import Foundation

actor UserSession {
    static let shared = UserSession()
    private init() {}

    private let userIdKey = "current_user_id"
    private let appGroupDefaults = UserDefaults(suiteName: "group.com.jesseta.yumo")!

    /// Get the current user ID (returns nil if not signed in)
    func getCurrentUserId() -> String? {
        return appGroupDefaults.string(forKey: userIdKey)
    }

    /// Set the user ID after sign in
    func setUserId(_ userId: String) {
        appGroupDefaults.set(userId, forKey: userIdKey)
        print("✅ UserSession: Set userId = \(userId)")
    }

    /// Clear the user ID on sign out (keeps local data)
    func clearUserId() {
        appGroupDefaults.removeObject(forKey: userIdKey)
        print("🗑️ UserSession: Cleared userId")
    }
}

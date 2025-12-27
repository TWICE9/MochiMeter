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

    private let userIdKey = "current_user_id"
    private let appGroupDefaults: UserDefaults?

    private init(suiteName: String = "group.com.jesseta.yumo") {
        self.appGroupDefaults = UserDefaults(suiteName: suiteName)
        if appGroupDefaults == nil {
            assertionFailure("Failed to initialize App Group UserDefaults. Check entitlements.")
        }
    }

    /// Get the current user ID (returns nil if not signed in or app group unavailable)
    func getCurrentUserId() -> String? {
        return appGroupDefaults?.string(forKey: userIdKey)
    }

    /// Set the user ID after sign in
    func setUserId(_ userId: String) {
        appGroupDefaults?.set(userId, forKey: userIdKey)
        #if DEBUG
        print("UserSession: Set userId")
        #endif
    }

    /// Clear the user ID on sign out (keeps local data)
    func clearUserId() {
        appGroupDefaults?.removeObject(forKey: userIdKey)
        #if DEBUG
        print("UserSession: Cleared userId")
        #endif
    }
}

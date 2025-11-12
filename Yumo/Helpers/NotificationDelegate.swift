//
//  must.swift
//  Yumo
//
//  Created by Apple on 9/11/2025.
//


// Helpers/NotificationDelegate.swift

import SwiftUI
import UserNotifications

// ⭐️ This class must inherit from NSObject and conform to the delegate protocol.
class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {

    // This function is required to allow notifications to show when the app is in the foreground.
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show the banner and play a sound
        completionHandler([.banner, .sound])
    }
}
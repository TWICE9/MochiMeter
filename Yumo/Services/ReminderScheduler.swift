// Services/ReminderScheduler.swift

import Foundation
import UserNotifications

struct ReminderScheduler {
    
    /// Schedules notifications for the specific days selected
    static func scheduleReminder(_ reminder: Reminder) {
        // First, clear any old versions of this reminder to be safe
        cancelReminder(reminder)
        
        let content = UNMutableNotificationContent()
        
        // ⭐️ 1. Set the main bold title to the Reminder's title
        content.title = reminder.title
        
        // ⭐️ 2. Set the body text
        if !reminder.notes.isEmpty {
            // If user wrote notes, show them
            content.body = reminder.notes
        } else {
            // If no notes, repeat the title in a friendly sentence
            content.body = "It's time to \(reminder.title)!"
        }
        
        content.sound = .default

        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: reminder.time)
        let minute = calendar.component(.minute, from: reminder.time)
        
        // Loop through the selected weekdays (1=Sun, 7=Sat)
        for weekday in reminder.weekdays {
            var components = DateComponents()
            components.hour = hour
            components.minute = minute
            components.weekday = weekday
            
            // Create a repeating trigger for this specific day
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            
            // Create a unique ID for this day
            let uniqueID = "\(reminder.notificationID)-\(weekday)"
            
            let request = UNNotificationRequest(
                identifier: uniqueID,
                content: content,
                trigger: trigger
            )
            
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("Error scheduling: \(error.localizedDescription)")
                }
            }
        }
        
        print("Scheduled \(reminder.title) for days: \(reminder.weekdays)")
    }
    
    /// Cancels all notifications associated with this reminder
    static func cancelReminder(_ reminder: Reminder) {
        var idsToCancel: [String] = []
        for i in 1...7 {
            idsToCancel.append("\(reminder.notificationID)-\(i)")
        }
        
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: idsToCancel)
        print("Canceled reminder: \(reminder.title)")
    }
}

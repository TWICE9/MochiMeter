// Models/Reminder.swift

import Foundation
import SwiftData

@Model
final class Reminder {
    @Attribute(.unique) var id: UUID
    var userId: String? = nil  // nil for offline users
    var title: String
    var notes: String // ⭐️ New: Extra details
    var time: Date
    var isEnabled: Bool
    
    // ⭐️ New: Which days to repeat? (1=Sun, 2=Mon, ... 7=Sat)
    // If empty, we assume it's a one-time reminder or daily (logic handled in view)
    var weekdays: [Int]
    
    var notificationID: String
    
    init(
        id: UUID = UUID(),
        title: String,
        notes: String = "",
        time: Date,
        isEnabled: Bool = true,
        weekdays: [Int] = [1,2,3,4,5,6,7] // Default to every day
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.time = time
        self.isEnabled = isEnabled
        self.weekdays = weekdays
        self.notificationID = UUID().uuidString
    }
}

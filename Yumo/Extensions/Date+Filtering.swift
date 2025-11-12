// Extensions/Date+Filtering.swift

import Foundation

extension Date {
    /// Returns the start of the current day.
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }
    
    /// Returns the end of the current day (1 millisecond before midnight tomorrow).
    var endOfDay: Date {
        let calendar = Calendar.current
        var components = DateComponents()
        components.day = 1
        components.second = -1
        
        // Add one day minus one second to the start of today
        return calendar.date(byAdding: components, to: self.startOfDay)!
    }
}

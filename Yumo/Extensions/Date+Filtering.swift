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

    /// Returns true if both dates fall in the same ISO 8601 week (Mon-first).
    func isInSameISOWeek(as other: Date) -> Bool {
        var cal = Calendar(identifier: .iso8601)
        cal.firstWeekday = 2
        let selfWeek = cal.dateInterval(of: .weekOfYear, for: self)?.start
        let otherWeek = cal.dateInterval(of: .weekOfYear, for: other)?.start
        return selfWeek == otherWeek
    }
}

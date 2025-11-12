//
//  FastingLog.swift
//  Yumo
//
//  Created by Apple on 8/11/2025.
//


// Models/FastingLog.swift

import Foundation
import SwiftData

@Model
final class FastingLog {
    @Attribute(.unique) var id: UUID
    var userId: String? = nil  // nil for offline users
    var startTime: Date
    var endTime: Date? // nil if the fast is currently active
    var goalHours: Double
    
    init(
        id: UUID = UUID(),
        startTime: Date = Date(),
        endTime: Date? = nil,
        goalHours: Double = 16 // Default to 16:8 schedule
    ) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.goalHours = goalHours
    }
    
    /// Calculated total duration of the fast (in seconds)
    var duration: TimeInterval {
        return (endTime ?? Date()).timeIntervalSince(startTime)
    }
    
    /// Calculated goal duration in seconds
    var goalDuration: TimeInterval {
        return goalHours * 3600 // 3600 seconds per hour
    }
}
//
//  LoggedFitness.swift
//  Yumo
//
//  Model for storing manual fitness entries (steps, calories burned)
//  Used to supplement HealthKit data for users with cross-platform fitness tracking

import Foundation
import SwiftData

@Model
final class LoggedFitness {
    @Attribute(.unique) var id: UUID
    var userId: String? = nil  // nil for offline users
    var date: Date  // Date component only (start of day)
    var steps: Int?  // Optional manual steps entry
    var caloriesBurned: Double?  // Optional active calories burned
    
    init(
        id: UUID = UUID(),
        date: Date = Date(),
        steps: Int? = nil,
        caloriesBurned: Double? = nil
    ) {
        self.id = id
        // Normalize to start of day to ensure one entry per day
        self.date = Calendar.current.startOfDay(for: date)
        self.steps = steps
        self.caloriesBurned = caloriesBurned
    }
}

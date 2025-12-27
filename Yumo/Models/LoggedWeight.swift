//
//  LoggedWeight.swift
//  Yumo
//
//  Model for storing user weight entries over time

import Foundation
import SwiftData

@Model
final class LoggedWeight {
    @Attribute(.unique) var id: UUID
    var userId: String? = nil  // nil for offline users
    var timestamp: Date
    var weightKg: Double {  // Weight stored in kilograms
        didSet { weightKg = InputValidation.capWeight(weightKg) }
    }
    var note: String?  // Optional note for context (e.g., "morning", "after workout")

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        weightKg: Double,
        note: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.weightKg = InputValidation.capWeight(weightKg)
        self.note = note
    }
}

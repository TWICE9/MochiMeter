//
//  ScanHistoryPayload.swift
//  Yumo
//
//  Created by Apple on 18/11/2025.
//


import Foundation

public struct ScanHistoryPayload: Codable, Sendable {
    public let barcode: String
    public let food_name: String
    public let calories: Double
    public let protein: Double
    public let carbs: Double
    public let fat: Double
    public let fiber: Double
    public let scanned_at: String

    public init(
        barcode: String,
        food_name: String,
        calories: Double,
        protein: Double,
        carbs: Double,
        fat: Double,
        fiber: Double,
        scanned_at: String
    ) {
        self.barcode = barcode
        self.food_name = food_name
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.fiber = fiber
        self.scanned_at = scanned_at
    }
}

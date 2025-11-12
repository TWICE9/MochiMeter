//
//  CloudFood.swift
//  Yumo
//

import SwiftData
import Foundation

@Model
final class CloudFood {

    // MARK: - Identity
    @Attribute(.unique) var barcode: String          // UPC / EAN
    var name: String                                 // Display name
    var scanCount: Int                               // Local scan frequency

    // MARK: - Macronutrients (per 100g)
    var calories: Double
    var protein: Double
    var carbs: Double
    var fat: Double
    var fiber: Double

    // MARK: - Micronutrients (per 100g)
    var sugar: Double
    var salt: Double
    var potassium: Double

    // MARK: - Metadata
    var updatedAt: Date                              // When Supabase says it's last updated
    var locallyCachedAt: Date                        // When SwiftData stored it

    // MARK: - Initializer
    init(
        barcode: String,
        name: String,
        scanCount: Int = 0,
        calories: Double,
        protein: Double,
        carbs: Double,
        fat: Double,
        fiber: Double,
        sugar: Double,
        salt: Double,
        potassium: Double,
        updatedAt: Date,
        locallyCachedAt: Date = Date()
    ) {
        self.barcode = barcode
        self.name = name
        self.scanCount = scanCount

        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.fiber = fiber

        self.sugar = sugar
        self.salt = salt
        self.potassium = potassium

        self.updatedAt = updatedAt
        self.locallyCachedAt = locallyCachedAt
    }
}


//
//  LoggedWater.swift
//  Yumo
//
//  Created by Apple on 8/11/2025.
//


// Models/LoggedWater.swift

import Foundation
import SwiftData

@Model
final class LoggedWater {
    @Attribute(.unique) var id: UUID
    var userId: String? = nil  // nil for offline users
    var timestamp: Date
    var amountML: Double { // Amount in milliliters
        didSet { amountML = InputValidation.capCupSize(amountML) }
    }

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        amountML: Double
    ) {
        self.id = id
        self.timestamp = timestamp
        self.amountML = InputValidation.capCupSize(amountML)
    }
}
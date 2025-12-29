//
//  ShoppingItem.swift
//  Yumo
//
//  Created by Apple on 15/11/2025.
//

import Foundation
import SwiftData

@Model
final class ShoppingItem {
    @Attribute(.unique) var id: UUID
    var userId: String? // Optional to support guest functionality if needed
    var name: String
    var isCompleted: Bool
    var createdAt: Date
    
    init(id: UUID = UUID(), userId: String? = nil, name: String, isCompleted: Bool = false, createdAt: Date = Date()) {
        self.id = id
        self.userId = userId
        self.name = name
        self.isCompleted = isCompleted
        self.createdAt = createdAt
    }
}
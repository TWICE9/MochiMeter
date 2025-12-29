//
//  ShoppingItemDTO.swift
//  Yumo
//
//  Created by Cloud Assistant on 2025-12-28.
//

import Foundation

struct ShoppingItemDTO: Sendable, Codable {
    let id: UUID
    let user_id: UUID
    let name: String
    let is_completed: Bool
    let created_at: String
}

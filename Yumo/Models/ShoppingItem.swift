//
//  for.swift
//  Yumo
//
//  Created by Apple on 15/11/2025.
//


import Foundation

// A simple, identifiable struct for our list items
struct ShoppingItem: Identifiable, Codable {
    let id: UUID
    var name: String
    var isCompleted: Bool

    init(id: UUID = UUID(), name: String, isCompleted: Bool = false) {
        self.id = id
        self.name = name
        self.isCompleted = isCompleted
    }
}
//
//  holds.swift
//  Yumo
//
//  Created by Apple on 15/11/2025.
//


import Foundation
import Combine
import SwiftUI
// This class holds all the logic for the shopping list
@MainActor
class ShoppingListViewModel: ObservableObject {
    
    @Published var items: [ShoppingItem] = []
    @Published var newItemName: String = ""

    // Add a new item to the list
    func addItem() {
        guard !newItemName.isEmpty else { return } // Don't add empty items
        let newItem = ShoppingItem(name: newItemName)
        items.append(newItem)
        newItemName = "" // Clear the text field
    }
    
    // Toggle the 'completed' status of an item
    func toggleCompletion(for item: ShoppingItem) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index].isCompleted.toggle()
        }
    }
    
    // Delete items from the list
    func deleteItems(at offsets: IndexSet) {
        items.remove(atOffsets: offsets)
    }
}

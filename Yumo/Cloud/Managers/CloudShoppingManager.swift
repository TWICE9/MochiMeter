//
//  CloudShoppingManager.swift
//  Yumo
//
//  Created by Cloud Assistant on 2025-12-28.
//

import Foundation
@preconcurrency import Supabase



actor CloudShoppingManager {
    static let shared = CloudShoppingManager()
    private init() {}
    
    // MARK: - Date Helpers
    
    nonisolated func parseDate(_ string: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: string) { return date }
        
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string) ?? Date()
    }
    
    nonisolated func formatDate(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
    
    // MARK: - Remote Operations
    
    func fetchShoppingItems(userId: String) async throws -> [ShoppingItemDTO] {
        guard let userUUID = UUID(uuidString: userId) else { return [] }
        
        let response = try await supabase.database
            .from("shopping_items")
            .select()
            .eq("user_id", value: userUUID)
            .execute()
        
        let decoder = JSONDecoder()
        let dtos = try decoder.decode([ShoppingItemDTO].self, from: response.data)
        return dtos
    }
    
    
    nonisolated func upsert(id: UUID, userId: String, name: String, isCompleted: Bool, createdAt: Date) async {
        guard let userUUID = UUID(uuidString: userId) else { return }
        
        let dateString = formatDate(createdAt)
        
        // Local struct to avoid actor isolation issues
        struct UploadPayload: Encodable {
            let id: UUID
            let user_id: UUID
            let name: String
            let is_completed: Bool
            let created_at: String
        }
        
        let payload = UploadPayload(
            id: id,
            user_id: userUUID,
            name: name,
            is_completed: isCompleted,
            created_at: dateString
        )
        
        do {
            try await supabase.database
                .from("shopping_items")
                .upsert(payload)
                .execute()
            print("☁️ Uploaded shopping item: \(name)")
        } catch {
            print("❌ Error uploading shopping item: \(error.localizedDescription)")
        }
    }
    
    nonisolated func delete(id: UUID) async {
        do {
            try await supabase.database
                .from("shopping_items")
                .delete()
                .eq("id", value: id)
                .execute()
             print("🗑️ Deleted shopping item from cloud")
        } catch {
            print("❌ Error deleting shopping item: \(error.localizedDescription)")
        }
    }
}

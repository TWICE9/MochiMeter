//
//  PendingAnalysisManager.swift
//  Yumo
//
//  Manages background-safe AI food analysis that can complete even if the app closes
//

import Foundation
import UIKit
@preconcurrency import Supabase

/// Manages pending AI analyses that survive app closure
actor PendingAnalysisManager {
    static let shared = PendingAnalysisManager()
    
    private let storageBucket = "food-images"
    
    private init() {}
    
    // MARK: - Submit Analysis (Fire and Forget)
    
    /// Submits an image for background analysis. Returns immediately after upload.
    /// - Parameters:
    ///   - image: The food image to analyze
    ///   - localFoodId: The local LoggedFood UUID string (to match results later)
    ///   - userId: The user's ID
    /// - Returns: The pending analysis ID
    func submitForAnalysis(image: UIImage, localFoodId: String, userId: String) async throws -> String {
        // 1. Resize and compress image
        let resizedImage = image.resized(toMaxDimension: 1024)
        guard let imageData = resizedImage.jpegData(compressionQuality: 0.80) else {
            throw PendingAnalysisError.imageProcessingFailed
        }
        
        // 2. Generate unique filename
        let filename = "\(userId)/\(UUID().uuidString).jpg"
        
        // 3. Upload to Supabase Storage
        do {
            try await supabase.storage
                .from(storageBucket)
                .upload(
                    path: filename,
                    file: imageData,
                    options: FileOptions(contentType: "image/jpeg")
                )
            print("📤 Image uploaded to storage: \(filename)")
        } catch {
            print("❌ Failed to upload image: \(error)")
            throw PendingAnalysisError.uploadFailed(error.localizedDescription)
        }
        
        // 4. Create pending analysis record
        struct PendingAnalysisRecord: Codable {
            let id: String
            let user_id: String
            let image_path: String
            let status: String
            let created_at: String
            let local_food_id: String?
        }
        
        let analysisId = UUID().uuidString
        let record = PendingAnalysisRecord(
            id: analysisId,
            user_id: userId,
            image_path: filename,
            status: "pending",
            created_at: ISO8601DateFormatter().string(from: Date()),
            local_food_id: localFoodId
        )
        
        do {
            try await supabase.database
                .from("pending_analyses")
                .insert(record)
                .execute()
            print("📝 Pending analysis record created: \(analysisId)")
        } catch {
            print("❌ Failed to create pending analysis: \(error)")
            throw PendingAnalysisError.databaseError(error.localizedDescription)
        }
        
        // 5. Trigger edge function (fire and forget - we don't wait for response)
        Task {
            await triggerAnalysis(analysisId: analysisId, imagePath: filename)
        }
        
        return analysisId
    }
    
    /// Triggers the edge function to process the analysis (fire and forget)
    private func triggerAnalysis(analysisId: String, imagePath: String) async {
        do {
            let requestBody: [String: Any] = [
                "analysisId": analysisId,
                "imagePath": imagePath,
                "mode": "background"  // Signal to edge function to write to DB
            ]
            
            guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
                print("❌ Failed to serialize trigger request")
                return
            }
            
            // Call the edge function - we don't wait for the full response
            _ = try await supabase.functions.invoke(
                "analyze-food",
                options: FunctionInvokeOptions(body: jsonData)
            )
            
            print("🚀 Analysis triggered for: \(analysisId)")
        } catch {
            // Don't worry if this fails - the edge function might still complete
            print("⚠️ Trigger request failed (analysis may still complete): \(error)")
        }
    }
    
    // MARK: - Sync Completed Analyses
    
    /// Fetches completed analyses that need to be synced to local database
    func fetchCompletedAnalyses(for userId: String) async throws -> [CompletedAnalysis] {
        let response = try await supabase.database
            .from("pending_analyses")
            .select()
            .eq("user_id", value: userId)
            .eq("status", value: "completed")
            .order("completed_at", ascending: false)
            .execute()
        
        let decoder = JSONDecoder()
        let rows = try decoder.decode([CompletedAnalysisRow].self, from: response.data)
        
        return rows.map { row in
            CompletedAnalysis(
                id: row.id,
                localFoodId: row.local_food_id,
                result: row.result,
                completedAt: row.completed_at
            )
        }
    }
    
    /// Marks an analysis as synced (no longer pending)
    func markAsSynced(analysisId: String) async throws {
        try await supabase.database
            .from("pending_analyses")
            .update(["status": "synced"])
            .eq("id", value: analysisId)
            .execute()
        
        print("✅ Analysis marked as synced: \(analysisId)")
    }
    
    /// Fetches failed analyses for potential retry or user notification
    func fetchFailedAnalyses(for userId: String) async throws -> [FailedAnalysis] {
        let response = try await supabase.database
            .from("pending_analyses")
            .select()
            .eq("user_id", value: userId)
            .eq("status", value: "failed")
            .execute()
        
        let decoder = JSONDecoder()
        let rows = try decoder.decode([FailedAnalysisRow].self, from: response.data)
        
        return rows.map { row in
            FailedAnalysis(
                id: row.id,
                localFoodId: row.local_food_id,
                errorMessage: row.error_message,
                createdAt: row.created_at
            )
        }
    }
    
    /// Deletes a failed analysis and its image
    func deleteFailedAnalysis(analysisId: String, imagePath: String) async throws {
        // Delete from storage
        do {
            _ = try await supabase.storage
                .from(storageBucket)
                .remove(paths: [imagePath])
        } catch {
            print("⚠️ Failed to delete image from storage: \(error)")
        }
        
        // Delete from database
        try await supabase.database
            .from("pending_analyses")
            .delete()
            .eq("id", value: analysisId)
            .execute()
    }
}

// MARK: - Data Models

struct CompletedAnalysisRow: Codable, Sendable {
    let id: String
    let local_food_id: String?
    let result: AnalysisResultJSON?
    let completed_at: String?
}

struct AnalysisResultJSON: Codable, Sendable {
    let name: String
    let servingSize: String
    let calories: Double
    let protein: Double
    let carbs: Double
    let fat: Double
    let fiber: Double
    let sugar: Double
    let salt: Double?
    let potassium: Double?
    let confidence: String?
    let ingredients: [String]?
    let ingredientBreakdown: [IngredientBreakdownJSON]?
}

struct IngredientBreakdownJSON: Codable, Sendable {
    let name: String
    let calories: Double
}

struct CompletedAnalysis: Sendable {
    let id: String
    let localFoodId: String?
    let result: AnalysisResultJSON?
    let completedAt: String?
}

struct FailedAnalysisRow: Codable, Sendable {
    let id: String
    let local_food_id: String?
    let error_message: String?
    let created_at: String
}

struct FailedAnalysis: Sendable {
    let id: String
    let localFoodId: String?
    let errorMessage: String?
    let createdAt: String
}

// MARK: - Errors

enum PendingAnalysisError: Error, LocalizedError {
    case imageProcessingFailed
    case uploadFailed(String)
    case databaseError(String)
    case analysisNotFound
    
    var errorDescription: String? {
        switch self {
        case .imageProcessingFailed:
            return "Failed to process image for upload"
        case .uploadFailed(let message):
            return "Failed to upload image: \(message)"
        case .databaseError(let message):
            return "Database error: \(message)"
        case .analysisNotFound:
            return "Analysis not found"
        }
    }
}

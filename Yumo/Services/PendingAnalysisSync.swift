//
//  PendingAnalysisSync.swift
//  Yumo
//
//  Syncs completed background analyses to local database on app launch
//

import Foundation
import SwiftData
import UIKit

/// Syncs completed pending analyses to local database
@MainActor
class PendingAnalysisSync {
    static let shared = PendingAnalysisSync()
    
    private var isSyncing = false
    
    private init() {}
    
    /// Call this on app launch to sync any completed background analyses
    func syncCompletedAnalyses(modelContext: ModelContext) async {
        guard !isSyncing else {
            print("⏳ Sync already in progress, skipping")
            return
        }
        
        isSyncing = true
        defer { isSyncing = false }
        
        guard let userId = await UserSession.shared.getCurrentUserId() else {
            print("ℹ️ No user logged in, skipping pending analysis sync")
            return
        }
        
        print("🔄 Checking for completed background analyses...")
        
        do {
            // 1. Fetch completed analyses from Supabase
            let completedAnalyses = try await PendingAnalysisManager.shared.fetchCompletedAnalyses(for: userId)
            
            if completedAnalyses.isEmpty {
                print("✅ No pending analyses to sync")
                return
            }
            
            print("📥 Found \(completedAnalyses.count) completed analyses to sync")
            
            // 2. For each completed analysis, update the local LoggedFood
            for analysis in completedAnalyses {
                await syncSingleAnalysis(analysis, modelContext: modelContext)
            }
            
            // 3. Also check for failed analyses
            let failedAnalyses = try await PendingAnalysisManager.shared.fetchFailedAnalyses(for: userId)
            if !failedAnalyses.isEmpty {
                print("⚠️ Found \(failedAnalyses.count) failed analyses")
                await handleFailedAnalyses(failedAnalyses, modelContext: modelContext)
            }
            
            // Notify UI to refresh
            NotificationCenter.default.post(name: Notification.Name("FoodLogCreated"), object: nil)
            
        } catch {
            print("❌ Failed to sync pending analyses: \(error)")
        }
    }
    
    private func syncSingleAnalysis(_ analysis: CompletedAnalysis, modelContext: ModelContext) async {
        guard let localFoodIdString = analysis.localFoodId,
              let result = analysis.result else {
            print("⚠️ Analysis \(analysis.id) missing localFoodId or result")
            return
        }
        
        // Find the local LoggedFood by its UUID string stored in the analyzing flag
        // We'll need to fetch by a custom query since we stored the ID as a string
        do {
            // Fetch all foods that are still analyzing
            let descriptor = FetchDescriptor<LoggedFood>(
                predicate: #Predicate<LoggedFood> { food in
                    food.isAnalyzing == true
                }
            )
            
            let analyzingFoods = try modelContext.fetch(descriptor)
            
            // Find the one with matching ID (we stored UUID string)
            // Since we can't directly query by persistentModelID, we'll match by creation time or other fields
            // For now, let's update the most recent analyzing food if IDs match
            
            guard let targetFood = analyzingFoods.first(where: { food in
                // Match by the ID we stored
                food.persistentModelID.hashValue.description == localFoodIdString ||
                food.id.uuidString == localFoodIdString
            }) ?? analyzingFoods.first else {
                print("⚠️ Could not find local food for analysis \(analysis.id)")
                // Still mark as synced to avoid re-processing
                try? await PendingAnalysisManager.shared.markAsSynced(analysisId: analysis.id)
                return
            }
            
            // Update the food with analysis results
            targetFood.name = result.name
            targetFood.servingSizeDescription = result.servingSize
            targetFood.caloriesPerServing = result.calories
            targetFood.proteinPerServing = result.protein
            targetFood.carbsPerServing = result.carbs
            targetFood.fatPerServing = result.fat
            targetFood.fiberPerServing = result.fiber
            targetFood.sugarPerServing = result.sugar
            targetFood.brand = "AI Analyzed"
            targetFood.aiConfidence = result.confidence
            targetFood.isAnalyzing = false
            
            // Handle ingredient breakdown
            if let ingredients = result.ingredients {
                targetFood.aiIngredients = ingredients
            }
            
            if let breakdown = result.ingredientBreakdown {
                var caloriesDict: [String: Double] = [:]
                for item in breakdown {
                    caloriesDict[item.name] = item.calories
                }
                targetFood.aiIngredientCalories = caloriesDict
            }
            
            try modelContext.save()
            
            // Mark as synced in Supabase
            try await PendingAnalysisManager.shared.markAsSynced(analysisId: analysis.id)
            
            print("✅ Synced analysis for: \(result.name)")
            
            // Haptic feedback
            await MainActor.run {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
            
        } catch {
            print("❌ Failed to sync analysis \(analysis.id): \(error)")
        }
    }
    
    private func handleFailedAnalyses(_ failedAnalyses: [FailedAnalysis], modelContext: ModelContext) async {
        for failed in failedAnalyses {
            guard let localFoodIdString = failed.localFoodId else { continue }
            
            do {
                // Find and update the local food to show failure
                let descriptor = FetchDescriptor<LoggedFood>(
                    predicate: #Predicate<LoggedFood> { food in
                        food.isAnalyzing == true
                    }
                )
                
                let analyzingFoods = try modelContext.fetch(descriptor)
                
                if let targetFood = analyzingFoods.first(where: { food in
                    food.persistentModelID.hashValue.description == localFoodIdString ||
                    food.id.uuidString == localFoodIdString
                }) {
                    targetFood.name = "Analysis failed"
                    targetFood.isAnalyzing = false
                    try modelContext.save()
                }
                
            } catch {
                print("❌ Failed to handle failed analysis: \(error)")
            }
        }
    }
}

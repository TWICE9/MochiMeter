//
//  PendingAnalysisSync.swift
//  Yumo
//
//  Syncs completed background analyses to local database on app launch
//  Also provides smart polling for quick updates while app is active
//

import Foundation
import SwiftData
import UIKit
@preconcurrency import Supabase

/// Syncs completed pending analyses to local database
@MainActor
class PendingAnalysisSync {
    static let shared = PendingAnalysisSync()
    
    private var isSyncing = false
    private var pollingTask: Task<Void, Never>?
    private var isPolling = false
    private weak var modelContext: ModelContext?
    
    /// Polling intervals - fast when analyzing, slow when idle
    private let fastPollingInterval: TimeInterval = 1.0  // 1 second when items are analyzing
    private let slowPollingInterval: TimeInterval = 10.0 // 10 seconds when idle

    /// Stuck analysis recovery settings
    private let stuckRetryTimeout: TimeInterval = 60    // Retry after 1 minute stuck
    private let stuckGiveUpTimeout: TimeInterval = 180  // Give up after 3 minutes
    
    private init() {}
    
    // MARK: - Smart Polling
    
    /// Start smart polling for completed analyses
    /// Polls fast (1s) when there are pending analyses, slow (10s) when idle
    func startListening(modelContext: ModelContext) async {
        guard !isPolling else { return }
        
        guard await UserSession.shared.getCurrentUserId() != nil else {
            print("ℹ️ No user logged in, skipping analysis polling")
            return
        }
        
        self.modelContext = modelContext
        isPolling = true
        
        print("📡 Starting smart polling for pending analyses...")
        
        // Create a polling task with adaptive interval
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self = self, self.isPolling, let context = self.modelContext else { break }
                
                // Check if there are any items currently analyzing
                let hasAnalyzingItems = self.hasAnalyzingItems(in: context)
                
                // Use fast polling when analyzing, slow when idle
                let interval = hasAnalyzingItems ? self.fastPollingInterval : self.slowPollingInterval
                
                if hasAnalyzingItems {
                    // Only log when actively polling
                    // Check for completed analyses
                    await self.syncCompletedAnalyses(modelContext: context)
                }
                
                // Wait before next poll (adaptive interval)
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            }
            
            print("📡 Polling stopped")
        }
        
        print("✅ Smart analysis polling active (fast: \(fastPollingInterval)s, slow: \(slowPollingInterval)s)")
    }
    
    /// Check if there are any items currently being analyzed
    private func hasAnalyzingItems(in context: ModelContext) -> Bool {
        do {
            let descriptor = FetchDescriptor<LoggedFood>(
                predicate: #Predicate<LoggedFood> { food in
                    food.isAnalyzing == true
                }
            )
            let count = try context.fetchCount(descriptor)
            return count > 0
        } catch {
            return false
        }
    }
    
    /// Stop polling for updates
    /// Call this when the app goes to background or the user logs out
    func stopListening() async {
        guard isPolling else { return }
        
        print("📡 Stopping analysis polling...")
        
        isPolling = false
        pollingTask?.cancel()
        pollingTask = nil
        modelContext = nil
        
        print("✅ Analysis polling stopped")
    }
    
    // MARK: - Manual Sync
    
    /// Call this on app launch to sync any completed background analyses
    func syncCompletedAnalyses(modelContext: ModelContext) async {
        guard !isSyncing else {
            return // Skip silently to avoid log noise
        }
        
        isSyncing = true
        defer { isSyncing = false }
        
        guard let userId = await UserSession.shared.getCurrentUserId() else {
            return // Skip silently during polling
        }
        
        do {
            var syncedCount = 0
            var failedCount = 0

            // 1. Fetch and sync completed analyses from Supabase
            let completedAnalyses = try await PendingAnalysisManager.shared.fetchCompletedAnalyses(for: userId)
            if !completedAnalyses.isEmpty {
                print("📥 Found \(completedAnalyses.count) completed analyses to sync")
                for analysis in completedAnalyses {
                    await syncSingleAnalysis(analysis, modelContext: modelContext)
                    syncedCount += 1
                }
            }

            // 2. Check for stuck pending analyses and retry or fail them
            let stuckAnalyses = try await PendingAnalysisManager.shared.fetchStuckAnalyses(for: userId, retryTimeout: stuckRetryTimeout, giveUpTimeout: stuckGiveUpTimeout)
            if !stuckAnalyses.isEmpty {
                print("⏰ Found \(stuckAnalyses.count) stuck analyses")
                await handleStuckAnalyses(stuckAnalyses, modelContext: modelContext)
            }

            // 3. Check for failed analyses
            let failedAnalyses = try await PendingAnalysisManager.shared.fetchFailedAnalyses(for: userId)
            if !failedAnalyses.isEmpty {
                print("⚠️ Found \(failedAnalyses.count) failed analyses")
                await handleFailedAnalyses(failedAnalyses, modelContext: modelContext)
                failedCount = failedAnalyses.count
            }

            // Only notify the UI if something actually changed.
            // Posting this notification unconditionally was causing the home screen
            // to re-render (and reset scroll position) on every launch even with no new data.
            if syncedCount > 0 || failedCount > 0 {
                NotificationCenter.default.post(name: Notification.Name("FoodLogCreated"), object: nil)
            }

        } catch {
            // Suppress error logs during polling to avoid noise
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
            
        } catch {
            print("❌ Failed to sync analysis \(analysis.id): \(error)")
        }
    }
    
    // MARK: - Stuck Analysis Recovery

    private func handleStuckAnalyses(_ stuckAnalyses: [StuckAnalysis], modelContext: ModelContext) async {
        for stuck in stuckAnalyses {
            if !stuck.shouldGiveUp {
                // Still within retry window — re-trigger the edge function
                await PendingAnalysisManager.shared.retryAnalysis(
                    analysisId: stuck.id,
                    imagePath: stuck.imagePath
                )
            } else {
                // Past give-up timeout — mark as failed
                do {
                    try await PendingAnalysisManager.shared.markAsFailed(
                        analysisId: stuck.id,
                        reason: "Analysis timed out"
                    )
                } catch {
                    print("❌ Failed to mark analysis as failed: \(error)")
                }

                // Update the local food item to show failure
                guard let localFoodIdString = stuck.localFoodId else { continue }
                do {
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
                        targetFood.isAnalysisFailed = true
                        try modelContext.save()
                    }
                } catch {
                    print("❌ Failed to update local food for stuck analysis: \(error)")
                }
            }
        }
    }

    private func handleFailedAnalyses(_ failedAnalyses: [FailedAnalysis], modelContext: ModelContext) async {
        for failed in failedAnalyses {
            guard let localFoodIdString = failed.localFoodId else {
                // Orphaned failed row with no local food — consume it so it isn't re-fetched forever.
                try? await PendingAnalysisManager.shared.markAsSynced(analysisId: failed.id)
                continue
            }

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
                    targetFood.isAnalysisFailed = true
                    try modelContext.save()
                }

                // Consume the row once the failure is reflected locally. Leaving it as
                // `failed` lets it be re-applied on top of a later retry of the same food
                // (and re-fetched on every poll), which is exactly what stuck the card on
                // "Analysis failed" after topping up credits.
                try? await PendingAnalysisManager.shared.markAsSynced(analysisId: failed.id)

            } catch {
                print("❌ Failed to handle failed analysis: \(error)")
            }
        }
    }

}

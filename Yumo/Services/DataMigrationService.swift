// Services/DataMigrationService.swift

import Foundation
import SwiftData

/// Service responsible for migrating offline data to a signed-in user
actor DataMigrationService {

    static let shared = DataMigrationService()
    private init() {}

    /// Migrates all offline data (userId == nil) to the specified userId
    /// This should be called when a user signs in for the first time
    func migrateOfflineDataToUser(userId: String, context: ModelContext) async {
        print("🔄 Starting data migration for userId: \(userId)")

        // Migrate LoggedFood
        await migrateLoggedFood(to: userId, context: context)

        // Migrate LoggedWater
        await migrateLoggedWater(to: userId, context: context)

        // Migrate UserGoals
        await migrateUserGoals(to: userId, context: context)

        // Migrate FastingLog
        await migrateFastingLog(to: userId, context: context)

        // Migrate Recipe
        await migrateRecipe(to: userId, context: context)

        // Migrate Reminder
        await migrateReminder(to: userId, context: context)

        // Save all changes
        try? context.save()

        print("✅ Data migration complete for userId: \(userId)")
    }

    // MARK: - Individual Migration Functions

    private func migrateLoggedFood(to userId: String, context: ModelContext) async {
        let predicate = #Predicate<LoggedFood> { $0.userId == nil }
        let descriptor = FetchDescriptor<LoggedFood>(predicate: predicate)

        guard let offlineItems = try? context.fetch(descriptor) else { return }

        print("📦 Migrating \(offlineItems.count) LoggedFood items...")
        for item in offlineItems {
            item.userId = userId
        }
    }

    private func migrateLoggedWater(to userId: String, context: ModelContext) async {
        let predicate = #Predicate<LoggedWater> { $0.userId == nil }
        let descriptor = FetchDescriptor<LoggedWater>(predicate: predicate)

        guard let offlineItems = try? context.fetch(descriptor) else { return }

        print("💧 Migrating \(offlineItems.count) LoggedWater items...")
        for item in offlineItems {
            item.userId = userId
        }
    }

    private func migrateUserGoals(to userId: String, context: ModelContext) async {
        let predicate = #Predicate<UserGoals> { $0.userId == nil }
        let descriptor = FetchDescriptor<UserGoals>(predicate: predicate)

        guard let offlineItems = try? context.fetch(descriptor) else { return }

        print("🎯 Migrating \(offlineItems.count) UserGoals items...")
        for item in offlineItems {
            item.userId = userId
        }
    }

    private func migrateFastingLog(to userId: String, context: ModelContext) async {
        let predicate = #Predicate<FastingLog> { $0.userId == nil }
        let descriptor = FetchDescriptor<FastingLog>(predicate: predicate)

        guard let offlineItems = try? context.fetch(descriptor) else { return }

        print("⏱️ Migrating \(offlineItems.count) FastingLog items...")
        for item in offlineItems {
            item.userId = userId
        }
    }

    private func migrateRecipe(to userId: String, context: ModelContext) async {
        let predicate = #Predicate<Recipe> { $0.userId == nil }
        let descriptor = FetchDescriptor<Recipe>(predicate: predicate)

        guard let offlineItems = try? context.fetch(descriptor) else { return }

        print("📖 Migrating \(offlineItems.count) Recipe items...")
        for item in offlineItems {
            item.userId = userId

            // Also migrate all ingredients in the recipe
            if let ingredients = item.ingredients {
                for ingredient in ingredients {
                    ingredient.userId = userId
                }
            }
        }
    }

    private func migrateReminder(to userId: String, context: ModelContext) async {
        let predicate = #Predicate<Reminder> { $0.userId == nil }
        let descriptor = FetchDescriptor<Reminder>(predicate: predicate)

        guard let offlineItems = try? context.fetch(descriptor) else { return }

        print("⏰ Migrating \(offlineItems.count) Reminder items...")
        for item in offlineItems {
            item.userId = userId
        }
    }

    /// Checks if there is any offline data that needs migration
    func hasOfflineData(context: ModelContext) async -> Bool {
        // Check LoggedFood
        let foodPredicate = #Predicate<LoggedFood> { $0.userId == nil }
        let foodDescriptor = FetchDescriptor<LoggedFood>(predicate: foodPredicate)
        if let foodCount = try? context.fetchCount(foodDescriptor), foodCount > 0 {
            return true
        }

        // Check LoggedWater
        let waterPredicate = #Predicate<LoggedWater> { $0.userId == nil }
        let waterDescriptor = FetchDescriptor<LoggedWater>(predicate: waterPredicate)
        if let waterCount = try? context.fetchCount(waterDescriptor), waterCount > 0 {
            return true
        }

        // Check UserGoals
        let goalsPredicate = #Predicate<UserGoals> { $0.userId == nil }
        let goalsDescriptor = FetchDescriptor<UserGoals>(predicate: goalsPredicate)
        if let goalsCount = try? context.fetchCount(goalsDescriptor), goalsCount > 0 {
            return true
        }

        // Check FastingLog
        let fastingPredicate = #Predicate<FastingLog> { $0.userId == nil }
        let fastingDescriptor = FetchDescriptor<FastingLog>(predicate: fastingPredicate)
        if let fastingCount = try? context.fetchCount(fastingDescriptor), fastingCount > 0 {
            return true
        }

        // Check Recipe
        let recipePredicate = #Predicate<Recipe> { $0.userId == nil }
        let recipeDescriptor = FetchDescriptor<Recipe>(predicate: recipePredicate)
        if let recipeCount = try? context.fetchCount(recipeDescriptor), recipeCount > 0 {
            return true
        }

        // Check Reminder
        let reminderPredicate = #Predicate<Reminder> { $0.userId == nil }
        let reminderDescriptor = FetchDescriptor<Reminder>(predicate: reminderPredicate)
        if let reminderCount = try? context.fetchCount(reminderDescriptor), reminderCount > 0 {
            return true
        }

        return false
    }
}

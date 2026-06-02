// Cloud/CloudSyncManager.swift

import Foundation
import SwiftData
import Supabase

enum CloudSyncStep: CaseIterable {
    case foodLogs
    case waterLogs
    case weightLogs
    case fitnessLogs
    case fastingLogs
    case recipes
    case reminders
    case userGoals
    case runningProfile
    case runningPlans
    case complete

    var label: String {
        switch self {
        case .foodLogs: return "Food logs synced"
        case .waterLogs: return "Water logs synced"
        case .weightLogs: return "Weight logs synced"
        case .fitnessLogs: return "Fitness logs synced"
        case .fastingLogs: return "Fasting logs synced"
        case .recipes: return "Recipes synced"
        case .reminders: return "Reminders synced"
        case .userGoals: return "Goals synced"
        case .runningProfile: return "Running profile synced"
        case .runningPlans: return "Running plans synced"
        case .complete: return "Full sync complete"
        }
    }
}

/// Manages bidirectional sync between local SwiftData and Supabase cloud
actor CloudSyncManager {

    static let shared = CloudSyncManager()
    private init() {}

    private let supabaseClient = supabase

    // MARK: - Full Sync

    /// Performs full bidirectional sync for all data types
    /// Call this on app launch when user is signed in
    func performFullSync(
        userId: String,
        context: ModelContext,
        progressHandler: (@Sendable (CloudSyncStep) async -> Void)? = nil
    ) async {
        print("🔄 Starting full sync for user: \(userId)")

        // IMPORTANT: Sync recipes FIRST, because food logs may reference recipes as ingredients
        // This ensures recipes exist before we try to link food logs to them
        await self.syncRecipes(userId: userId, context: context)
        await progressHandler?(.recipes)

        // Now run remaining syncs in parallel for faster performance
        await withTaskGroup(of: CloudSyncStep.self) { group in
            group.addTask {
                await self.syncFoodLogs(userId: userId, context: context)
                return .foodLogs
            }
            group.addTask {
                await self.syncWaterLogs(userId: userId, context: context)
                return .waterLogs
            }
            group.addTask {
                await self.syncWeightLogs(userId: userId, context: context)
                return .weightLogs
            }
            group.addTask {
                await self.syncFitnessLogs(userId: userId, context: context)
                return .fitnessLogs
            }
            group.addTask {
                await self.syncFastingLogs(userId: userId, context: context)
                return .fastingLogs
            }
            group.addTask {
                await self.syncReminders(userId: userId, context: context)
                return .reminders
            }
            group.addTask {
                await self.syncUserGoals(userId: userId, context: context)
                return .userGoals
            }
            group.addTask {
                await self.syncRunningProfile(userId: userId, context: context)
                return .runningProfile
            }
            group.addTask {
                await self.syncRunningPlans(userId: userId, context: context)
                return .runningPlans
            }

            // Report progress as each sync completes
            for await completedStep in group {
                await progressHandler?(completedStep)
            }
        }

        print("✅ Full sync complete")
        await progressHandler?(.complete)
    }

    // MARK: - User Goals Sync (for performFullSync)

    @MainActor
    func syncUserGoals(userId: String, context: ModelContext) async {
        // Fetch local user goals
        let localGoals = await UserScopedQuery.fetchUserGoals(context: context)

        // If we have local goals, upload them to the cloud
        if let goals = localGoals {
            await uploadUserGoalsImmediately(goals, userId: userId)
        }

        print("✅ User goals synced")
    }

    // MARK: - Food Logs Sync

    func syncFoodLogs(userId: String, context: ModelContext) async {
        do {
            // 1. Fetch local food logs for this user
            let localPredicate = #Predicate<LoggedFood> { $0.userId == userId }
            let localDescriptor = FetchDescriptor<LoggedFood>(predicate: localPredicate)
            let localLogs = (try? context.fetch(localDescriptor)) ?? []

            // 2. Fetch cloud food logs
            let cloudLogs: [CloudFoodLog] = try await supabaseClient.database
                .from("user_food_logs")
                .select()
                .eq("user_id", value: userId)
                .execute()
                .value

            // 3. Merge using last-write-wins
            for cloudLog in cloudLogs {
                if let localLog = localLogs.first(where: { $0.id.uuidString == cloudLog.id }) {
                    // Update local if cloud is newer
                    if cloudLog.updated_at > localLog.timestamp {
                        updateLocalFoodLog(local: localLog, from: cloudLog)
                    }
                } else {
                    // Create new local record
                    let newLog = createLocalFoodLog(from: cloudLog, userId: userId, context: context)
                    context.insert(newLog)
                }
            }

            // 4. Upload local logs that don't exist in cloud (BATCH for performance)
            var logsToUpload: [CloudFoodLog] = []
            for localLog in localLogs {
                let existsInCloud = cloudLogs.contains(where: { $0.id == localLog.id.uuidString })
                if !existsInCloud {
                    // Upload image first if available (can't batch images)
                    var imagePath: String? = localLog.cloudImagePath
                    if imagePath == nil, let photoData = localLog.photoData {
                        imagePath = await ImageStorageManager.shared.uploadImage(
                            imageData: photoData,
                            userId: userId,
                            logId: localLog.id.uuidString
                        )
                        if let path = imagePath {
                            localLog.cloudImagePath = path
                        }
                    }
                    
                    logsToUpload.append(CloudFoodLog(
                        id: localLog.id.uuidString,
                        user_id: userId,
                        name: localLog.name,
                        timestamp: localLog.timestamp,
                        serving_size_description: localLog.servingSizeDescription,
                        serving_amount: localLog.servingAmount,
                        calories_per_serving: localLog.caloriesPerServing,
                        protein_per_serving: localLog.proteinPerServing,
                        carbs_per_serving: localLog.carbsPerServing,
                        fat_per_serving: localLog.fatPerServing,
                        fiber_per_serving: localLog.fiberPerServing,
                        sugar_per_serving: localLog.sugarPerServing,
                        salt_per_serving: localLog.saltPerServing,
                        potassium_per_serving: localLog.potassiumPerServing,
                        barcode: localLog.barcode,
                        brand: localLog.brand,
                        is_halal: localLog.isHalal,
                        recipe_id: localLog.recipe?.id.uuidString,
                        image_path: imagePath,
                        updated_at: localLog.timestamp
                    ))
                }
            }
            
            // Batch upsert all food logs at once
            if !logsToUpload.isEmpty {
                try await supabaseClient.database.from("user_food_logs").upsert(logsToUpload).execute()
            }

            try? context.save()
            print("✅ Food logs synced")

        } catch {
            print("❌ Food logs sync failed: \(error)")
        }
    }

    @MainActor
    private func uploadFoodLog(_ log: LoggedFood, userId: String) async throws {
        // Upload image to storage if available
        var imagePath: String? = log.cloudImagePath
        if imagePath == nil, let photoData = log.photoData {
            imagePath = await ImageStorageManager.shared.uploadImage(
                imageData: photoData,
                userId: userId,
                logId: log.id.uuidString
            )
            // Update local log with cloud image path
            if let path = imagePath {
                log.cloudImagePath = path
            }
        }

        let cloudLog = CloudFoodLog(
            id: log.id.uuidString,
            user_id: userId,
            name: log.name,
            timestamp: log.timestamp,
            serving_size_description: log.servingSizeDescription,
            serving_amount: log.servingAmount,
            calories_per_serving: log.caloriesPerServing,
            protein_per_serving: log.proteinPerServing,
            carbs_per_serving: log.carbsPerServing,
            fat_per_serving: log.fatPerServing,
            fiber_per_serving: log.fiberPerServing,
            sugar_per_serving: log.sugarPerServing,
            salt_per_serving: log.saltPerServing,
            potassium_per_serving: log.potassiumPerServing,
            barcode: log.barcode,
            brand: log.brand,
            is_halal: log.isHalal,
            recipe_id: log.recipe?.id.uuidString,
            image_path: imagePath,
            updated_at: log.timestamp
        )

        try await supabaseClient.database
            .from("user_food_logs")
            .upsert(cloudLog)
            .execute()
    }

    /// Delete a food log from the cloud
    func deleteFoodLogFromCloud(logId: String, userId: String) async {
        do {
            try await supabaseClient.database
                .from("user_food_logs")
                .delete()
                .eq("id", value: logId)
                .eq("user_id", value: userId)
                .execute()

            print("☁️ Deleted food log from cloud: \(logId)")
        } catch {
            print("❌ Failed to delete food log from cloud: \(error)")
        }
    }

    /// Delete a water log from the cloud
    func deleteWaterLogFromCloud(logId: String, userId: String) async {
        do {
            try await supabaseClient.database
                .from("user_water_logs")
                .delete()
                .eq("id", value: logId)
                .eq("user_id", value: userId)
                .execute()

            print("☁️ Deleted water log from cloud: \(logId)")
        } catch {
            print("❌ Failed to delete water log from cloud: \(error)")
        }
    }

    /// Delete a fasting log from the cloud
    func deleteFastingLogFromCloud(logId: String, userId: String) async {
        do {
            try await supabaseClient.database
                .from("user_fasting_logs")
                .delete()
                .eq("id", value: logId)
                .eq("user_id", value: userId)
                .execute()

            print("☁️ Deleted fasting log from cloud: \(logId)")
        } catch {
            print("❌ Failed to delete fasting log from cloud: \(error)")
        }
    }

    /// Delete a recipe from the cloud
    func deleteRecipeFromCloud(recipeId: String, userId: String) async {
        do {
            try await supabaseClient.database
                .from("user_recipes")
                .delete()
                .eq("id", value: recipeId)
                .eq("user_id", value: userId)
                .execute()

            print("☁️ Deleted recipe from cloud: \(recipeId)")
        } catch {
            print("❌ Failed to delete recipe from cloud: \(error)")
        }
    }

    /// Delete a reminder from the cloud
    func deleteReminderFromCloud(reminderId: String, userId: String) async {
        do {
            try await supabaseClient.database
                .from("user_reminders")
                .delete()
                .eq("id", value: reminderId)
                .eq("user_id", value: userId)
                .execute()

            print("☁️ Deleted reminder from cloud: \(reminderId)")
        } catch {
            print("❌ Failed to delete reminder from cloud: \(error)")
        }
    }

    private func updateLocalFoodLog(local: LoggedFood, from cloud: CloudFoodLog) {
        local.name = cloud.name
        local.timestamp = cloud.timestamp
        local.servingSizeDescription = cloud.serving_size_description
        local.servingAmount = cloud.serving_amount
        local.caloriesPerServing = cloud.calories_per_serving
        local.proteinPerServing = cloud.protein_per_serving
        local.carbsPerServing = cloud.carbs_per_serving
        local.fatPerServing = cloud.fat_per_serving
        local.fiberPerServing = cloud.fiber_per_serving
        local.sugarPerServing = cloud.sugar_per_serving
        local.saltPerServing = cloud.salt_per_serving
        local.potassiumPerServing = cloud.potassium_per_serving
        local.barcode = cloud.barcode
        local.brand = cloud.brand
        local.isHalal = cloud.is_halal
        local.cloudImagePath = cloud.image_path  // Sync cloud image path
    }

    private func createLocalFoodLog(from cloud: CloudFoodLog, userId: String, context: ModelContext) -> LoggedFood {
        let log = LoggedFood(
            id: UUID(uuidString: cloud.id) ?? UUID(),
            name: cloud.name,
            timestamp: cloud.timestamp,
            servingSizeDescription: cloud.serving_size_description,
            servingAmount: cloud.serving_amount,
            caloriesPerServing: cloud.calories_per_serving,
            proteinPerServing: cloud.protein_per_serving,
            carbsPerServing: cloud.carbs_per_serving,
            fatPerServing: cloud.fat_per_serving,
            fiberPerServing: cloud.fiber_per_serving,
            sugarPerServing: cloud.sugar_per_serving,
            saltPerServing: cloud.salt_per_serving,
            potassiumPerServing: cloud.potassium_per_serving,
            barcode: cloud.barcode,
            brand: cloud.brand,
            isHalal: cloud.is_halal
        )
        log.userId = userId
        log.cloudImagePath = cloud.image_path  // Store cloud image path for later download
        
        // Link to recipe if this food log is a recipe ingredient
        if let recipeIdString = cloud.recipe_id,
           let recipeUUID = UUID(uuidString: recipeIdString) {
            // Look up the recipe in the local database
            let recipePredicate = #Predicate<Recipe> { $0.id == recipeUUID }
            if let recipe = try? context.fetch(FetchDescriptor(predicate: recipePredicate)).first {
                log.recipe = recipe
            }
        }
        
        return log
    }

    // MARK: - Water Logs Sync

    func syncWaterLogs(userId: String, context: ModelContext) async {
        do {
            let localPredicate = #Predicate<LoggedWater> { $0.userId == userId }
            let localDescriptor = FetchDescriptor<LoggedWater>(predicate: localPredicate)
            let localLogs = (try? context.fetch(localDescriptor)) ?? []

            let cloudLogs: [CloudWaterLog] = try await supabaseClient.database
                .from("user_water_logs")
                .select()
                .eq("user_id", value: userId)
                .execute()
                .value

            // Merge cloud → local
            for cloudLog in cloudLogs {
                if let localLog = localLogs.first(where: { $0.id.uuidString == cloudLog.id }) {
                    if cloudLog.updated_at > localLog.timestamp {
                        localLog.amountML = cloudLog.amount_ml
                        localLog.timestamp = cloudLog.timestamp
                    }
                } else {
                    let newLog = LoggedWater(
                        id: UUID(uuidString: cloudLog.id) ?? UUID(),
                        timestamp: cloudLog.timestamp,
                        amountML: cloudLog.amount_ml
                    )
                    newLog.userId = userId
                    context.insert(newLog)
                }
            }

            // Upload local → cloud (BATCH for performance)
            var logsToUpload: [CloudWaterLog] = []
            for localLog in localLogs {
                let existsInCloud = cloudLogs.contains(where: { $0.id == localLog.id.uuidString })
                if !existsInCloud {
                    logsToUpload.append(CloudWaterLog(
                        id: localLog.id.uuidString,
                        user_id: userId,
                        amount_ml: localLog.amountML,
                        timestamp: localLog.timestamp,
                        updated_at: localLog.timestamp
                    ))
                }
            }
            
            // Batch upsert all at once
            if !logsToUpload.isEmpty {
                try await supabaseClient.database.from("user_water_logs").upsert(logsToUpload).execute()
            }

            try? context.save()
            print("✅ Water logs synced")

        } catch {
            print("❌ Water logs sync failed: \(error)")
        }
    }

    // MARK: - Weight Logs Sync

    func syncWeightLogs(userId: String, context: ModelContext) async {
        do {
            let localPredicate = #Predicate<LoggedWeight> { $0.userId == userId }
            let localDescriptor = FetchDescriptor<LoggedWeight>(predicate: localPredicate)
            let localLogs = (try? context.fetch(localDescriptor)) ?? []

            let cloudLogs: [CloudWeightLog] = try await supabaseClient.database
                .from("user_weight_logs")
                .select()
                .eq("user_id", value: userId)
                .execute()
                .value

            // Merge cloud → local
            for cloudLog in cloudLogs {
                if let localLog = localLogs.first(where: { $0.id.uuidString == cloudLog.id }) {
                    if cloudLog.updated_at > localLog.timestamp {
                        localLog.weightKg = cloudLog.weight_kg
                        localLog.note = cloudLog.note
                        localLog.timestamp = cloudLog.timestamp
                    }
                } else {
                    let newLog = LoggedWeight(
                        id: UUID(uuidString: cloudLog.id) ?? UUID(),
                        timestamp: cloudLog.timestamp,
                        weightKg: cloudLog.weight_kg,
                        note: cloudLog.note
                    )
                    newLog.userId = userId
                    context.insert(newLog)
                }
            }

            // Upload local → cloud (BATCH for performance)
            var logsToUpload: [CloudWeightLog] = []
            for localLog in localLogs {
                let existsInCloud = cloudLogs.contains(where: { $0.id == localLog.id.uuidString })
                if !existsInCloud {
                    logsToUpload.append(CloudWeightLog(
                        id: localLog.id.uuidString,
                        user_id: userId,
                        weight_kg: localLog.weightKg,
                        note: localLog.note,
                        timestamp: localLog.timestamp,
                        updated_at: localLog.timestamp
                    ))
                }
            }
            
            // Batch upsert all at once
            if !logsToUpload.isEmpty {
                try await supabaseClient.database.from("user_weight_logs").upsert(logsToUpload).execute()
            }

            try? context.save()
            print("✅ Weight logs synced")

        } catch {
            print("❌ Weight logs sync failed: \(error)")
        }
    }

    // MARK: - Fasting Logs Sync

    func syncFastingLogs(userId: String, context: ModelContext) async {
        do {
            let localPredicate = #Predicate<FastingLog> { $0.userId == userId }
            let localDescriptor = FetchDescriptor<FastingLog>(predicate: localPredicate)
            let localLogs = (try? context.fetch(localDescriptor)) ?? []

            let cloudLogs: [CloudFastingLog] = try await supabaseClient.database
                .from("user_fasting_logs")
                .select()
                .eq("user_id", value: userId)
                .execute()
                .value

            // Merge cloud → local
            for cloudLog in cloudLogs {
                if let localLog = localLogs.first(where: { $0.id.uuidString == cloudLog.id }) {
                    if cloudLog.updated_at > localLog.startTime {
                        localLog.startTime = cloudLog.start_time
                        localLog.endTime = cloudLog.end_time
                        localLog.goalHours = cloudLog.goal_hours
                    }
                } else {
                    let newLog = FastingLog(
                        id: UUID(uuidString: cloudLog.id) ?? UUID(),
                        startTime: cloudLog.start_time,
                        endTime: cloudLog.end_time,
                        goalHours: cloudLog.goal_hours
                    )
                    newLog.userId = userId
                    context.insert(newLog)
                }
            }

            // Upload local → cloud (BATCH for performance)
            var logsToUpload: [CloudFastingLog] = []
            for localLog in localLogs {
                let existsInCloud = cloudLogs.contains(where: { $0.id == localLog.id.uuidString })
                if !existsInCloud {
                    logsToUpload.append(CloudFastingLog(
                        id: localLog.id.uuidString,
                        user_id: userId,
                        start_time: localLog.startTime,
                        end_time: localLog.endTime,
                        goal_hours: localLog.goalHours,
                        updated_at: localLog.endTime ?? localLog.startTime
                    ))
                }
            }
            
            // Batch upsert all at once
            if !logsToUpload.isEmpty {
                try await supabaseClient.database.from("user_fasting_logs").upsert(logsToUpload).execute()
            }

            try? context.save()
            print("✅ Fasting logs synced")

        } catch {
            print("❌ Fasting logs sync failed: \(error)")
        }
    }

    // MARK: - Recipes Sync

    func syncRecipes(userId: String, context: ModelContext) async {
        do {
            let localPredicate = #Predicate<Recipe> { $0.userId == userId }
            let localDescriptor = FetchDescriptor<Recipe>(predicate: localPredicate)
            let localRecipes = (try? context.fetch(localDescriptor)) ?? []

            let cloudRecipes: [CloudRecipe] = try await supabaseClient.database
                .from("user_recipes")
                .select()
                .eq("user_id", value: userId)
                .execute()
                .value

            // Merge cloud → local
            for cloudRecipe in cloudRecipes {
                if let localRecipe = localRecipes.first(where: { $0.id.uuidString == cloudRecipe.id }) {
                    if cloudRecipe.updated_at > Date() {
                        localRecipe.name = cloudRecipe.name
                        localRecipe.servings = cloudRecipe.servings
                    }
                } else {
                    let newRecipe = Recipe(
                        id: UUID(uuidString: cloudRecipe.id) ?? UUID(),
                        name: cloudRecipe.name,
                        servings: cloudRecipe.servings
                    )
                    newRecipe.userId = userId
                    context.insert(newRecipe)
                }
            }

            // Upload local → cloud (BATCH for performance)
            var recipesToUpload: [CloudRecipe] = []
            for localRecipe in localRecipes {
                let existsInCloud = cloudRecipes.contains(where: { $0.id == localRecipe.id.uuidString })
                if !existsInCloud {
                    recipesToUpload.append(CloudRecipe(
                        id: localRecipe.id.uuidString,
                        user_id: userId,
                        name: localRecipe.name,
                        servings: localRecipe.servings,
                        updated_at: Date()
                    ))
                }
            }
            
            // Batch upsert all at once
            if !recipesToUpload.isEmpty {
                try await supabaseClient.database.from("user_recipes").upsert(recipesToUpload).execute()
            }

            try? context.save()
            print("✅ Recipes synced")

        } catch {
            print("❌ Recipes sync failed: \(error)")
        }
    }

    // MARK: - Reminders Sync

    func syncReminders(userId: String, context: ModelContext) async {
        do {
            let localPredicate = #Predicate<Reminder> { $0.userId == userId }
            let localDescriptor = FetchDescriptor<Reminder>(predicate: localPredicate)
            let localReminders = (try? context.fetch(localDescriptor)) ?? []

            let cloudReminders: [CloudReminder] = try await supabaseClient.database
                .from("user_reminders")
                .select()
                .eq("user_id", value: userId)
                .execute()
                .value

            // Merge cloud → local
            for cloudReminder in cloudReminders {
                if let localReminder = localReminders.first(where: { $0.id.uuidString == cloudReminder.id }) {
                    if cloudReminder.updated_at > localReminder.time {
                        localReminder.title = cloudReminder.title
                        localReminder.notes = cloudReminder.notes
                        localReminder.time = cloudReminder.time
                        localReminder.isEnabled = cloudReminder.is_enabled
                        localReminder.weekdays = cloudReminder.weekdays
                    }
                } else {
                    let newReminder = Reminder(
                        id: UUID(uuidString: cloudReminder.id) ?? UUID(),
                        title: cloudReminder.title,
                        notes: cloudReminder.notes,
                        time: cloudReminder.time,
                        isEnabled: cloudReminder.is_enabled,
                        weekdays: cloudReminder.weekdays
                    )
                    newReminder.userId = userId
                    context.insert(newReminder)
                }
            }

            // Upload local → cloud (BATCH for performance)
            var remindersToUpload: [CloudReminder] = []
            for localReminder in localReminders {
                let existsInCloud = cloudReminders.contains(where: { $0.id == localReminder.id.uuidString })
                if !existsInCloud {
                    remindersToUpload.append(CloudReminder(
                        id: localReminder.id.uuidString,
                        user_id: userId,
                        title: localReminder.title,
                        notes: localReminder.notes,
                        time: localReminder.time,
                        is_enabled: localReminder.isEnabled,
                        weekdays: localReminder.weekdays,
                        notification_id: localReminder.notificationID,
                        updated_at: localReminder.time
                    ))
                }
            }
            
            // Batch upsert all at once
            if !remindersToUpload.isEmpty {
                try await supabaseClient.database.from("user_reminders").upsert(remindersToUpload).execute()
            }

            try? context.save()
            print("✅ Reminders synced")

        } catch {
            print("❌ Reminders sync failed: \(error)")
        }
    }

    // MARK: - Single Item Upload (for real-time sync)

    /// Upload a single food log immediately after creation
    func uploadFoodLogImmediately(_ log: LoggedFood, userId: String) async {
        do {
            try await uploadFoodLog(log, userId: userId)
            print("✅ Food log uploaded: \(log.name)")
        } catch {
            print("❌ Failed to upload food log: \(error)")
        }
    }

    /// Upload a single water log immediately after creation
    func uploadWaterLogImmediately(_ log: LoggedWater, userId: String) async {
        do {
            let cloudLog = CloudWaterLog(
                id: log.id.uuidString,
                user_id: userId,
                amount_ml: log.amountML,
                timestamp: log.timestamp,
                updated_at: log.timestamp
            )
            try await supabaseClient.database.from("user_water_logs").upsert(cloudLog).execute()
            print("✅ Water log uploaded")
        } catch {
            print("❌ Failed to upload water log: \(error)")
        }
    }

    /// Upload a single fasting log immediately after creation or completion
    func uploadFastingLogImmediately(_ log: FastingLog, userId: String) async {
        do {
            let cloudLog = CloudFastingLog(
                id: log.id.uuidString,
                user_id: userId,
                start_time: log.startTime,
                end_time: log.endTime,
                goal_hours: log.goalHours,
                updated_at: log.endTime ?? log.startTime
            )
            try await supabaseClient.database.from("user_fasting_logs").upsert(cloudLog).execute()
            print("✅ Fasting log uploaded")
        } catch {
            print("❌ Failed to upload fasting log: \(error)")
        }
    }

    /// Upload a single weight log immediately after creation
    func uploadWeightLogImmediately(_ log: LoggedWeight, userId: String) async {
        do {
            let cloudLog = CloudWeightLog(
                id: log.id.uuidString,
                user_id: userId,
                weight_kg: log.weightKg,
                note: log.note,
                timestamp: log.timestamp,
                updated_at: log.timestamp
            )
            try await supabaseClient.database.from("user_weight_logs").upsert(cloudLog).execute()
            print("✅ Weight log uploaded: \(log.weightKg) kg")
        } catch {
            print("❌ Failed to upload weight log: \(error)")
        }
    }

    /// Delete a weight log from the cloud
    func deleteWeightLogFromCloud(logId: String, userId: String) async {
        do {
            try await supabaseClient.database
                .from("user_weight_logs")
                .delete()
                .eq("id", value: logId)
                .eq("user_id", value: userId)
                .execute()

            print("☁️ Deleted weight log from cloud: \(logId)")
        } catch {
            print("❌ Failed to delete weight log from cloud: \(error)")
        }
    }

    // MARK: - User Goals Sync

    /// Upload user goals immediately after they're changed
    @MainActor
    func uploadUserGoalsImmediately(_ goals: UserGoals, userId: String) async {
        // Import needed for Auth User type
        guard let userUUID = UUID(uuidString: userId) else {
            print("❌ Invalid userId format")
            return
        }

        do {
            let birthString = ISO8601DateFormatter().string(from: goals.birthDate)

            let params = UpsertProfileParams(
                user_id: userUUID,
                name: goals.name,
                birthdate: birthString,
                gender: goals.gender.rawValue,
                height_cm: Int(goals.height),
                weight_kg: goals.weight,
                activity_level: goals.activityLevel.rawValue,
                weight_goal: goals.weightGoal.rawValueAsInt,
                target_weight: goals.targetWeight,
                daily_calories: Int(goals.dailyCalories),
                daily_protein: Int(goals.dailyProtein),
                daily_carbs: Int(goals.dailyCarbs),
                daily_fat: Int(goals.dailyFat),
                blockers: goals.blockersRaw,
                diet_type: goals.dietTypeRaw,
                goals_to_accomplish: goals.goalsToAccomplishRaw,
                referral_code: goals.referralCode,
                healthkit_enabled: goals.healthKitEnabled
            )

            try await supabaseClient.database
                .from("profiles")
                .update(params)
                .eq("user_id", value: userUUID)
                .execute()

            print("✅ User goals uploaded to Supabase")
        } catch {
            print("❌ Failed to upload user goals: \(error)")
        }
    }

    // MARK: - Fitness Logs Sync

    func syncFitnessLogs(userId: String, context: ModelContext) async {
        do {
            let localPredicate = #Predicate<LoggedFitness> { $0.userId == userId }
            let localDescriptor = FetchDescriptor<LoggedFitness>(predicate: localPredicate)
            let localLogs = (try? context.fetch(localDescriptor)) ?? []

            let cloudLogs: [CloudFitnessLog] = try await supabaseClient.database
                .from("user_fitness_logs")
                .select()
                .eq("user_id", value: userId)
                .execute()
                .value

            // Merge cloud → local
            for cloudLog in cloudLogs {
                if let localLog = localLogs.first(where: { $0.id.uuidString == cloudLog.id }) {
                    if cloudLog.updated_at > localLog.date {
                        localLog.steps = cloudLog.steps
                        localLog.caloriesBurned = cloudLog.calories_burned
                    }
                } else {
                    let dateFormatter = ISO8601DateFormatter()
                    dateFormatter.formatOptions = [.withFullDate]
                    guard let date = dateFormatter.date(from: cloudLog.date) else { continue }
                    
                    let newLog = LoggedFitness(
                        id: UUID(uuidString: cloudLog.id) ?? UUID(),
                        date: date,
                        steps: cloudLog.steps,
                        caloriesBurned: cloudLog.calories_burned
                    )
                    newLog.userId = userId
                    context.insert(newLog)
                }
            }

            // Upload local → cloud (BATCH for performance)
            var logsToUpload: [CloudFitnessLog] = []
            let dateFormatter = ISO8601DateFormatter()
            dateFormatter.formatOptions = [.withFullDate]
            
            for localLog in localLogs {
                let existsInCloud = cloudLogs.contains(where: { $0.id == localLog.id.uuidString })
                if !existsInCloud {
                    logsToUpload.append(CloudFitnessLog(
                        id: localLog.id.uuidString,
                        user_id: userId,
                        date: dateFormatter.string(from: localLog.date),
                        steps: localLog.steps,
                        calories_burned: localLog.caloriesBurned,
                        updated_at: localLog.date
                    ))
                }
            }
            
            // Batch upsert all at once
            if !logsToUpload.isEmpty {
                try await supabaseClient.database.from("user_fitness_logs").upsert(logsToUpload).execute()
            }

            try? context.save()
            print("✅ Fitness logs synced")

        } catch {
            print("❌ Fitness logs sync failed: \(error)")
        }
    }

    /// Upload a single fitness log immediately after creation/update
    func uploadFitnessLogImmediately(_ log: LoggedFitness, userId: String) async {
        do {
            let dateFormatter = ISO8601DateFormatter()
            dateFormatter.formatOptions = [.withFullDate]
            
            let cloudLog = CloudFitnessLog(
                id: log.id.uuidString,
                user_id: userId,
                date: dateFormatter.string(from: log.date),
                steps: log.steps,
                calories_burned: log.caloriesBurned,
                updated_at: log.date
            )
            try await supabaseClient.database.from("user_fitness_logs").upsert(cloudLog).execute()
            print("✅ Fitness log uploaded")
        } catch {
            print("❌ Failed to upload fitness log: \(error)")
        }
    }

    /// Delete a fitness log from the cloud
    func deleteFitnessLogFromCloud(logId: String, userId: String) async {
        do {
            try await supabaseClient.database
                .from("user_fitness_logs")
                .delete()
                .eq("id", value: logId)
                .eq("user_id", value: userId)
                .execute()

            print("☁️ Deleted fitness log from cloud: \(logId)")
        } catch {
            print("❌ Failed to delete fitness log from cloud: \(error)")
        }
    }

    // MARK: - Running Profile Sync

    /// Bidirectional sync for the user's single running_profile row.
    /// Resolves conflicts by newer `updated_at`.
    @MainActor
    func syncRunningProfile(userId: String, context: ModelContext) async {
        let local = await UserScopedQuery.fetchRunningProfile(context: context)

        do {
            let remoteRows: [CloudRunningProfile] = try await supabaseClient.database
                .from("running_profiles")
                .select()
                .eq("user_id", value: userId)
                .limit(1)
                .execute()
                .value
            let remote = remoteRows.first

            switch (local, remote) {
            case (nil, nil):
                // Nothing on either side — user hasn't onboarded yet.
                break

            case (nil, let cloud?):
                // Cloud-only: hydrate local.
                let newLocal = makeLocalRunningProfile(from: cloud)
                context.insert(newLocal)
                try? context.save()

            case (let localProfile?, nil):
                // Local-only: push to cloud.
                await uploadRunningProfileImmediately(localProfile, userId: userId)

            case (let localProfile?, let cloud?):
                // Both present — newer wins.
                if cloud.updated_at > localProfile.updatedAt {
                    applyCloudToLocal(cloud, local: localProfile)
                    try? context.save()
                } else if localProfile.updatedAt > cloud.updated_at {
                    await uploadRunningProfileImmediately(localProfile, userId: userId)
                }
            }

            print("✅ Running profile synced")
        } catch {
            print("❌ Running profile sync failed: \(error)")
        }
    }

    /// Upload the local running profile to Supabase (upsert).
    /// Derives `user_id` from the live Supabase auth session so the value
    /// always matches `auth.uid()` that RLS checks against.
    func uploadRunningProfileImmediately(_ profile: RunningProfile, userId: String) async {
        // Use the live auth session's UUID — not the cached `userId` string —
        // so we never accidentally push a row whose user_id disagrees with
        // the JWT on the request.
        guard let session = try? await supabaseClient.auth.session else {
            print("❌ Cannot upload running profile: no active Supabase session")
            return
        }
        let authUserId = session.user.id

        let cloud = await makeCloudRunningProfile(from: profile, userId: authUserId)
        do {
            try await supabaseClient.database
                .from("running_profiles")
                .upsert(cloud)
                .execute()
            print("✅ Running profile uploaded")
        } catch {
            print("❌ Failed to upload running profile: \(error)")
        }
    }

    // MARK: Running profile mapping helpers

    @MainActor
    private func makeCloudRunningProfile(from p: RunningProfile, userId: UUID) -> CloudRunningProfile {
        CloudRunningProfile(
            user_id: userId,
            has_completed_onboarding: p.hasCompletedOnboarding,
            experience: p.experienceRaw,
            has_run_before: p.hasRunBefore,
            primary_goal: p.primaryGoalRaw,
            weekly_run_days_target: p.weeklyRunDaysTarget,
            available_days: p.availableDaysRaw,
            long_run_day: p.longRunDayRaw,
            current_longest_run_km: p.currentLongestRunKm,
            current_weekly_km: p.currentWeeklyKm,
            typical_pace_seconds_per_km: p.typicalPaceSecondsPerKm,
            recent_1km_seconds: p.recent1kmSeconds,
            recent_5km_seconds: p.recent5kmSeconds,
            recent_10km_seconds: p.recent10kmSeconds,
            recent_half_marathon_seconds: p.recentHalfMarathonSeconds,
            recent_marathon_seconds: p.recentMarathonSeconds,
            target_race_date: p.targetRaceDate,
            target_race_distance: p.targetRaceDistanceRaw,
            target_race_name: p.targetRaceName,
            target_race_goal_time_seconds: p.targetRaceGoalTimeSeconds,
            injuries_or_limitations: p.injuriesOrLimitations,
            cross_training_activities: p.crossTrainingActivitiesRaw.isEmpty ? nil : p.crossTrainingActivitiesRaw,
            cross_training_sessions_per_week: p.crossTrainingSessionsPerWeek,
            cross_training_schedule: p.crossTrainingScheduleRaw.isEmpty ? nil : p.crossTrainingScheduleRaw,
            workout_reminders_enabled: p.workoutRemindersEnabled,
            workout_reminder_hour: p.workoutReminderHour,
            workout_reminder_minute: p.workoutReminderMinute,
            created_at: p.createdAt,
            updated_at: p.updatedAt
        )
    }

    @MainActor
    private func makeLocalRunningProfile(from cloud: CloudRunningProfile) -> RunningProfile {
        let p = RunningProfile()
        p.userId = cloud.user_id.uuidString.lowercased()
        applyCloudToLocal(cloud, local: p)
        return p
    }

    @MainActor
    private func applyCloudToLocal(_ cloud: CloudRunningProfile, local p: RunningProfile) {
        p.hasCompletedOnboarding = cloud.has_completed_onboarding
        p.experienceRaw = cloud.experience
        p.hasRunBefore = cloud.has_run_before
        p.primaryGoalRaw = cloud.primary_goal
        p.weeklyRunDaysTarget = cloud.weekly_run_days_target
        p.availableDaysRaw = cloud.available_days
        p.longRunDayRaw = cloud.long_run_day
        p.currentLongestRunKm = cloud.current_longest_run_km
        p.currentWeeklyKm = cloud.current_weekly_km
        p.typicalPaceSecondsPerKm = cloud.typical_pace_seconds_per_km
        p.recent1kmSeconds = cloud.recent_1km_seconds
        p.recent5kmSeconds = cloud.recent_5km_seconds
        p.recent10kmSeconds = cloud.recent_10km_seconds
        p.recentHalfMarathonSeconds = cloud.recent_half_marathon_seconds
        p.recentMarathonSeconds = cloud.recent_marathon_seconds
        p.targetRaceDate = cloud.target_race_date
        p.targetRaceDistanceRaw = cloud.target_race_distance
        p.targetRaceName = cloud.target_race_name
        p.targetRaceGoalTimeSeconds = cloud.target_race_goal_time_seconds
        p.injuriesOrLimitations = cloud.injuries_or_limitations
        p.crossTrainingActivitiesRaw = cloud.cross_training_activities ?? []
        p.crossTrainingSessionsPerWeek = cloud.cross_training_sessions_per_week ?? 0
        p.crossTrainingScheduleRaw = cloud.cross_training_schedule ?? []
        p.workoutRemindersEnabled = cloud.workout_reminders_enabled ?? false
        p.workoutReminderHour = cloud.workout_reminder_hour
        p.workoutReminderMinute = cloud.workout_reminder_minute
        p.createdAt = cloud.created_at
        p.updatedAt = cloud.updated_at
    }

    // MARK: - Running Plans Sync

    /// Bidirectional sync for the user's running plans and their sessions.
    /// Phase 3a scope: hydrate local SwiftData from cloud + push any local
    /// plans that exist only locally. Conflict resolution is
    /// newer-`updated_at`-wins at the plan and session level.
    @MainActor
    func syncRunningPlans(userId: String, context: ModelContext) async {
        do {
            // --- Fetch remote ---
            let remotePlans: [CloudRunningPlan] = try await supabaseClient.database
                .from("running_plans")
                .select()
                .eq("user_id", value: userId)
                .execute()
                .value

            // Paginate session fetch in 500-row pages so we never hit PostgREST's
            // default max-rows ceiling (1000). Developers who regenerate many test
            // plans accumulate hundreds of sessions; without pagination the newest
            // plan's sessions can be silently dropped from the response.
            var remoteSessions: [CloudPlannedSession] = []
            let sessionPageSize = 500
            var sessionOffset = 0
            while true {
                let page: [CloudPlannedSession] = try await supabaseClient.database
                    .from("planned_sessions")
                    .select()
                    .eq("user_id", value: userId)
                    .range(from: sessionOffset, to: sessionOffset + sessionPageSize - 1)
                    .execute()
                    .value
                remoteSessions.append(contentsOf: page)
                if page.count < sessionPageSize { break }
                sessionOffset += sessionPageSize
            }

            // --- Local ---
            let localPlans = await UserScopedQuery.fetchRunningPlans(context: context)

            // Plan index by id (local).
            var localPlansById: [UUID: RunningPlan] = [:]
            for p in localPlans { localPlansById[p.id] = p }

            // Merge cloud plans → local.
            for cloud in remotePlans {
                if let local = localPlansById[cloud.id] {
                    if cloud.updated_at > local.updatedAt {
                        applyCloudToLocal(cloud, local: local)
                    }
                } else {
                    let newLocal = makeLocalRunningPlan(from: cloud)
                    context.insert(newLocal)
                    localPlansById[newLocal.id] = newLocal
                }
            }

            // Upload local-only plans.
            let remotePlanIds = Set(remotePlans.map(\.id))
            var plansToUpload: [CloudRunningPlan] = []
            for local in localPlans where !remotePlanIds.contains(local.id) {
                plansToUpload.append(makeCloudRunningPlan(from: local, userId: userId))
            }
            if !plansToUpload.isEmpty {
                _ = try? await supabaseClient.database
                    .from("running_plans")
                    .upsert(plansToUpload)
                    .execute()
            }

            // --- Sessions ---
            // Local sessions grouped by plan.
            let allLocalSessions: [PlannedSession] = localPlansById.values.flatMap { $0.sessions }
            var localSessionsById: [UUID: PlannedSession] = [:]
            for s in allLocalSessions { localSessionsById[s.id] = s }

            // Merge cloud sessions → local.
            for cloudSession in remoteSessions {
                if let local = localSessionsById[cloudSession.id] {
                    if cloudSession.updated_at > local.updatedAt {
                        applyCloudToLocal(cloudSession, local: local)
                    }
                } else if let owningPlan = localPlansById[cloudSession.plan_id] {
                    let newLocal = makeLocalPlannedSession(from: cloudSession, plan: owningPlan)
                    context.insert(newLocal)
                    localSessionsById[newLocal.id] = newLocal
                }
            }

            // Upload local-only sessions.
            let remoteSessionIds = Set(remoteSessions.map(\.id))
            var sessionsToUpload: [CloudPlannedSession] = []
            for local in allLocalSessions where !remoteSessionIds.contains(local.id) {
                guard let plan = local.plan else { continue }
                sessionsToUpload.append(makeCloudPlannedSession(from: local, plan: plan, userId: userId))
            }
            if !sessionsToUpload.isEmpty {
                _ = try? await supabaseClient.database
                    .from("planned_sessions")
                    .upsert(sessionsToUpload)
                    .execute()
            }

            // --- Adaptations ---
            // Mirrors the plan/session merge: pull cloud, upsert local-only,
            // newer-updated_at-wins. Adaptations are written by the edge
            // function so most flow is download-only, but we keep upload paths
            // so acknowledged_at flips can sync back when the user dismisses
            // a banner offline.
            await syncRunningPlanAdaptations(userId: userId, context: context)

            try? context.save()
            print("✅ Running plans synced (\(localPlansById.count) plans, \(localSessionsById.count) sessions)")
        } catch {
            print("❌ Running plans sync failed: \(error)")
        }
    }

    /// Bidirectional sync of `running_plan_adaptations`.
    /// Called as a tail step from `syncRunningPlans` so plans/sessions are
    /// already up to date locally — adaptations reference plans by id.
    @MainActor
    private func syncRunningPlanAdaptations(userId: String, context: ModelContext) async {
        do {
            let remote: [CloudRunningPlanAdaptation] = try await supabaseClient.database
                .from("running_plan_adaptations")
                .select()
                .eq("user_id", value: userId)
                .execute()
                .value

            let descriptor = FetchDescriptor<RunningPlanAdaptation>()
            let local = (try? context.fetch(descriptor)) ?? []
            var localById: [UUID: RunningPlanAdaptation] = [:]
            for a in local { localById[a.id] = a }

            // Cloud → local merge (newer-updated_at-wins).
            for cloud in remote {
                if let existing = localById[cloud.id] {
                    if cloud.updated_at > existing.updatedAt {
                        applyCloudToLocal(cloud, local: existing)
                    }
                } else {
                    let newLocal = makeLocalRunningPlanAdaptation(from: cloud)
                    context.insert(newLocal)
                    localById[newLocal.id] = newLocal
                }
            }

            // Push acknowledged_at flips back to cloud. We only ever change
            // that single column from the client — the audit fields are
            // service-role only (locked down by trigger after the security
            // tightening migration). Local-only INSERT rows shouldn't exist
            // anymore: every adaptation is created server-side by the edge
            // function and pulled into local via this same sync.
            for a in local {
                guard let cloud = remote.first(where: { $0.id == a.id }) else { continue }
                guard a.updatedAt > cloud.updated_at,
                      a.acknowledgedAt != cloud.acknowledged_at
                else { continue }
                await pushAcknowledgedAt(adaptation: a, userId: userId)
            }
        } catch {
            print("⚠️ Adaptations sync failed (non-fatal): \(error)")
        }
    }

    /// Mark an adaptation as read both locally and in the cloud. The local
    /// flip happens immediately; the cloud update is best-effort.
    @MainActor
    func acknowledgeAdaptation(_ adaptation: RunningPlanAdaptation) async {
        guard adaptation.acknowledgedAt == nil else { return }
        adaptation.acknowledgedAt = Date()
        adaptation.updatedAt = Date()

        guard let session = try? await supabaseClient.auth.session else { return }
        await pushAcknowledgedAt(
            adaptation: adaptation,
            userId: session.user.id.uuidString.lowercased()
        )
    }

    /// Targeted UPDATE of just `acknowledged_at` (and the auto-bumped
    /// `updated_at`). Used both by the dismiss flow and by sync. Sending
    /// only this column avoids tripping the field-immutability trigger
    /// on `running_plan_adaptations` — JSONB column round-trips can
    /// produce false positives in `IS DISTINCT FROM` comparisons.
    @MainActor
    private func pushAcknowledgedAt(
        adaptation: RunningPlanAdaptation,
        userId: String
    ) async {
        struct AckPayload: Encodable {
            let acknowledged_at: Date?
        }
        let payload = AckPayload(acknowledged_at: adaptation.acknowledgedAt)
        do {
            try await supabaseClient.database
                .from("running_plan_adaptations")
                .update(payload)
                .eq("id", value: adaptation.id.uuidString)
                .eq("user_id", value: userId)
                .execute()
        } catch {
            print("⚠️ Failed to push acknowledged_at: \(error)")
        }
    }

    @MainActor
    private func makeCloudRunningPlanAdaptation(
        from a: RunningPlanAdaptation,
        userId: UUID
    ) -> CloudRunningPlanAdaptation {
        CloudRunningPlanAdaptation(
            id: a.id,
            user_id: userId,
            plan_id: a.planId,
            reason: a.reasonRaw,
            summary: a.summary,
            changes: a.changesJSON,
            sessions_changed: a.sessionsChanged,
            acknowledged_at: a.acknowledgedAt,
            created_at: a.createdAt,
            updated_at: a.updatedAt
        )
    }

    @MainActor
    private func makeLocalRunningPlanAdaptation(
        from cloud: CloudRunningPlanAdaptation
    ) -> RunningPlanAdaptation {
        let a = RunningPlanAdaptation(
            id: cloud.id,
            userId: cloud.user_id.uuidString.lowercased(),
            planId: cloud.plan_id,
            summary: cloud.summary,
            changesJSON: cloud.changes,
            sessionsChanged: cloud.sessions_changed,
            acknowledgedAt: cloud.acknowledged_at,
            createdAt: cloud.created_at,
            updatedAt: cloud.updated_at
        )
        a.reasonRaw = cloud.reason
        return a
    }

    @MainActor
    private func applyCloudToLocal(
        _ cloud: CloudRunningPlanAdaptation,
        local a: RunningPlanAdaptation
    ) {
        a.userId = cloud.user_id.uuidString.lowercased()
        a.planId = cloud.plan_id
        a.reasonRaw = cloud.reason
        a.summary = cloud.summary
        a.changesJSON = cloud.changes
        a.sessionsChanged = cloud.sessions_changed
        a.acknowledgedAt = cloud.acknowledged_at
        a.createdAt = cloud.created_at
        a.updatedAt = cloud.updated_at
    }

    /// Upload a single plan (and its sessions) immediately — e.g. right after
    /// the generate-plan edge function returns a freshly-built plan.
    func uploadRunningPlanImmediately(_ plan: RunningPlan) async {
        guard let session = try? await supabaseClient.auth.session else {
            print("❌ Cannot upload running plan: no active Supabase session")
            return
        }
        let authUserId = session.user.id

        let (planDTO, sessionDTOs) = await makeCloudRunningPlanBundle(from: plan, userId: authUserId)

        do {
            try await supabaseClient.database
                .from("running_plans")
                .upsert(planDTO)
                .execute()

            if !sessionDTOs.isEmpty {
                try await supabaseClient.database
                    .from("planned_sessions")
                    .upsert(sessionDTOs)
                    .execute()
            }
            print("✅ Running plan uploaded (\(sessionDTOs.count) sessions)")
        } catch {
            print("❌ Failed to upload running plan: \(error)")
        }
    }

    /// Hard-delete a running plan from Supabase. The `planned_sessions` FK is
    /// `ON DELETE CASCADE`, so the plan's sessions are dropped server-side
    /// automatically — callers only need to forget the plan locally afterwards.
    ///
    /// Returns `true` on success. Callers should hold off on the local delete
    /// until this returns true; otherwise the next `syncRunningPlans` will see
    /// the plan still in cloud + missing locally and resurrect it.
    @discardableResult
    func deleteRunningPlanFromCloud(_ planId: UUID) async -> Bool {
        guard (try? await supabaseClient.auth.session) != nil else {
            print("❌ Cannot delete running plan: no active Supabase session")
            return false
        }
        do {
            try await supabaseClient.database
                .from("running_plans")
                .delete()
                .eq("id", value: planId.uuidString)
                .execute()
            print("🗑️ Running plan deleted from cloud (id=\(planId))")
            return true
        } catch {
            print("❌ Failed to delete running plan: \(error)")
            return false
        }
    }

    /// Upload a single session (e.g. when user marks it complete).
    func uploadPlannedSessionImmediately(_ session: PlannedSession) async {
        guard let authSession = try? await supabaseClient.auth.session else {
            print("❌ Cannot upload planned session: no active Supabase session")
            return
        }
        let authUserId = authSession.user.id

        guard let dto = await makeSessionDTOIfPossible(session, userId: authUserId) else {
            print("❌ Cannot upload planned session: missing plan relationship")
            return
        }
        do {
            try await supabaseClient.database
                .from("planned_sessions")
                .upsert(dto)
                .execute()
            print("✅ Planned session uploaded")
        } catch {
            print("❌ Failed to upload planned session: \(error)")
        }
    }

    @MainActor
    private func makeSessionDTOIfPossible(_ session: PlannedSession, userId: UUID) -> CloudPlannedSession? {
        guard let plan = session.plan else { return nil }
        return makeCloudPlannedSession(from: session, plan: plan, userId: userId)
    }

    // MARK: Running plan mapping helpers

    @MainActor
    private func makeCloudRunningPlanBundle(
        from plan: RunningPlan,
        userId: UUID
    ) -> (CloudRunningPlan, [CloudPlannedSession]) {
        let planDTO = makeCloudRunningPlan(from: plan, userId: userId)
        let sessions = plan.sessions.map {
            makeCloudPlannedSession(from: $0, plan: plan, userId: userId)
        }
        return (planDTO, sessions)
    }

    @MainActor
    private func makeCloudRunningPlan(from p: RunningPlan, userId: String) -> CloudRunningPlan {
        let uuid = UUID(uuidString: userId) ?? UUID()
        return makeCloudRunningPlan(from: p, userId: uuid)
    }

    @MainActor
    private func makeCloudRunningPlan(from p: RunningPlan, userId: UUID) -> CloudRunningPlan {
        CloudRunningPlan(
            id: p.id,
            user_id: userId,
            name: p.name,
            goal_type: p.goalTypeRaw,
            status: p.statusRaw,
            start_date: p.startDate,
            total_weeks: p.totalWeeks,
            target_race_date: p.targetRaceDate,
            target_race_distance: p.targetRaceDistanceRaw,
            target_race_name: p.targetRaceName,
            target_race_goal_time_seconds: p.targetRaceGoalTimeSeconds,
            generation_source: p.generationSourceRaw,
            generation_context: p.generationContextJSON,
            model_version: p.modelVersion,
            created_at: p.createdAt,
            updated_at: p.updatedAt
        )
    }

    @MainActor
    private func makeCloudPlannedSession(
        from s: PlannedSession,
        plan: RunningPlan,
        userId: String
    ) -> CloudPlannedSession {
        let uuid = UUID(uuidString: userId) ?? UUID()
        return makeCloudPlannedSession(from: s, plan: plan, userId: uuid)
    }

    @MainActor
    private func makeCloudPlannedSession(
        from s: PlannedSession,
        plan: RunningPlan,
        userId: UUID
    ) -> CloudPlannedSession {
        CloudPlannedSession(
            id: s.id,
            user_id: userId,
            plan_id: plan.id,
            week_number: s.weekNumber,
            scheduled_date: s.scheduledDate,
            session_type: s.sessionTypeRaw,
            target_distance_km: s.targetDistanceKm,
            target_duration_minutes: s.targetDurationMinutes,
            target_pace_seconds_per_km: s.targetPaceSecondsPerKm,
            description: s.sessionDescription,
            notes: s.notes,
            completed_at: s.completedAt,
            completed_distance_km: s.completedDistanceKm,
            completed_duration_minutes: s.completedDurationMinutes,
            completed_source: s.completedSource,
            skipped: s.skipped,
            created_at: s.createdAt,
            updated_at: s.updatedAt
        )
    }

    @MainActor
    private func makeLocalRunningPlan(from cloud: CloudRunningPlan) -> RunningPlan {
        let p = RunningPlan(
            id: cloud.id,
            userId: cloud.user_id.uuidString.lowercased(),
            name: cloud.name,
            goalType: RunningGoalType(rawValue: cloud.goal_type) ?? .generalFitness,
            status: RunningPlanStatus(rawValue: cloud.status) ?? .active,
            startDate: cloud.start_date,
            totalWeeks: cloud.total_weeks,
            targetRaceDate: cloud.target_race_date,
            targetRaceDistance: cloud.target_race_distance.flatMap { RaceDistance(rawValue: $0) },
            targetRaceName: cloud.target_race_name,
            targetRaceGoalTimeSeconds: cloud.target_race_goal_time_seconds,
            generationSource: RunningPlanGenerationSource(rawValue: cloud.generation_source) ?? .ai,
            generationContextJSON: cloud.generation_context,
            modelVersion: cloud.model_version,
            createdAt: cloud.created_at,
            updatedAt: cloud.updated_at
        )
        return p
    }

    @MainActor
    private func makeLocalPlannedSession(
        from cloud: CloudPlannedSession,
        plan: RunningPlan
    ) -> PlannedSession {
        let s = PlannedSession(
            id: cloud.id,
            userId: cloud.user_id.uuidString.lowercased(),
            weekNumber: cloud.week_number,
            scheduledDate: cloud.scheduled_date,
            sessionType: RunningSessionType(rawValue: cloud.session_type) ?? .easy,
            targetDistanceKm: cloud.target_distance_km,
            targetDurationMinutes: cloud.target_duration_minutes,
            targetPaceSecondsPerKm: cloud.target_pace_seconds_per_km,
            description: cloud.description,
            notes: cloud.notes,
            createdAt: cloud.created_at,
            updatedAt: cloud.updated_at
        )
        s.plan = plan
        s.completedAt = cloud.completed_at
        s.completedDistanceKm = cloud.completed_distance_km
        s.completedDurationMinutes = cloud.completed_duration_minutes
        s.completedSource = cloud.completed_source
        s.skipped = cloud.skipped
        return s
    }

    @MainActor
    private func applyCloudToLocal(_ cloud: CloudRunningPlan, local p: RunningPlan) {
        p.name = cloud.name
        p.goalTypeRaw = cloud.goal_type
        p.statusRaw = cloud.status
        p.startDate = cloud.start_date
        p.totalWeeks = cloud.total_weeks
        p.targetRaceDate = cloud.target_race_date
        p.targetRaceDistanceRaw = cloud.target_race_distance
        p.targetRaceName = cloud.target_race_name
        p.targetRaceGoalTimeSeconds = cloud.target_race_goal_time_seconds
        p.generationSourceRaw = cloud.generation_source
        p.generationContextJSON = cloud.generation_context
        p.modelVersion = cloud.model_version
        p.createdAt = cloud.created_at
        p.updatedAt = cloud.updated_at
    }

    @MainActor
    private func applyCloudToLocal(_ cloud: CloudPlannedSession, local s: PlannedSession) {
        s.weekNumber = cloud.week_number
        s.scheduledDate = cloud.scheduled_date
        s.sessionTypeRaw = cloud.session_type
        s.targetDistanceKm = cloud.target_distance_km
        s.targetDurationMinutes = cloud.target_duration_minutes
        s.targetPaceSecondsPerKm = cloud.target_pace_seconds_per_km
        s.sessionDescription = cloud.description
        s.notes = cloud.notes
        s.completedAt = cloud.completed_at
        s.completedDistanceKm = cloud.completed_distance_km
        s.completedDurationMinutes = cloud.completed_duration_minutes
        s.completedSource = cloud.completed_source
        s.skipped = cloud.skipped
        s.updatedAt = cloud.updated_at
    }
}

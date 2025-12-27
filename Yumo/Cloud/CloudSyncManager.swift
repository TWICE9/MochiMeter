// Cloud/CloudSyncManager.swift

import Foundation
import SwiftData
import Supabase

enum CloudSyncStep: CaseIterable {
    case foodLogs
    case waterLogs
    case weightLogs
    case fastingLogs
    case recipes
    case reminders
    case userGoals
    case complete

    var label: String {
        switch self {
        case .foodLogs: return "Food logs synced"
        case .waterLogs: return "Water logs synced"
        case .weightLogs: return "Weight logs synced"
        case .fastingLogs: return "Fasting logs synced"
        case .recipes: return "Recipes synced"
        case .reminders: return "Reminders synced"
        case .userGoals: return "Goals synced"
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
                .upsert(params)
                .execute()

            print("✅ User goals uploaded to Supabase")
        } catch {
            print("❌ Failed to upload user goals: \(error)")
        }
    }
}

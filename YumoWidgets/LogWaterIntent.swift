// YumoWidgets/LogWaterIntent.swift

import AppIntents
import SwiftData
import SwiftUI
import WidgetKit

struct LogWaterIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Water"
    static var description = IntentDescription("Logs a cup of water from the widget.")

    func perform() async throws -> some IntentResult {
        // ⭐️ FIX: Use the shared container helper (on MainActor for thread safety)
        let container = await MainActor.run { SharedModelContainer.create() }
        let context = ModelContext(container)

        do {
            // 0. Get userId from App Group UserDefaults
            let appGroupDefaults = UserDefaults(suiteName: "group.com.jesseta.yumo")
            let userId = appGroupDefaults?.string(forKey: "current_user_id")

            // 1. Fetch User Goals to get cup size (user-scoped)
            let goalsPredicate: Predicate<UserGoals>
            if let userId = userId {
                goalsPredicate = #Predicate { $0.userId == userId }
            } else {
                goalsPredicate = #Predicate { $0.userId == nil }
            }
            let descriptor = FetchDescriptor<UserGoals>(predicate: goalsPredicate)
            let goals = try context.fetch(descriptor).first
            let amount = goals?.waterCupSizeML ?? 250 // Default to 250 if no goal found

            // 2. Create and Insert the Log with userId
            let newLog = LoggedWater(amountML: amount)
            newLog.userId = userId
            context.insert(newLog)
            try context.save()

            print("💧 Widget logged \(amount)mL for user: \(userId ?? "offline")")

            // 3. Refresh the widget timeline immediately
            WidgetCenter.shared.reloadTimelines(ofKind: "WaterWidget")

            return .result()

        } catch {
            print("Failed to log water from widget: \(error)")
            return .result()
        }
    }
}

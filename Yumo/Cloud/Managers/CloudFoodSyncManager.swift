//
//  CloudFoodSyncManager.swift
//

import Foundation
import Supabase
import SwiftData

actor CloudFoodSyncManager {

    static let shared = CloudFoodSyncManager()
    private init() {}

    private let lastSyncKey = "cloud_last_sync_time"

    // MARK: - FETCH FROM CLOUD
    func fetchFoodsFromCloud(deltaSince: Date?) async -> [[String: Any]] {

        do {
            var query = await supabase.database
                .from("master_foods")
                .select()

            if let deltaSince {
                let iso = ISO8601DateFormatter().string(from: deltaSince)
                query = query.gte("updated_at", value: iso)
            }

            let result = try await query.execute()
            // Decode the response data using JSONSerialization
            if let json = try JSONSerialization.jsonObject(with: result.data) as? [[String: Any]] {
                return json
            }
            return []

        } catch {
            print("❌ Cloud fetch error:", error.localizedDescription)
            return []
        }
    }

    // MARK: - LOCAL DB LOOKUP
    @MainActor
    func findFoodInLocalDB(barcode: String, context: ModelContext) -> CloudFood? {
        let descriptor = FetchDescriptor<CloudFood>(
            predicate: #Predicate { $0.barcode == barcode }
        )
        return try? context.fetch(descriptor).first
    }

    // MARK: - SYNC INTO SWIFTDATA
    @MainActor
    func syncFoods(_ cloudFoods: [[String: Any]], context: ModelContext) async {

        for row in cloudFoods {
            guard let barcode = row["barcode"] as? String else { continue }

            let descriptor = FetchDescriptor<CloudFood>(
                predicate: #Predicate { $0.barcode == barcode }
            )
            let existing = try? context.fetch(descriptor).first

            let name = row["food_name"] as? String ?? "Unknown"
            let scanCount = row["scan_count"] as? Int ?? 0

            let calories = row["calories"] as? Double ?? 0
            let protein  = row["protein"] as? Double ?? 0
            let carbs    = row["carbs"] as? Double ?? 0
            let fat      = row["fat"] as? Double ?? 0
            let fiber    = row["fiber"] as? Double ?? 0

            // ⭐ NEW Nutrition
            let sugar = row["sugar"] as? Double ?? 0
            let salt = row["salt"] as? Double ?? 0
            let potassium = row["potassium"] as? Double ?? 0

            let updatedAtString = row["updated_at"] as? String
            let updatedAt = updatedAtString.flatMap {
                ISO8601DateFormatter().date(from: $0)
            } ?? Date()

            if let local = existing {
                // UPDATE
                local.name = name
                local.scanCount = scanCount

                local.calories = calories
                local.protein = protein
                local.carbs = carbs
                local.fat = fat
                local.fiber = fiber

                local.sugar = sugar
                local.salt = salt
                local.potassium = potassium

                local.updatedAt = updatedAt

            } else {
                // INSERT NEW
                let new = CloudFood(
                    barcode: barcode,
                    name: name,
                    scanCount: scanCount,
                    calories: calories,
                    protein: protein,
                    carbs: carbs,
                    fat: fat,
                    fiber: fiber,
                    sugar: sugar,
                    salt: salt,
                    potassium: potassium,
                    updatedAt: updatedAt
                )
                context.insert(new)
            }
        }

        try? context.save()
    }

    // MARK: - LAST SYNC TIME
    func getLastSyncTime() -> Date? {
        if let iso = UserDefaults.standard.string(forKey: lastSyncKey) {
            return ISO8601DateFormatter().date(from: iso)
        }
        return nil
    }

    func setLastSyncTime() {
        let iso = ISO8601DateFormatter().string(from: Date())
        UserDefaults.standard.set(iso, forKey: lastSyncKey)
    }

    // MARK: - APP LAUNCH SYNC
    @MainActor
    func syncOnAppLaunch(context: ModelContext) async {
        let last = await getLastSyncTime()
        let cloudData = await fetchFoodsFromCloud(deltaSince: last)
        await syncFoods(cloudData, context: context)
        await setLastSyncTime()
    }

    // MARK: - DAILY SYNC
    @MainActor
    func syncOncePerDay(context: ModelContext) async {
        let last = await getLastSyncTime()
        let now = Date()

        if let last, now.timeIntervalSince(last) < 86400 {
            print("🟦 Daily sync skipped <24h")
            return
        }

        print("🟩 Running daily sync")
        await syncOnAppLaunch(context: context)
    }
}

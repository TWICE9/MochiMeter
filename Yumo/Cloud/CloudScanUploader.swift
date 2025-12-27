//
//  CloudScanUploader.swift
//  Yumo
//

import Foundation
import Supabase

actor CloudScanUploader {
    static let shared = CloudScanUploader()
    private init() {}

    // MARK: - Payload for scan_history
    private struct ScanUploadPayload: Codable {
        let barcode: String
        let food_name: String
        let calories: Double
        let protein: Double
        let carbs: Double
        let fat: Double
        let fiber: Double
        let sugar: Double
        let salt: Double
        let potassium: Double
        let scanned_at: String
    }

    // MARK: - RPC params for upsert_food()
    private struct UpsertFoodParams: Encodable {
        let p_barcode: String
        let p_name: String
        let p_brand: String?
        let p_calories: Double
        let p_protein: Double
        let p_carbs: Double
        let p_fat: Double
        let p_fiber: Double
        let p_sugar: Double
        let p_salt: Double
        let p_potassium: Double
    }

    // MARK: - Upload scan to scan_history
    func uploadScan(
        barcode: String,
        name: String,
        caloriesPerServing: Double,
        proteinPerServing: Double,
        carbsPerServing: Double,
        fatPerServing: Double,
        fiberPerServing: Double,
        sugarPerServing: Double,
        saltPerServing: Double,
        potassiumPerServing: Double,
        servingAmount: Double
    ) async {

        let totalCalories = caloriesPerServing * servingAmount
        let totalProtein  = proteinPerServing * servingAmount
        let totalCarbs    = carbsPerServing * servingAmount
        let totalFat      = fatPerServing * servingAmount
        let totalFiber    = fiberPerServing * servingAmount
        let totalSugar    = sugarPerServing * servingAmount
        let totalSalt     = saltPerServing * servingAmount
        let totalPotassium = potassiumPerServing * servingAmount

        let payload = ScanUploadPayload(
            barcode: barcode,
            food_name: name,
            calories: totalCalories,
            protein: totalProtein,
            carbs: totalCarbs,
            fat: totalFat,
            fiber: totalFiber,
            sugar: totalSugar,
            salt: totalSalt,
            potassium: totalPotassium,
            scanned_at: ISO8601DateFormatter().string(from: Date())
        )

        do {
            try await supabase.database
                .from("scan_history")
                .insert(payload)
                .execute()

        } catch {
            print("❌ Failed to upload scan:", error.localizedDescription)
        }
    }

    // MARK: - Upsert into master_foods
    func incrementScanCount(
        for barcode: String,
        name: String,
        brand: String?,
        caloriesPerServing: Double,
        proteinPerServing: Double,
        carbsPerServing: Double,
        fatPerServing: Double,
        fiberPerServing: Double,
        sugarPerServing: Double,
        saltPerServing: Double,
        potassiumPerServing: Double,
        servingAmount: Double
    ) async {

        let totalCalories = caloriesPerServing * servingAmount
        let totalProtein  = proteinPerServing * servingAmount
        let totalCarbs    = carbsPerServing * servingAmount
        let totalFat      = fatPerServing * servingAmount
        let totalFiber    = fiberPerServing * servingAmount
        let totalSugar    = sugarPerServing * servingAmount
        let totalSalt     = saltPerServing * servingAmount
        let totalPotassium = potassiumPerServing * servingAmount

        let params = UpsertFoodParams(
            p_barcode: barcode,
            p_name: name,
            p_brand: brand,
            p_calories: totalCalories,
            p_protein: totalProtein,
            p_carbs: totalCarbs,
            p_fat: totalFat,
            p_fiber: totalFiber,
            p_sugar: totalSugar,
            p_salt: totalSalt,
            p_potassium: totalPotassium
        )

        do {
            try await supabase.database
                .rpc("upsert_food", params: params)
                .execute()

        } catch {
            print("❌ Failed upsert:", error.localizedDescription)
        }
    }
}

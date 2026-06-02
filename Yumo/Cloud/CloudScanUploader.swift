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

        let payload = ScanUploadPayload(
            barcode: barcode,
            food_name: name,
            calories: caloriesPerServing,
            protein: proteinPerServing,
            carbs: carbsPerServing,
            fat: fatPerServing,
            fiber: fiberPerServing,
            sugar: sugarPerServing,
            salt: saltPerServing,
            potassium: potassiumPerServing,
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

        let params = UpsertFoodParams(
            p_barcode: barcode,
            p_name: name,
            p_brand: brand,
            p_calories: caloriesPerServing,
            p_protein: proteinPerServing,
            p_carbs: carbsPerServing,
            p_fat: fatPerServing,
            p_fiber: fiberPerServing,
            p_sugar: sugarPerServing,
            p_salt: saltPerServing,
            p_potassium: potassiumPerServing
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

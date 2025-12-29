//
//  AIFoodScanner.swift
//  Yumo
//

import Foundation
import UIKit
import Supabase

// MARK: - AI Food Scanner Service
actor AIFoodScanner {
    static let shared = AIFoodScanner()

    private let client: SupabaseClient

    init(client: SupabaseClient = supabase) {
        self.client = client
    }

    /// Analyzes a food image using GPT-4o Mini and returns nutrition data
    func analyzeFood(image: UIImage) async throws -> FoodAnalysisResult {

        // 1. Resize image for faster upload (max 1024px on longest side)
        let resizedImage = image.resized(toMaxDimension: 1024)

        // 2. Compress and convert to base64 (0.85 quality for better accuracy)
        guard let imageData = resizedImage.jpegData(compressionQuality: 0.85) else {
            throw FoodScanError.imageProcessingFailed
        }

        let base64String = imageData.base64EncodedString()

        // 2. Call Supabase Edge Function
        let requestBody: [String: Any] = ["imageBase64": base64String]
        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            throw FoodScanError.invalidRequest
        }


        let response: FoodAnalysisResult = try await analyzeWithRetry(body: jsonData, functionName: "analyze-food")

        // 3. Return the parsed result
        let result = response

        return result
    }

    /// Analyzes a typed meal description (no image) using GPT-4o Mini
    func analyzeMealDescription(_ description: String) async throws -> FoodAnalysisResult {
        let trimmed = description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw FoodScanError.invalidRequest
        }
        
        // Get user's general location context (Country) for more accurate regional food data
        // We use Locale to avoid demanding location permissions/tracking
        let countryCode: String
        if #available(iOS 16, *) {
            countryCode = Locale.current.region?.identifier ?? "US"
        } else {
            countryCode = Locale.current.regionCode ?? "US"
        }
        
        let countryName = Locale.current.localizedString(forRegionCode: countryCode) ?? "United States"
        
        // Append location context to the description so the AI knows which regional menu to use
        // e.g. "KFC Zinger Box" -> "KFC Zinger Box (Location Context: Australia)"
        let descriptionWithContext = "\(trimmed) (Location Context: \(countryName))"

        let requestBody: [String: Any] = ["description": descriptionWithContext]
        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            throw FoodScanError.invalidRequest
        }

        // Text analysis - use 20 second timeout and single retry
        let response: FoodAnalysisResult = try await analyzeWithRetry(body: jsonData, functionName: "analyze-meal-text", timeout: 20, maxAttempts: 1)

        return response
    }
    
    /// Applies user-provided corrections to an existing analysis
    func analyzeFoodCorrection(current: FoodAnalysisResult, correction: String) async throws -> FoodAnalysisResult {
        let trimmed = correction.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw FoodScanError.invalidRequest }

        let requestBody: [String: Any] = [
            "current": [
                "name": current.name,
                "servingSize": current.servingSize,
                "calories": current.calories,
                "protein": current.protein,
                "carbs": current.carbs,
                "fat": current.fat,
                "fiber": current.fiber,
                "sugar": current.sugar,
                "ingredients": current.ingredients ?? []
            ],
            "correction": trimmed
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            throw FoodScanError.invalidRequest
        }

        let response: FoodAnalysisResult = try await analyzeWithRetry(
            body: jsonData,
            functionName: "analyze-food-fix",
            timeout: 12,
            maxAttempts: 1
        )
        return response
    }

    // MARK: - Private Helpers

    private func analyzeWithRetry(body: Data, functionName: String, timeout: Double = 18, attempt: Int = 1, maxAttempts: Int = 2) async throws -> FoodAnalysisResult {
        do {
            return try await withTimeout(seconds: timeout) {
                try await self.client.functions.invoke(
                    functionName,
                    options: FunctionInvokeOptions(body: body)
                )
            }
        } catch {
            if attempt < maxAttempts {
                let delay = UInt64(pow(2.0, Double(attempt - 1)) * 0.6 * 1_000_000_000)
                try? await Task.sleep(nanoseconds: delay)
                return try await analyzeWithRetry(body: body, functionName: functionName, timeout: timeout, attempt: attempt + 1, maxAttempts: maxAttempts)
            }

            if let scanError = error as? FoodScanError {
                throw scanError
            } else if (error as NSError).domain == NSURLErrorDomain {
                throw FoodScanError.networkError(error.localizedDescription)
            } else {
                throw error
            }
        }
    }

    private func withTimeout<T>(seconds: Double, operation: @escaping () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw FoodScanError.analysisTimeout
            }

            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }
}

// MARK: - Models
// MARK: - Models
struct FoodAnalysisResult: Codable, Sendable {
    let name: String
    let servingSize: String
    let calories: Double
    let protein: Double
    let carbs: Double
    let fat: Double
    let fiber: Double
    let sugar: Double
    let salt: Double // Added support
    let potassium: Double // Added support
    let confidence: String?
    let ingredients: [String]?

    enum CodingKeys: String, CodingKey {
        case name, servingSize, calories, protein, carbs, fat, fiber, sugar, salt, potassium, confidence, ingredients
    }

    // Regular memberwise initializer
    init(name: String, servingSize: String, calories: Double, protein: Double, carbs: Double, fat: Double, fiber: Double, sugar: Double, salt: Double = 0, potassium: Double = 0, confidence: String? = nil, ingredients: [String]? = nil) {
        self.name = name
        self.servingSize = servingSize
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.fiber = fiber
        self.sugar = sugar
        self.salt = salt
        self.potassium = potassium
        self.confidence = confidence
        self.ingredients = ingredients
    }

    // Custom decoder to validate and cap values
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        name = try container.decode(String.self, forKey: .name)
        servingSize = try container.decode(String.self, forKey: .servingSize)
        confidence = try container.decodeIfPresent(String.self, forKey: .confidence)
        ingredients = try container.decodeIfPresent([String].self, forKey: .ingredients)

        // Decode and validate numeric values
        // Use decodeIfPresent for new fields to maintain backward compatibility with old backend responses
        let rawCalories = try container.decode(Double.self, forKey: .calories)
        let rawProtein = try container.decode(Double.self, forKey: .protein)
        let rawCarbs = try container.decode(Double.self, forKey: .carbs)
        let rawFat = try container.decode(Double.self, forKey: .fat)
        let rawFiber = try container.decode(Double.self, forKey: .fiber)
        let rawSugar = try container.decode(Double.self, forKey: .sugar)
        let rawSalt = try container.decodeIfPresent(Double.self, forKey: .salt) ?? 0
        let rawPotassium = try container.decodeIfPresent(Double.self, forKey: .potassium) ?? 0

        // Apply validation caps (max 10,000 cal, 1,000g macros)
        calories = min(max(rawCalories, 0), 10_000)
        protein = min(max(rawProtein, 0), 1_000)
        carbs = min(max(rawCarbs, 0), 1_000)
        fat = min(max(rawFat, 0), 1_000)
        fiber = min(max(rawFiber, 0), 1_000)
        sugar = min(max(rawSugar, 0), 1_000)
        salt = min(max(rawSalt, 0), 1_000)
        potassium = min(max(rawPotassium, 0), 5_000) // Higher cap for potassium (mg)
    }

    // Manual encoder to maintain Codable conformance
    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(servingSize, forKey: .servingSize)
        try container.encode(calories, forKey: .calories)
        try container.encode(protein, forKey: .protein)
        try container.encode(carbs, forKey: .carbs)
        try container.encode(fat, forKey: .fat)
        try container.encode(fiber, forKey: .fiber)
        try container.encode(sugar, forKey: .sugar)
        try container.encode(salt, forKey: .salt)
        try container.encode(potassium, forKey: .potassium)
        try container.encodeIfPresent(confidence, forKey: .confidence)
        try container.encodeIfPresent(ingredients, forKey: .ingredients)
    }
}

enum FoodScanError: Error, LocalizedError {
    case imageProcessingFailed
    case analysisTimeout
    case invalidRequest
    case networkError(String)
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .imageProcessingFailed:
            return "Failed to process image"
        case .analysisTimeout:
            return "Analysis took too long"
        case .invalidRequest:
            return "Invalid request format"
        case .networkError(let message):
            return "Network error: \(message)"
        case .apiError(let message):
            return "API error: \(message)"
        }
    }
}

// MARK: - Helper Extensions
extension FoodAnalysisResult {
    /// Converts the analysis result to a LoggedFood object
    func toLoggedFood(servingAmount: Double = 1.0, timestamp: Date = Date()) -> LoggedFood {
        return LoggedFood(
            name: name,
            timestamp: timestamp,
            servingSizeDescription: servingSize,
            servingAmount: servingAmount,
            caloriesPerServing: calories,
            proteinPerServing: protein,
            carbsPerServing: carbs,
            fatPerServing: fat,
            fiberPerServing: fiber,
            sugarPerServing: sugar,
            saltPerServing: salt,
            potassiumPerServing: potassium,
            barcode: nil,
            brand: "AI Analyzed",
            isHalal: false
        )
    }

    /// Generates a deterministic "barcode" for AI-analyzed foods based on normalized name
    /// This allows the same food to be aggregated in master_foods across all users
    func generateAIBarcode() -> String {
        // Normalize the name: lowercase, remove extra spaces, trim
        let normalized = name
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)

        // Create a simple hash-based identifier
        // Using first 32 chars of hex string for reasonable length
        let data = Data(normalized.utf8)
        let hash = data.map { String(format: "%02x", $0) }.joined()
        let truncated = String(hash.prefix(32))

        return "AI-\(truncated)"
    }
}

extension UIImage {
    /// Resizes image to fit within a maximum dimension while maintaining aspect ratio
    nonisolated func resized(toMaxDimension maxDimension: CGFloat) -> UIImage {
        let size = self.size

        // If already smaller, return original
        if size.width <= maxDimension && size.height <= maxDimension {
            return self
        }

        // Calculate new size maintaining aspect ratio
        let ratio = size.width / size.height
        let newSize: CGSize

        if size.width > size.height {
            newSize = CGSize(width: maxDimension, height: maxDimension / ratio)
        } else {
            newSize = CGSize(width: maxDimension * ratio, height: maxDimension)
        }

        // Resize the image
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}

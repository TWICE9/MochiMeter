// Services/AIRunAnalysisService.swift

import Foundation
import UIKit
import Supabase

// MARK: - AI Run Analysis Service
actor AIRunAnalysisService {
    static let shared = AIRunAnalysisService()
    private let client: SupabaseClient

    init(client: SupabaseClient = supabase) {
        self.client = client
    }

    /// Analyzes a run screenshot using Gemini 1.5 Flash (via Edge Function)
    func analyzeRun(image: UIImage) async throws -> RunAnalysisResult {
        
        // 1. Resize image (optimized for text/graph reading, slightly larger max dim)
        // 1200px is good for reading small text on screenshots
        let resizedImage = image.resized(toMaxDimension: 1200)
        
        // 2. Compress
        guard let imageData = resizedImage.jpegData(compressionQuality: 0.8) else {
            throw RunAnalysisError.imageProcessingFailed
        }
        
        let base64String = imageData.base64EncodedString()
        
        // 3. Call Supabase Edge Function
        let requestBody: [String: Any] = ["imageBase64": base64String]
        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            throw RunAnalysisError.invalidRequest
        }
        
        // Call "analyze-run" function
        let response: RunAnalysisResult = try await analyzeWithRetry(body: jsonData, functionName: "analyze-run")
        
        return response
    }
    
    // MARK: - Private Helpers
    
    private func analyzeWithRetry(body: Data, functionName: String, timeout: Double = 20, attempt: Int = 1, maxAttempts: Int = 2) async throws -> RunAnalysisResult {
        do {
            return try await withTimeout(seconds: timeout) {
                let data: Data = try await self.client.functions.invoke(
                    functionName,
                    options: FunctionInvokeOptions(body: body),
                    decode: { data, _ in data }
                )
                return try self.decodeResult(data)
            }
        } catch {
            // Check for server error details first
            if let functionsError = error as? FunctionsError,
               case .httpError(let code, let data) = functionsError {
                // Parse error message from JSON response
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let serverMsg = json["error"] as? String {
                    throw RunAnalysisError.serverError("\(serverMsg)")
                }
                // Fallback if JSON parse fails
                throw RunAnalysisError.serverError("HTTP Error \(code)")
            }

            if attempt < maxAttempts {
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1s wait
                return try await analyzeWithRetry(body: body, functionName: functionName, timeout: timeout, attempt: attempt + 1, maxAttempts: maxAttempts)
            }
            throw error
        }
    }
    
    nonisolated func decodeResult(_ data: Data) throws -> RunAnalysisResult {
        let decoder = JSONDecoder()
        return try decoder.decode(RunAnalysisResult.self, from: data)
    }

    private func withTimeout<T>(seconds: Double, operation: @escaping () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await operation() }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw RunAnalysisError.timeout
            }
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }
}

// MARK: - Models

enum RunAnalysisError: Error, LocalizedError {
    case imageProcessingFailed
    case invalidRequest
    case timeout
    case serverError(String)
    
    var errorDescription: String? {
        switch self {
        case .imageProcessingFailed: return "Failed to process image."
        case .invalidRequest: return "Invalid request."
        case .timeout: return "Analysis timed out."
        case .serverError(let msg): return "Server error: \(msg)"
        }
    }
}

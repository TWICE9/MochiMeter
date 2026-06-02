
// Services/AICoachService.swift

import Foundation
import Supabase

struct CoachContext: Codable, Sendable {
    let currentCalories: Double
    let goalCalories: Double
    let currentProtein: Double
    let goalProtein: Double
    let currentCarbs: Double
    let goalCarbs: Double
    let recentActivity: String
    let readinessStatus: String
}

struct CoachResponse: Decodable, Sendable {
    let reply: String
    
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        reply = try container.decode(String.self, forKey: .reply)
    }
    
    enum CodingKeys: String, CodingKey {
        case reply
    }
}

struct CoachRequest: Encodable, Sendable {
    let message: String
    let history: [HistoryMessage] // New field
    let context: CoachContext
    
    struct HistoryMessage: Encodable, Sendable {
        let role: String
        let content: String
    }
    
    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(message, forKey: .message)
        try container.encode(history, forKey: .history)
        try container.encode(context, forKey: .context)
    }
    
    enum CodingKeys: String, CodingKey {
        case message, history, context
    }
}

actor AICoachService {
    static let shared = AICoachService()
    private let client: SupabaseClient
    
    init(client: SupabaseClient = supabase) {
        self.client = client
    }
    
    func askCoach(message: String, history: [ChatMessage], context: CoachContext) async throws -> String {
        // Convert chat history to simple Encodable format
        // We take the last 10 messages for context window efficiency
        let historyPayload = history.suffix(10).map { msg in
            CoachRequest.HistoryMessage(
                role: msg.isUser ? "user" : "assistant",
                content: msg.text
            )
        }
        
        let request = CoachRequest(
            message: message,
            history: historyPayload,
            context: context
        )
        
        // Invoke the 'health-coach' edge function
        let response: CoachResponse = try await client.functions.invoke(
            "health-coach",
            options: FunctionInvokeOptions(body: request)
        )
        
        return response.reply
    }
}

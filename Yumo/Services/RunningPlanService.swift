//
//  RunningPlanService.swift
//  Yumo
//
//  Calls the `generate-running-plan` Supabase edge function and syncs the
//  newly-created plan + sessions into local SwiftData.
//

import Foundation
@preconcurrency import Supabase
import SwiftData

enum RunningPlanGenerationError: LocalizedError {
    case notAuthenticated
    case rateLimited(nextAllowedAt: Date?)
    case profileIncomplete
    case aiFailure(detail: String?)
    case timedOut
    case unknown(detail: String?)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You need to be signed in to generate a running plan."
        case .rateLimited(let next):
            if let next {
                let formatter = RelativeDateTimeFormatter()
                formatter.unitsStyle = .full
                return "You can generate a new plan \(formatter.localizedString(for: next, relativeTo: Date()))."
            }
            return "You've recently generated a plan. Try again tomorrow."
        case .profileIncomplete:
            return "Finish the running onboarding before generating a plan."
        case .aiFailure(let detail):
            return detail.map { "AI plan generation failed: \($0)" } ?? "AI plan generation failed."
        case .timedOut:
            return "Your plan is taking longer than expected. Check back in a minute — if it still isn't here, try again."
        case .unknown(let detail):
            return detail ?? "Something went wrong generating your plan."
        }
    }
}

struct RunningPlanGenerationResult: Sendable {
    let planId: UUID
    let name: String
    let totalWeeks: Int
    let sessionCount: Int
    let startDate: Date
}

actor RunningPlanService {
    static let shared = RunningPlanService()
    private init() {}

    private let client = supabase

    /// Generate (or regenerate, when `force` is true) the active running plan
    /// for the current user.
    ///
    /// The edge function runs asynchronously (reasoning_effort:"high" can take
    /// 60-120s, which exceeds iOS's URLSession default timeout). This method:
    ///   1. Invokes the function — returns 202 Accepted immediately.
    ///   2. Polls `running_plans` every 3s for a new row authored after the
    ///      request started, up to `pollTimeoutSeconds`.
    ///   3. Calls `syncRunningPlans` once the row appears, then returns.
    func generatePlan(
        force: Bool = false,
        startDate: Date? = nil,
        runDays: [Int]? = nil,
        longRunDayIndex: Int? = nil,
        context: ModelContext,
        pollTimeoutSeconds: TimeInterval = 240
    ) async throws -> RunningPlanGenerationResult {
        // --- Auth precondition ---
        guard let session = try? await client.auth.session else {
            throw RunningPlanGenerationError.notAuthenticated
        }
        let userId = session.user.id.uuidString.lowercased()

        // --- Kick off async generation on the server ---
        // `run_days` (when present) is treated as authoritative on the server —
        // the AI's day_of_week is ignored and sessions are slotted onto these
        // exact days. The client computes them via the same `chooseRunDays`
        // algorithm the preview uses, so what the user sees on the summary
        // page is what gets generated.
        struct Body: Encodable {
            let force: Bool
            let plan_start_date: String?
            let run_days: [Int]?
            let long_run_day_index: Int?
        }
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime]
        let body = Body(
            force: force,
            plan_start_date: startDate.map { isoFormatter.string(from: $0) },
            run_days: runDays,
            long_run_day_index: longRunDayIndex
        )

        // Pull raw Data from the invocation and decode with our ISO-aware
        // decoder. The SDK's default decoder doesn't handle string dates.
        let rawData: Data
        do {
            rawData = try await client.functions.invoke(
                "generate-running-plan",
                options: FunctionInvokeOptions(body: body),
                decode: { data, _ in data }
            )
        } catch let functionError as FunctionsError {
            throw map(functionError)
        } catch {
            throw RunningPlanGenerationError.unknown(detail: error.localizedDescription)
        }

        let accepted: AcceptedResponse
        do {
            accepted = try JSONDecoder.edgeDecoder.decode(AcceptedResponse.self, from: rawData)
        } catch {
            let bodyString = String(data: rawData, encoding: .utf8) ?? "<binary>"
            print("❌ Failed to decode plan-accept response: \(error). Body: \(bodyString)")
            throw RunningPlanGenerationError.unknown(
                detail: "Unexpected response from server: \(bodyString.prefix(200))"
            )
        }

        // --- Poll for the new plan row ---
        let deadline = Date().addingTimeInterval(pollTimeoutSeconds)
        while Date() < deadline {
            try await Task.sleep(nanoseconds: 3_000_000_000) // 3s

            if let plan = try await fetchNewestPlanAfter(
                startedAt: accepted.started_at,
                userId: userId
            ) {
                await CloudSyncManager.shared.syncRunningPlans(userId: userId, context: context)
                return RunningPlanGenerationResult(
                    planId: plan.id,
                    name: plan.name,
                    totalWeeks: plan.total_weeks,
                    sessionCount: plan.session_count,
                    startDate: plan.start_date
                )
            }
        }

        throw RunningPlanGenerationError.timedOut
    }

    // MARK: - Poll helper

    private func fetchNewestPlanAfter(
        startedAt: Date,
        userId: String
    ) async throws -> PlanPollRow? {
        struct PlanRow: Decodable {
            let id: UUID
            let name: String
            let total_weeks: Int
            let start_date: Date
        }
        struct CountRow: Decodable { let id: UUID }

        // Small tolerance to absorb clock skew between client and server.
        let startedMinus2s = startedAt.addingTimeInterval(-2)
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let startedIso = isoFormatter.string(from: startedMinus2s)

        let planRows: [PlanRow] = try await client.database
            .from("running_plans")
            .select("id,name,total_weeks,start_date")
            .eq("user_id", value: userId)
            .eq("status", value: "active")
            .gte("created_at", value: startedIso)
            .order("created_at", ascending: false)
            .limit(1)
            .execute()
            .value

        guard let plan = planRows.first else { return nil }

        // Count sessions to confirm the plan is fully persisted before returning.
        let countResponse = try await client.database
            .from("planned_sessions")
            .select("id", head: false, count: .exact)
            .eq("plan_id", value: plan.id)
            .execute()

        let sessionCount = countResponse.count ?? 0
        // The plan row is only returned if at least one session exists —
        // otherwise we're in the window between plan insert and sessions
        // insert, and polling again will pick it up.
        guard sessionCount > 0 else { return nil }

        return PlanPollRow(
            id: plan.id,
            name: plan.name,
            total_weeks: plan.total_weeks,
            session_count: sessionCount,
            start_date: plan.start_date
        )
    }

    // MARK: - Adapt plan

    /// Calls the `adapt-running-plan` edge function with the given trigger,
    /// then re-syncs the active plan + sessions + adaptations from the cloud
    /// so the UI sees the new state. The edge function is fast (~5-10s) so we
    /// invoke synchronously rather than polling.
    func adaptPlan(
        reason: AdaptationReason,
        signal: AdaptationSignal? = nil,
        force: Bool = false,
        context: ModelContext
    ) async throws -> RunningPlanAdaptationResult {
        guard let session = try? await client.auth.session else {
            throw RunningPlanGenerationError.notAuthenticated
        }
        let userId = session.user.id.uuidString.lowercased()

        struct Body: Encodable {
            let reason: String
            let signal: AdaptationSignal?
            let force: Bool
        }
        let body = Body(reason: reason.rawValue, signal: signal, force: force)

        let rawData: Data
        do {
            rawData = try await client.functions.invoke(
                "adapt-running-plan",
                options: FunctionInvokeOptions(body: body),
                decode: { data, _ in data }
            )
        } catch let functionError as FunctionsError {
            throw map(functionError)
        } catch {
            throw RunningPlanGenerationError.unknown(detail: error.localizedDescription)
        }

        let decoded: AdaptResponse
        do {
            decoded = try JSONDecoder.edgeDecoder.decode(AdaptResponse.self, from: rawData)
        } catch {
            let bodyString = String(data: rawData, encoding: .utf8) ?? "<binary>"
            print("❌ Failed to decode adapt response: \(error). Body: \(bodyString)")
            throw RunningPlanGenerationError.unknown(
                detail: "Unexpected response from server: \(bodyString.prefix(200))"
            )
        }

        // Pull the updated plan + sessions + the new adaptation row down.
        await CloudSyncManager.shared.syncRunningPlans(userId: userId, context: context)

        return RunningPlanAdaptationResult(
            adaptationId: decoded.adaptation_id,
            planId: decoded.plan_id,
            sessionsChanged: decoded.sessions_changed,
            summary: decoded.summary
        )
    }

    private struct AdaptResponse: Decodable, Sendable {
        let adaptation_id: UUID?
        let plan_id: UUID
        let sessions_changed: Int
        let summary: String
    }

    // MARK: - Response models

    private struct AcceptedResponse: Decodable, Sendable {
        let status: String
        let started_at: Date
        let total_weeks: Int
    }

    private struct PlanPollRow: Sendable {
        let id: UUID
        let name: String
        let total_weeks: Int
        let session_count: Int
        let start_date: Date
    }

    private struct EdgeError: Decodable, Sendable {
        let error: String?
        let code: String?
        let next_allowed_at: Date?
        let detail: String?
    }

    // MARK: - Error mapping

    private func map(_ error: FunctionsError) -> RunningPlanGenerationError {
        // The Supabase SDK surfaces the HTTP error body on httpError; try to
        // decode our structured error shape before falling back to a generic.
        switch error {
        case .httpError(_, let data):
            if let decoded = try? JSONDecoder.edgeDecoder.decode(EdgeError.self, from: data) {
                if decoded.code == "rate_limited" {
                    return .rateLimited(nextAllowedAt: decoded.next_allowed_at)
                }
                if decoded.error == "Unauthorized" {
                    return .notAuthenticated
                }
                if decoded.error?.contains("onboarding") == true
                    || decoded.error?.contains("profile") == true {
                    return .profileIncomplete
                }
                return .aiFailure(detail: decoded.error)
            }
            return .unknown(detail: String(data: data, encoding: .utf8))
        case .relayError:
            return .unknown(detail: "Edge relay error")
        @unknown default:
            return .unknown(detail: error.localizedDescription)
        }
    }
}

// MARK: - Shared decoder for ISO8601 dates

private extension JSONDecoder {
    nonisolated(unsafe) static let edgeDecoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)
            let formatters: [ISO8601DateFormatter] = {
                let withFractional = ISO8601DateFormatter()
                withFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                let plain = ISO8601DateFormatter()
                plain.formatOptions = [.withInternetDateTime]
                return [withFractional, plain]
            }()
            for f in formatters {
                if let date = f.date(from: raw) { return date }
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Bad date: \(raw)")
        }
        return d
    }()
}

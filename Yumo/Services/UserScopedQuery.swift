//
//  UserScopedQuery.swift
//  Yumo
//
//  Helper service for fetching user-scoped data from SwiftData
//  Filters data by current userId (or nil for offline users)
//

import Foundation
import SwiftData
import os.signpost

private nonisolated(unsafe) let querySignposter = OSSignposter(subsystem: "com.yumo.perf", category: "UserScopedQuery")

actor UserScopedQuery {

    // MARK: - Food Logs

    static func fetchFoodLogs(context: ModelContext) async -> [LoggedFood] {
        let state = querySignposter.beginInterval("fetchFoodLogs")
        defer { querySignposter.endInterval("fetchFoodLogs", state) }

        let userId = await UserSession.shared.getCurrentUserId()

        let predicate: Predicate<LoggedFood>
        if let userId = userId {
            predicate = #Predicate { $0.userId == userId && $0.recipe == nil }
        } else {
            predicate = #Predicate { $0.userId == nil && $0.recipe == nil }
        }

        let descriptor = FetchDescriptor(
            predicate: predicate,
            sortBy: [SortDescriptor(\LoggedFood.timestamp, order: .reverse)]
        )

        let result = (try? context.fetch(descriptor)) ?? []
        querySignposter.emitEvent("fetchFoodLogs.count", "count=\(result.count)")
        return result
    }

    static func fetchFoodLogsForToday(context: ModelContext) async -> [LoggedFood] {
        let userId = await UserSession.shared.getCurrentUserId()
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        let predicate: Predicate<LoggedFood>
        if let userId = userId {
            predicate = #Predicate { log in
                log.userId == userId &&
                log.timestamp >= startOfDay &&
                log.timestamp < endOfDay &&
                log.recipe == nil
            }
        } else {
            predicate = #Predicate { log in
                log.userId == nil &&
                log.timestamp >= startOfDay &&
                log.timestamp < endOfDay &&
                log.recipe == nil
            }
        }

        let descriptor = FetchDescriptor(
            predicate: predicate,
            sortBy: [SortDescriptor(\LoggedFood.timestamp, order: .reverse)]
        )

        return (try? context.fetch(descriptor)) ?? []
    }

    static func fetchFoodLogsForDate(_ date: Date, context: ModelContext) async -> [LoggedFood] {
        let userId = await UserSession.shared.getCurrentUserId()
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        let predicate: Predicate<LoggedFood>
        if let userId = userId {
            predicate = #Predicate { log in
                log.userId == userId &&
                log.timestamp >= startOfDay &&
                log.timestamp < endOfDay &&
                log.recipe == nil
            }
        } else {
            predicate = #Predicate { log in
                log.userId == nil &&
                log.timestamp >= startOfDay &&
                log.timestamp < endOfDay &&
                log.recipe == nil
            }
        }

        let descriptor = FetchDescriptor(
            predicate: predicate,
            sortBy: [SortDescriptor(\LoggedFood.timestamp, order: .forward)]
        )

        return (try? context.fetch(descriptor)) ?? []
    }

    // MARK: - Water Logs

    static func fetchWaterLogs(context: ModelContext) async -> [LoggedWater] {
        let userId = await UserSession.shared.getCurrentUserId()

        let predicate: Predicate<LoggedWater>
        if let userId = userId {
            predicate = #Predicate { $0.userId == userId }
        } else {
            predicate = #Predicate { $0.userId == nil }
        }

        let descriptor = FetchDescriptor(predicate: predicate)
        return (try? context.fetch(descriptor)) ?? []
    }

    static func fetchWaterLogsForToday(context: ModelContext) async -> [LoggedWater] {
        let userId = await UserSession.shared.getCurrentUserId()
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        let predicate: Predicate<LoggedWater>
        if let userId = userId {
            predicate = #Predicate { log in
                log.userId == userId &&
                log.timestamp >= startOfDay &&
                log.timestamp < endOfDay
            }
        } else {
            predicate = #Predicate { log in
                log.userId == nil &&
                log.timestamp >= startOfDay &&
                log.timestamp < endOfDay
            }
        }

        let descriptor = FetchDescriptor(predicate: predicate)
        return (try? context.fetch(descriptor)) ?? []
    }

    // MARK: - User Goals

    static func fetchUserGoals(context: ModelContext) async -> UserGoals? {
        let state = querySignposter.beginInterval("fetchUserGoals")
        defer { querySignposter.endInterval("fetchUserGoals", state) }

        let userId = await UserSession.shared.getCurrentUserId()

        let predicate: Predicate<UserGoals>
        if let userId = userId {
            predicate = #Predicate { $0.userId == userId }
        } else {
            predicate = #Predicate { $0.userId == nil }
        }

        return try? context.fetch(FetchDescriptor(predicate: predicate)).first
    }

    // MARK: - Running Profile

    static func fetchRunningProfile(context: ModelContext) async -> RunningProfile? {
        let userId = await UserSession.shared.getCurrentUserId()

        let predicate: Predicate<RunningProfile>
        if let userId = userId {
            predicate = #Predicate { $0.userId == userId }
        } else {
            predicate = #Predicate { $0.userId == nil }
        }

        return try? context.fetch(FetchDescriptor(predicate: predicate)).first
    }

    // MARK: - Running Plans

    /// All plans for the current user, newest first.
    static func fetchRunningPlans(context: ModelContext) async -> [RunningPlan] {
        let userId = await UserSession.shared.getCurrentUserId()

        let predicate: Predicate<RunningPlan>
        if let userId = userId {
            predicate = #Predicate { $0.userId == userId }
        } else {
            predicate = #Predicate { $0.userId == nil }
        }

        let descriptor = FetchDescriptor<RunningPlan>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    /// The user's currently active plan, if any.
    static func fetchActiveRunningPlan(context: ModelContext) async -> RunningPlan? {
        let plans = await fetchRunningPlans(context: context)
        return plans.first { $0.status == .active }
    }

    /// Sessions for a specific plan, sorted by scheduled date ascending.
    static func fetchPlannedSessions(for planId: UUID, context: ModelContext) async -> [PlannedSession] {
        let predicate = #Predicate<PlannedSession> { $0.plan?.id == planId }
        let descriptor = FetchDescriptor<PlannedSession>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.scheduledDate, order: .forward)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    // MARK: - Fasting Logs

    static func fetchFastingLogs(context: ModelContext) async -> [FastingLog] {
        let userId = await UserSession.shared.getCurrentUserId()

        let predicate: Predicate<FastingLog>
        if let userId = userId {
            predicate = #Predicate { $0.userId == userId }
        } else {
            predicate = #Predicate { $0.userId == nil }
        }

        let descriptor = FetchDescriptor(
            predicate: predicate,
            sortBy: [SortDescriptor(\FastingLog.startTime, order: .reverse)]
        )

        return (try? context.fetch(descriptor)) ?? []
    }

    static func fetchCurrentFast(context: ModelContext) async -> FastingLog? {
        let userId = await UserSession.shared.getCurrentUserId()

        let predicate: Predicate<FastingLog>
        if let userId = userId {
            predicate = #Predicate { log in
                log.userId == userId && log.endTime == nil
            }
        } else {
            predicate = #Predicate { log in
                log.userId == nil && log.endTime == nil
            }
        }

        let descriptor = FetchDescriptor(predicate: predicate)
        return try? context.fetch(descriptor).first
    }

    // MARK: - Recipes

    static func fetchRecipes(context: ModelContext) async -> [Recipe] {
        let userId = await UserSession.shared.getCurrentUserId()

        let predicate: Predicate<Recipe>
        if let userId = userId {
            predicate = #Predicate { $0.userId == userId }
        } else {
            predicate = #Predicate { $0.userId == nil }
        }

        let descriptor = FetchDescriptor(
            predicate: predicate,
            sortBy: [SortDescriptor(\Recipe.name, order: .forward)]
        )

        return (try? context.fetch(descriptor)) ?? []
    }

    // MARK: - Reminders

    static func fetchReminders(context: ModelContext) async -> [Reminder] {
        let userId = await UserSession.shared.getCurrentUserId()

        let predicate: Predicate<Reminder>
        if let userId = userId {
            predicate = #Predicate { $0.userId == userId }
        } else {
            predicate = #Predicate { $0.userId == nil }
        }

        let descriptor = FetchDescriptor(
            predicate: predicate,
            sortBy: [SortDescriptor(\Reminder.time, order: .forward)]
        )

        return (try? context.fetch(descriptor)) ?? []
    }

    // MARK: - Weight Logs

    static func fetchWeightLogs(context: ModelContext) async -> [LoggedWeight] {
        let userId = await UserSession.shared.getCurrentUserId()

        let predicate: Predicate<LoggedWeight>
        if let userId = userId {
            predicate = #Predicate { $0.userId == userId }
        } else {
            predicate = #Predicate { $0.userId == nil }
        }

        let descriptor = FetchDescriptor(
            predicate: predicate,
            sortBy: [SortDescriptor(\LoggedWeight.timestamp, order: .reverse)]
        )

        return (try? context.fetch(descriptor)) ?? []
    }

    static func fetchLatestWeight(context: ModelContext) async -> LoggedWeight? {
        let logs = await fetchWeightLogs(context: context)
        return logs.first
    }

    static func fetchWeightLogsForRange(from startDate: Date, to endDate: Date, context: ModelContext) async -> [LoggedWeight] {
        let userId = await UserSession.shared.getCurrentUserId()

        let predicate: Predicate<LoggedWeight>
        if let userId = userId {
            predicate = #Predicate { log in
                log.userId == userId &&
                log.timestamp >= startDate &&
                log.timestamp <= endDate
            }
        } else {
            predicate = #Predicate { log in
                log.userId == nil &&
                log.timestamp >= startDate &&
                log.timestamp <= endDate
            }
        }

        let descriptor = FetchDescriptor(
            predicate: predicate,
            sortBy: [SortDescriptor(\LoggedWeight.timestamp, order: .forward)]
        )

        return (try? context.fetch(descriptor)) ?? []
    }
}

//
//  UserScopedQuery.swift
//  Yumo
//
//  Helper service for fetching user-scoped data from SwiftData
//  Filters data by current userId (or nil for offline users)
//

import Foundation
import SwiftData

actor UserScopedQuery {

    // MARK: - Food Logs

    static func fetchFoodLogs(context: ModelContext) async -> [LoggedFood] {
        let userId = await UserSession.shared.getCurrentUserId()

        let predicate: Predicate<LoggedFood>
        if let userId = userId {
            predicate = #Predicate { $0.userId == userId }
        } else {
            predicate = #Predicate { $0.userId == nil }
        }

        let descriptor = FetchDescriptor(
            predicate: predicate,
            sortBy: [SortDescriptor(\LoggedFood.timestamp, order: .reverse)]
        )

        return (try? context.fetch(descriptor)) ?? []
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
                log.timestamp < endOfDay
            }
        } else {
            predicate = #Predicate { log in
                log.userId == nil &&
                log.timestamp >= startOfDay &&
                log.timestamp < endOfDay
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
        let userId = await UserSession.shared.getCurrentUserId()

        let predicate: Predicate<UserGoals>
        if let userId = userId {
            predicate = #Predicate { $0.userId == userId }
        } else {
            predicate = #Predicate { $0.userId == nil }
        }

        return try? context.fetch(FetchDescriptor(predicate: predicate)).first
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
}

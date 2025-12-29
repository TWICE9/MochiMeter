// Services/HistoryManager.swift

import Foundation
import SwiftData

// MARK: - Data Structures

struct DaySummary: Identifiable {
    let id = UUID()
    let date: Date
    let totalCalories: Double
    let totalProtein: Double
    let totalCarbs: Double
    let totalFat: Double
    let metCalorieGoal: Bool
    
    // Calculated for chart/table limits
    let goalCalories: Double
    let goalProtein: Double
    let goalCarbs: Double
    let goalFat: Double
}

// MARK: - Manager Logic

struct HistoryManager {
    
    /// Calculates a summary for a single day's logs.
    /// Note: Filters out recipe ingredients (logs where recipe != nil)
    static func summarize(logs: [LoggedFood], goals: UserGoals) -> DaySummary {
        // Exclude recipe ingredients - only count standalone food logs
        let filteredLogs = logs.filter { $0.recipe == nil }
        
        let calories = filteredLogs.reduce(0) { $0 + $1.totalCalories }
        let protein = filteredLogs.reduce(0) { $0 + $1.totalProtein }
        let carbs = filteredLogs.reduce(0) { $0 + $1.totalCarbs }
        let fat = filteredLogs.reduce(0) { $0 + $1.totalFat }
        let goalMet = calories <= goals.dailyCalories && goals.dailyCalories > 0
        
        return DaySummary(
            date: filteredLogs.first?.timestamp.startOfDay ?? Date().startOfDay,
            totalCalories: calories,
            totalProtein: protein,
            totalCarbs: carbs,
            totalFat: fat,
            metCalorieGoal: goalMet,
            goalCalories: goals.dailyCalories,
            goalProtein: goals.dailyProtein,
            goalCarbs: goals.dailyCarbs,
            goalFat: goals.dailyFat
        )
    }
    
    /// Generates 7 daily summaries for charting (for the last week relative to endDate).
    static func generateLastWeekSummaries(from allLogs: [LoggedFood], goals: UserGoals, endDate: Date = Date()) -> [DaySummary] {
        var summaries: [DaySummary] = []
        let calendar = Calendar.current
        
        // 1. Group all logs by day
        let groupedByDay = Dictionary(grouping: allLogs) { log in
            calendar.startOfDay(for: log.timestamp)
        }
        
        // 2. Iterate through the last 7 days (including endDate)
        for i in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: -i, to: endDate) else { continue }
            let startOfDate = calendar.startOfDay(for: date)
            
            // 3. Get logs for that day, or an empty array if none exist
            let logsForDay = groupedByDay[startOfDate] ?? []
            
            // 4. Summarize
            let summary = summarize(logs: logsForDay, goals: goals)
            
            // If logs were empty, we must ensure the summary is for the correct day
            let finalDate = logsForDay.isEmpty ? startOfDate : summary.date
            
            summaries.append(
                DaySummary(
                    date: finalDate,
                    totalCalories: summary.totalCalories,
                    totalProtein: summary.totalProtein,
                    totalCarbs: summary.totalCarbs,
                    totalFat: summary.totalFat,
                    metCalorieGoal: summary.metCalorieGoal,
                    goalCalories: summary.goalCalories,
                    goalProtein: summary.goalProtein,
                    goalCarbs: summary.goalCarbs,
                    goalFat: summary.goalFat
                )
            )
        }
        
        // Return oldest date first for the chart (0-6 days ago)
        return summaries.reversed()
    }
}

//
//  UsageLimitManager.swift
//  Yumo
//
//  Tracks daily usage counts for free-tier features so non-premium users
//  get a limited amount of AI scans / quick logs per day before hitting
//  the paywall.
//

import Foundation
import SwiftUI
import Combine

@MainActor
final class UsageLimitManager: ObservableObject {
    static let shared = UsageLimitManager()

    // MARK: - Limits (per day, for non-premium users)
    static let dailyAIScanLimit: Int = 3
    static let dailyQuickMealLimit: Int = 3

    // MARK: - Keys
    private enum Key {
        static let aiScanCount = "usage_ai_scan_count"
        static let aiScanDate = "usage_ai_scan_date"
        static let quickMealCount = "usage_quick_meal_count"
        static let quickMealDate = "usage_quick_meal_date"
    }

    // Published so views can reactively re-enable once the counter resets.
    @Published private(set) var aiScanCountToday: Int = 0
    @Published private(set) var quickMealCountToday: Int = 0

    private init() {
        rolloverIfNeeded()
    }

    // MARK: - Public API

    func canUseAIScan() -> Bool {
        rolloverIfNeeded()
        return aiScanCountToday < Self.dailyAIScanLimit
    }

    func canUseQuickMeal() -> Bool {
        rolloverIfNeeded()
        return quickMealCountToday < Self.dailyQuickMealLimit
    }

    func recordAIScan() {
        rolloverIfNeeded()
        aiScanCountToday += 1
        UserDefaults.standard.set(aiScanCountToday, forKey: Key.aiScanCount)
        UserDefaults.standard.set(todayKey, forKey: Key.aiScanDate)
    }

    func recordQuickMeal() {
        rolloverIfNeeded()
        quickMealCountToday += 1
        UserDefaults.standard.set(quickMealCountToday, forKey: Key.quickMealCount)
        UserDefaults.standard.set(todayKey, forKey: Key.quickMealDate)
    }

    var aiScansRemaining: Int {
        max(0, Self.dailyAIScanLimit - aiScanCountToday)
    }

    var quickMealsRemaining: Int {
        max(0, Self.dailyQuickMealLimit - quickMealCountToday)
    }

    // MARK: - Rollover

    /// Local-day key (YYYY-MM-DD) so we reset at the user's local midnight.
    private var todayKey: String {
        let df = DateFormatter()
        df.calendar = Calendar.current
        df.timeZone = TimeZone.current
        df.dateFormat = "yyyy-MM-dd"
        return df.string(from: Date())
    }

    private func rolloverIfNeeded() {
        let today = todayKey
        let defaults = UserDefaults.standard

        let lastScanDate = defaults.string(forKey: Key.aiScanDate)
        if lastScanDate == today {
            aiScanCountToday = defaults.integer(forKey: Key.aiScanCount)
        } else {
            aiScanCountToday = 0
            defaults.set(0, forKey: Key.aiScanCount)
            defaults.set(today, forKey: Key.aiScanDate)
        }

        let lastQuickMealDate = defaults.string(forKey: Key.quickMealDate)
        if lastQuickMealDate == today {
            quickMealCountToday = defaults.integer(forKey: Key.quickMealCount)
        } else {
            quickMealCountToday = 0
            defaults.set(0, forKey: Key.quickMealCount)
            defaults.set(today, forKey: Key.quickMealDate)
        }
    }
}

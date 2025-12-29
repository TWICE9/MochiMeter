//
//  HealthKitManager.swift
//  Yumo
//

import Foundation
import HealthKit
import Combine

@MainActor
class HealthKitManager: ObservableObject {
    static let shared = HealthKitManager()

    private let healthStore = HKHealthStore()
    @Published var isAuthorized = false

    // Today's data
    @Published var todaySteps: Double = 0
    @Published var todayBurntCalories: Double = 0
    @Published var todayActiveMinutes: Double = 0

    // Weekly data
    @Published var weeklyBurntCalories: [(date: Date, calories: Double)] = []

    // Weight data
    @Published var latestWeight: Double? = nil
    @Published var weightHistory: [(date: Date, weightKg: Double)] = []

    private init() {}

    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("HealthKit is not available on this device")
            throw HealthKitError.notAvailable
        }

        let typesToRead: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .appleExerciseTime)!,
            HKObjectType.quantityType(forIdentifier: .bodyMass)!
        ]

        let typesToWrite: Set<HKSampleType> = [
            HKQuantityType.quantityType(forIdentifier: .bodyMass)!
        ]

        try await healthStore.requestAuthorization(toShare: typesToWrite, read: typesToRead)
        isAuthorized = true
        print("✅ HealthKit authorization granted")
    }

    // MARK: - Fetch Today's Data
    func fetchTodayActivity() async {
        await fetchActivity(for: Date())
    }

    // MARK: - Fetch Activity for Specific Date
    func fetchActivity(for date: Date) async {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay: Date

        // If it's today, use current time; otherwise use end of day
        if calendar.isDateInToday(date) {
            endOfDay = Date()
        } else {
            endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
        }

        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)

        // Fetch steps
        if let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) {
            let steps = await fetchSum(for: stepType, predicate: predicate, unit: .count())
            self.todaySteps = steps
        }

        // Fetch burnt calories
        if let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
            let calories = await fetchSum(for: energyType, predicate: predicate, unit: .kilocalorie())
            self.todayBurntCalories = calories
        }

        // Fetch active minutes
        if let exerciseType = HKQuantityType.quantityType(forIdentifier: .appleExerciseTime) {
            let minutes = await fetchSum(for: exerciseType, predicate: predicate, unit: .minute())
            self.todayActiveMinutes = minutes
        }
    }

    // MARK: - Fetch Weekly Burnt Calories
    func fetchWeeklyBurntCalories(endDate: Date = Date()) async {
        guard let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else { return }

        let calendar = Calendar.current
        guard let startDate = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: endDate)) else { return }

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let interval = DateComponents(day: 1)
        let anchorDate = calendar.startOfDay(for: endDate)

        let data = await fetchStatisticsCollection(
            for: energyType,
            predicate: predicate,
            interval: interval,
            anchorDate: anchorDate,
            startDate: startDate,
            endDate: endDate,
            unit: .kilocalorie()
        )

        self.weeklyBurntCalories = data
    }

    // MARK: - Helper Methods
    private func fetchSum(for quantityType: HKQuantityType, predicate: NSPredicate, unit: HKUnit) async -> Double {
        await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: quantityType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, error in
                if let error = error {
                    print("HealthKit query error: \(error.localizedDescription)")
                    continuation.resume(returning: 0)
                    return
                }
                let value = result?.sumQuantity()?.doubleValue(for: unit) ?? 0
                continuation.resume(returning: value)
            }
            healthStore.execute(query)
        }
    }

    private func fetchStatisticsCollection(
        for quantityType: HKQuantityType,
        predicate: NSPredicate,
        interval: DateComponents,
        anchorDate: Date,
        startDate: Date,
        endDate: Date,
        unit: HKUnit
    ) async -> [(date: Date, calories: Double)] {
        await withCheckedContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: quantityType,
                quantitySamplePredicate: predicate,
                anchorDate: anchorDate,
                intervalComponents: interval
            )

            query.initialResultsHandler = { _, results, error in
                guard let statsCollection = results else {
                    print("HealthKit collection error: \(error?.localizedDescription ?? "Unknown")")
                    continuation.resume(returning: [])
                    return
                }

                var data: [(Date, Double)] = []
                statsCollection.enumerateStatistics(from: startDate, to: endDate) { stats, _ in
                    let value = stats.sumQuantity()?.doubleValue(for: unit) ?? 0
                    data.append((stats.startDate, value))
                }
                continuation.resume(returning: data)
            }

            healthStore.execute(query)
        }
    }

    // MARK: - Weight Methods

    /// Fetches the most recent weight from HealthKit
    func fetchLatestWeight() async {
        guard let weightType = HKQuantityType.quantityType(forIdentifier: .bodyMass) else { return }

        let weight: Double? = await withCheckedContinuation { continuation in
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let query = HKSampleQuery(
                sampleType: weightType,
                predicate: nil,
                limit: 1,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                guard let sample = samples?.first as? HKQuantitySample else {
                    if let error = error {
                        print("HealthKit weight fetch error: \(error.localizedDescription)")
                    }
                    continuation.resume(returning: nil)
                    return
                }
                let weightKg = sample.quantity.doubleValue(for: .gramUnit(with: .kilo))
                continuation.resume(returning: weightKg)
            }
            healthStore.execute(query)
        }

        self.latestWeight = weight
    }

    /// Fetches weight history for the last N days
    func fetchWeightHistory(days: Int = 30) async {
        guard let weightType = HKQuantityType.quantityType(forIdentifier: .bodyMass) else { return }

        let calendar = Calendar.current
        let now = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -days, to: calendar.startOfDay(for: now)) else { return }

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: now, options: .strictStartDate)

        let history: [(date: Date, weightKg: Double)] = await withCheckedContinuation { continuation in
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: true)
            let query = HKSampleQuery(
                sampleType: weightType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                guard let samples = samples as? [HKQuantitySample] else {
                    if let error = error {
                        print("HealthKit weight history error: \(error.localizedDescription)")
                    }
                    continuation.resume(returning: [])
                    return
                }
                let data = samples.map { sample in
                    (date: sample.endDate, weightKg: sample.quantity.doubleValue(for: .gramUnit(with: .kilo)))
                }
                continuation.resume(returning: data)
            }
            healthStore.execute(query)
        }

        self.weightHistory = history
    }

    /// Saves a weight entry to HealthKit
    func saveWeight(_ weightKg: Double, date: Date = Date()) async throws {
        guard let weightType = HKQuantityType.quantityType(forIdentifier: .bodyMass) else {
            throw HealthKitError.notAvailable
        }

        let quantity = HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: weightKg)
        let sample = HKQuantitySample(type: weightType, quantity: quantity, start: date, end: date)

        try await healthStore.save(sample)
        print("✅ Weight saved to HealthKit: \(weightKg) kg")

        // Refresh the latest weight
        await fetchLatestWeight()
    }
}

enum HealthKitError: Error {
    case notAvailable
}

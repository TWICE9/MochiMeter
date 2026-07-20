//
//  HealthKitManager.swift
//  Yumo
//

import Foundation
import HealthKit
import CoreLocation
import Combine
import os.signpost
import WidgetKit

private let hkSignposter = OSSignposter(subsystem: "com.yumo.perf", category: "HealthKitManager")

@MainActor
class HealthKitManager: ObservableObject {
    static let shared = HealthKitManager()

    let healthStore = HKHealthStore()

    // All publishable health state lives in one snapshot so SwiftUI sees a single
    // dependency edge per observer instead of one per field. Callers read fields
    // through the forwarding accessors below; internal writers update `snapshot`
    // (use the `update { ... }` helper for multi-field changes to coalesce into
    // one publish).
    @Published var snapshot = HealthSnapshot()

    /// Build a draft from the current snapshot, mutate it, and assign back as a
    /// single publish. Use this when a fetch updates more than one field.
    func update(_ mutate: (inout HealthSnapshot) -> Void) {
        var draft = snapshot
        mutate(&draft)
        snapshot = draft
    }

    // MARK: - Snapshot field forwarders (read-only public API)

    var isAuthorized: Bool { snapshot.isAuthorized }

    var todaySteps: Double { snapshot.todaySteps }
    var todayBurntCalories: Double { snapshot.todayBurntCalories }
    var todayActiveMinutes: Double { snapshot.todayActiveMinutes }

    var weeklyBurntCalories: [(date: Date, calories: Double)] { snapshot.weeklyBurntCalories }

    var latestWeight: Double? { snapshot.latestWeight }
    var weightHistory: [(date: Date, weightKg: Double)] { snapshot.weightHistory }

    var profileHeight: Double? { snapshot.profileHeight }
    var profileDateOfBirth: Date? { snapshot.profileDateOfBirth }
    var profileBiologicalSex: HKBiologicalSex? { snapshot.profileBiologicalSex }

    var lastNightSleep: SleepData? { snapshot.lastNightSleep }
    var weeklySleep: [SleepData] { snapshot.weeklySleep }

    var latestHRV: Double? { snapshot.latestHRV }
    var weeklyHRV: [(date: Date, hrv: Double)] { snapshot.weeklyHRV }
    var averageHRV: Double? { snapshot.averageHRV }

    var latestRestingHR: Double? { snapshot.latestRestingHR }
    var weeklyRestingHR: [(date: Date, hr: Double)] { snapshot.weeklyRestingHR }

    var recoveryScore: Int? { snapshot.recoveryScore }
    var recoveryStatus: RecoveryStatus { snapshot.recoveryStatus }

    var todayWorkouts: [WorkoutSummary] { snapshot.todayWorkouts }
    var weeklyWorkouts: [WorkoutSummary] { snapshot.weeklyWorkouts }

    var thisWeekRunKm: Double { snapshot.thisWeekRunKm }
    var weeklyRunStreak: Int { snapshot.weeklyRunStreak }

    var recentAvgWeeklyRunKm: Double { snapshot.recentAvgWeeklyRunKm }
    var lastWeekRunKm: Double { snapshot.lastWeekRunKm }
    var recentMaxLongRunKm: Double { snapshot.recentMaxLongRunKm }

    var personalBests: [PersonalBest] { snapshot.personalBests }

    var strainScore: Double? { snapshot.strainScore }
    var weeklyStrain: [(date: Date, strain: Double)] { snapshot.weeklyStrain }
    var weeklyRecovery: [(date: Date, score: Int)] { snapshot.weeklyRecovery }
    var weeklyRecoverySleep: [(date: Date, sleepHours: Double, recovery: Int, strain: Double)] { snapshot.weeklyRecoverySleep }

    // MARK: - Cache Trackers
    private var lastRecoveryFetch: Date?
    private var lastStrainFetch: Date?
    private var lastWeeklyRunStatsFetch: Date?
    private var lastPersonalBestsFetch: Date?
    
    private var lastActivityFetchDate: Date?
    private var lastActivityFetchTime: Date?
    
    private var lastWeeklyCalFetchDate: Date?
    private var lastWeeklyCalFetchTime: Date?

    // How long (seconds) before we consider data stale and re-fetch.
    // Conservative values: today's activity = 5 min, heavy 730-day scans = 30 min.
    private static let activityTTL: TimeInterval   = 5 * 60
    private static let heavyScanTTL: TimeInterval  = 30 * 60

    private init() {}
    
    // MARK: - App Launch Prefetch
    
    /// Called on app launch to warm up the cache.
    /// Fetches all heavy data once so navigating to the Activity screen is instant.
    func prefetchAllData() async {
        let prefetchState = hkSignposter.beginInterval("prefetchAllData")
        defer { hkSignposter.endInterval("prefetchAllData", prefetchState) }

        try? await requestAuthorization()

        guard isAuthorized else {
            print("🚫 Skipping HealthKit prefetch: Not authorized")
            return
        }

        print("🔄 Starting HealthKit background prefetch...")
        let start = Date()

        async let recoveryTask: ()       = fetchRecoveryData()
        async let strainTask: ()         = fetchStrainData()
        async let activityTask: ()       = fetchTodayActivity()
        async let personalBestsTask: () = refreshPersonalBests()

        _ = await (recoveryTask, strainTask, activityTask, personalBestsTask)

        shareReadinessToWidget()

        print("✅ HealthKit prefetch complete in \(String(format: "%.2f", Date().timeIntervalSince(start)))s")
    }

    /// Pushes the current recovery / sleep / strain values to the App Group so
    /// the running readiness widget can display them without HealthKit access.
    func shareReadinessToWidget() {
        guard let defaults = UserDefaults(suiteName: "group.com.jesseta.yumo") else { return }
        defaults.set(recoveryScore ?? -1, forKey: "readiness_recovery")
        defaults.set(strainScore ?? -1, forKey: "readiness_strain")
        let sleepHours = (lastNightSleep?.totalSleepSeconds ?? 0) / 3600.0
        defaults.set(sleepHours, forKey: "readiness_sleep_hours")
        defaults.set(Date().timeIntervalSince1970, forKey: "readiness_updated_at")
        WidgetCenter.shared.reloadTimelines(ofKind: "RunningReadinessWidget")
    }

    func requestAuthorization() async throws {
        if isAuthorized { return }

        guard HKHealthStore.isHealthDataAvailable() else {
            print("HealthKit is not available on this device")
            throw HealthKitError.notAvailable
        }

        let typesToRead: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .appleExerciseTime)!,
            HKObjectType.quantityType(forIdentifier: .bodyMass)!,
            HKObjectType.quantityType(forIdentifier: .height)!,
            HKObjectType.characteristicType(forIdentifier: .dateOfBirth)!,
            HKObjectType.characteristicType(forIdentifier: .biologicalSex)!,
            // Phase 1: Sleep, HRV & Recovery
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
            HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
            HKObjectType.quantityType(forIdentifier: .restingHeartRate)!,
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            // Phase 2: Workouts & Strain
            HKObjectType.workoutType(),
            HKSeriesType.workoutRoute(),
            HKObjectType.quantityType(forIdentifier: .flightsClimbed)!,
            // Run analytics (iOS 16+)
            HKObjectType.quantityType(forIdentifier: .runningSpeed)!
        ]

        let typesToWrite: Set<HKSampleType> = [
            HKQuantityType.quantityType(forIdentifier: .bodyMass)!
        ]

        try await healthStore.requestAuthorization(toShare: typesToWrite, read: typesToRead)
        snapshot.isAuthorized = true
        print("✅ HealthKit authorization granted")
    }
    
    // MARK: - Fetch Profile Data for Onboarding
    
    /// Fetches user profile data (weight, height, DOB, sex) for onboarding pre-fill
    func fetchProfileForOnboarding() async -> (weight: Double?, height: Double?, dob: Date?, sex: HKBiologicalSex?) {
        // Fetch weight
        await fetchLatestWeight()
        let weight = latestWeight

        let height = await fetchLatestHeight()
        let dob = fetchDateOfBirth()
        let sex = fetchBiologicalSex()

        update {
            $0.profileHeight = height
            $0.profileDateOfBirth = dob
            $0.profileBiologicalSex = sex
        }
        
        print("📊 HealthKit Profile Data:")
        print("   - Weight: \(weight.map { "\($0) kg" } ?? "N/A")")
        print("   - Height: \(height.map { "\($0) cm" } ?? "N/A")")
        print("   - DOB: \(dob.map { "\($0)" } ?? "N/A")")
        print("   - Sex: \(sex.map { "\($0.rawValue)" } ?? "N/A")")
        
        return (weight, height, dob, sex)
    }
    
    /// Fetches the most recent height from HealthKit
    private func fetchLatestHeight() async -> Double? {
        guard let heightType = HKQuantityType.quantityType(forIdentifier: .height) else { return nil }

        return await withCheckedContinuation { continuation in
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let query = HKSampleQuery(
                sampleType: heightType,
                predicate: nil,
                limit: 1,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                guard let sample = samples?.first as? HKQuantitySample else {
                    if let error = error {
                        print("HealthKit height fetch error: \(error.localizedDescription)")
                    }
                    continuation.resume(returning: nil)
                    return
                }
                let heightCm = sample.quantity.doubleValue(for: .meterUnit(with: .centi))
                continuation.resume(returning: heightCm)
            }
            healthStore.execute(query)
        }
    }
    
    /// Fetches date of birth from HealthKit characteristics
    private func fetchDateOfBirth() -> Date? {
        do {
            let dobComponents = try healthStore.dateOfBirthComponents()
            return Calendar.current.date(from: dobComponents)
        } catch {
            print("HealthKit DOB fetch error: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Fetches biological sex from HealthKit characteristics
    private func fetchBiologicalSex() -> HKBiologicalSex? {
        do {
            let sex = try healthStore.biologicalSex()
            return sex.biologicalSex
        } catch {
            print("HealthKit sex fetch error: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Fetch Today's Data
    func fetchTodayActivity() async {
        let state = hkSignposter.beginInterval("fetchTodayActivity")
        await fetchActivity(for: Date())
        hkSignposter.endInterval("fetchTodayActivity", state)
    }

    // MARK: - Fetch Activity for Specific Date
    func fetchActivity(for date: Date) async {
        // Check cache (5 min throttle for same date)
        if let lastDate = lastActivityFetchDate,
           Calendar.current.isDate(lastDate, inSameDayAs: date),
           let lastTime = lastActivityFetchTime,
           Date().timeIntervalSince(lastTime) < 300 {
            return
        }

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

        var steps: Double?
        var calories: Double?
        var minutes: Double?

        if let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) {
            steps = await fetchSum(for: stepType, predicate: predicate, unit: .count())
        }
        if let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
            calories = await fetchSum(for: energyType, predicate: predicate, unit: .kilocalorie())
        }
        if let exerciseType = HKQuantityType.quantityType(forIdentifier: .appleExerciseTime) {
            minutes = await fetchSum(for: exerciseType, predicate: predicate, unit: .minute())
        }

        update {
            if let steps { $0.todaySteps = steps }
            if let calories { $0.todayBurntCalories = calories }
            if let minutes { $0.todayActiveMinutes = minutes }
        }

        self.lastActivityFetchDate = date
        self.lastActivityFetchTime = Date()
    }

    // MARK: - Fetch Weekly Burnt Calories
    func fetchWeeklyBurntCalories(endDate: Date = Date()) async {
        // Check cache
        if let lastDate = lastWeeklyCalFetchDate,
           Calendar.current.isDate(lastDate, inSameDayAs: endDate),
           let lastTime = lastWeeklyCalFetchTime,
           Date().timeIntervalSince(lastTime) < 300 {
            return
        }

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

        self.snapshot.weeklyBurntCalories = data
        
        self.lastWeeklyCalFetchDate = endDate
        self.lastWeeklyCalFetchTime = Date()
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

    /// Fetches the average heart rate during a workout's time range
    func fetchAvgHeartRate(for workout: HKWorkout) async -> Int? {
        guard let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return nil }
        
        // Use a time-based predicate because third-party apps like Strava might not link samples directly to the workout object
        let predicate = HKQuery.predicateForSamples(withStart: workout.startDate, end: workout.endDate, options: .strictStartDate)
        
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: hrType,
                quantitySamplePredicate: predicate,
                options: .discreteAverage
            ) { _, result, error in
                if let avg = result?.averageQuantity() {
                    let bpm = avg.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                    continuation.resume(returning: Int(bpm))
                } else {
                    continuation.resume(returning: nil)
                }
            }
            healthStore.execute(query)
        }
    }
    
    /// Fetches elevation gain during a workout by accumulating flights climbed or elevation data
    func fetchElevationGain(for workout: HKWorkout) async -> Double? {
        guard let flightsType = HKQuantityType.quantityType(forIdentifier: .flightsClimbed) else { return nil }
        let predicate = HKQuery.predicateForSamples(withStart: workout.startDate, end: workout.endDate, options: .strictStartDate)
        
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: flightsType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, error in
                if let sum = result?.sumQuantity() {
                    let flights = sum.doubleValue(for: .count())
                    // Apple Health defines 1 flight as ~3 meters of elevation
                    continuation.resume(returning: flights * 3.0)
                } else {
                    continuation.resume(returning: nil)
                }
            }
            healthStore.execute(query)
        }
    }

    // MARK: - Route Methods

    /// Best-effort fetch of avg HR and elevation gain for a `LoggedRun` by locating the
    /// matching HKWorkout via fuzzy date+distance match (same heuristic as `fetchRoute(matching:)`).
    /// Returns `nil` for any value HealthKit can't provide. Used as a fallback when the
    /// `LoggedRun` was synthesized before the HK fallback queries had populated the workout summary.
    func fetchMetrics(matching run: LoggedRun) async -> (avgHeartRate: Int?, elevationMeters: Int?) {
        guard HKHealthStore.isHealthDataAvailable() else { return (nil, nil) }

        // Plan-session runs store `runDate` as the scheduled 06:00 UTC slot, which can
        // sit on a different local calendar day than the actual workout. Search a ±1 day
        // window around `runDate` and let the distance match pick the right workout.
        let cal = Calendar.current
        let dayStart = cal.date(byAdding: .day, value: -1, to: cal.startOfDay(for: run.runDate)) ?? run.runDate
        guard let dayEnd = cal.date(byAdding: .day, value: 2, to: cal.startOfDay(for: run.runDate)) else { return (nil, nil) }
        let predicate = HKQuery.predicateForSamples(withStart: dayStart, end: dayEnd, options: [])

        let workouts: [HKWorkout] = await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HKObjectType.workoutType(),
                predicate: predicate,
                limit: 50,
                sortDescriptors: nil
            ) { _, results, _ in
                continuation.resume(returning: (results as? [HKWorkout]) ?? [])
            }
            healthStore.execute(query)
        }

        let targetMeters = run.distanceKm * 1000
        let runningOnly = workouts.filter { $0.workoutActivityType == .running }
        let candidates = runningOnly.isEmpty ? workouts : runningOnly
        guard let workout = candidates.min(by: {
            let dA = abs(($0.totalDistance?.doubleValue(for: .meter()) ?? 0) - targetMeters)
            let dB = abs(($1.totalDistance?.doubleValue(for: .meter()) ?? 0) - targetMeters)
            return dA < dB
        }) else {
            print("🏃 fetchMetrics: no workout candidate found in ±1 day window for run on \(run.runDate)")
            return (nil, nil)
        }

        print("🏃 fetchMetrics: matched workout from \(workout.sourceRevision.source.name) at \(workout.startDate), distance=\((workout.totalDistance?.doubleValue(for: .meter()) ?? 0) / 1000)km vs target=\(run.distanceKm)km")

        var avgHR: Int? = nil
        if let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate),
           let stats = workout.statistics(for: hrType),
           let avg = stats.averageQuantity() {
            avgHR = Int(avg.doubleValue(for: HKUnit.count().unitDivided(by: .minute())))
        }
        if avgHR == nil {
            avgHR = await fetchAvgHeartRate(for: workout)
        }

        var elev: Double? = nil
        if let q = workout.metadata?[HKMetadataKeyElevationAscended] as? HKQuantity {
            elev = q.doubleValue(for: .meter())
        }
        if elev == nil || elev == 0 {
            elev = await fetchElevationGain(for: workout)
        }
        if elev == nil || elev == 0 {
            // Last resort: integrate positive altitude deltas from the GPS route.
            // Catches third-party syncs (Huawei, etc.) that include the route but
            // skip `HKMetadataKeyElevationAscended` and `flightsClimbed`.
            elev = await fetchElevationFromRoute(for: workout)
        }

        print("🏃 fetchMetrics: result avgHR=\(avgHR.map(String.init) ?? "nil"), elevation=\(elev.map { String(format: "%.1fm", $0) } ?? "nil")")

        return (avgHR, elev.map { Int($0) })
    }

    /// Computes elevation gain by streaming the workout's GPS route and summing
    /// positive altitude deltas (with light smoothing + a noise threshold).
    /// Returns `nil` if the workout has no route or no usable altitude data.
    private func fetchElevationFromRoute(for workout: HKWorkout) async -> Double? {
        let routeType = HKSeriesType.workoutRoute()

        let linkedPredicate = HKQuery.predicateForObjects(from: workout)
        var routes: [HKWorkoutRoute] = await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: routeType,
                predicate: linkedPredicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, results, _ in
                continuation.resume(returning: (results as? [HKWorkoutRoute]) ?? [])
            }
            healthStore.execute(query)
        }

        if routes.isEmpty {
            let timePredicate = HKQuery.predicateForSamples(
                withStart: workout.startDate,
                end: workout.endDate,
                options: .strictStartDate
            )
            routes = await withCheckedContinuation { continuation in
                let query = HKSampleQuery(
                    sampleType: routeType,
                    predicate: timePredicate,
                    limit: 1,
                    sortDescriptors: nil
                ) { _, results, _ in
                    continuation.resume(returning: (results as? [HKWorkoutRoute]) ?? [])
                }
                healthStore.execute(query)
            }
        }

        guard let route = routes.first else { return nil }

        final class Accumulator: @unchecked Sendable {
            var altitudes: [Double] = []
        }
        let acc = Accumulator()

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            var resumed = false
            let query = HKWorkoutRouteQuery(route: route) { _, locations, done, _ in
                if let locations {
                    for loc in locations where loc.verticalAccuracy >= 0 {
                        acc.altitudes.append(loc.altitude)
                    }
                }
                if done && !resumed {
                    resumed = true
                    continuation.resume()
                }
            }
            healthStore.execute(query)
        }

        let altitudes = acc.altitudes
        guard altitudes.count > 1 else { return nil }

        // Light moving-average smoothing to suppress GPS jitter
        let windowRadius = 2
        var smoothed: [Double] = []
        smoothed.reserveCapacity(altitudes.count)
        for i in 0..<altitudes.count {
            let lo = max(0, i - windowRadius)
            let hi = min(altitudes.count, i + windowRadius + 1)
            let slice = altitudes[lo..<hi]
            smoothed.append(slice.reduce(0, +) / Double(slice.count))
        }

        // Sum positive altitude deltas only when a sustained climb exceeds the noise threshold
        let noiseThreshold: Double = 1.0 // meters
        var totalGain: Double = 0
        var pendingGain: Double = 0
        for i in 1..<smoothed.count {
            let delta = smoothed[i] - smoothed[i - 1]
            if delta > 0 {
                pendingGain += delta
            } else if delta < 0 {
                if pendingGain >= noiseThreshold { totalGain += pendingGain }
                pendingGain = 0
            }
        }
        if pendingGain >= noiseThreshold { totalGain += pendingGain }

        print("🏃 fetchElevationFromRoute: route had \(altitudes.count) altitude points → \(String(format: "%.1f", totalGain))m gain")
        return totalGain > 0 ? totalGain : nil
    }

    /// Finds the HealthKit running workout that matches a LoggedRun by date and distance,
    /// then returns the GPS polyline coordinates recorded by that workout.
    /// Returns an empty array for indoor runs, plan sessions, or any run without GPS data.
    func fetchRoute(matching run: LoggedRun) async -> [CLLocationCoordinate2D] {
        guard HKHealthStore.isHealthDataAvailable() else { return [] }

        let tolerance: TimeInterval = 5 * 60
        let start = run.runDate.addingTimeInterval(-tolerance)
        let end = run.runDate.addingTimeInterval(run.durationMinutes * 60 + tolerance)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [])

        let workouts: [HKWorkout] = await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HKObjectType.workoutType(),
                predicate: predicate,
                limit: 10,
                sortDescriptors: nil
            ) { _, results, _ in
                continuation.resume(returning: (results as? [HKWorkout]) ?? [])
            }
            healthStore.execute(query)
        }

        let targetMeters = run.distanceKm * 1000
        // Prefer .running workouts; fall back to any type so third-party apps aren't missed.
        let runningOnly = workouts.filter { $0.workoutActivityType == .running }
        let candidates = runningOnly.isEmpty ? workouts : runningOnly
        guard let match = candidates.min(by: {
            let dA = abs(($0.totalDistance?.doubleValue(for: .meter()) ?? 0) - targetMeters)
            let dB = abs(($1.totalDistance?.doubleValue(for: .meter()) ?? 0) - targetMeters)
            return dA < dB
        }) else {
            print("🗺️ fetchRoute: no candidate workout found (checked \(workouts.count) total)")
            return []
        }

        print("🗺️ fetchRoute: matched workout from \(match.sourceRevision.source.name), type=\(match.workoutActivityType.rawValue)")
        return await fetchRouteCoordinates(for: match)
    }

    /// Fetches the GPS route for an HKWorkout identified by its exact UUID.
    /// This is more reliable than the date/distance fuzzy match.
    func fetchRoute(byHKWorkoutUUID uuid: UUID) async -> [CLLocationCoordinate2D] {
        guard HKHealthStore.isHealthDataAvailable() else { return [] }

        let predicate = HKQuery.predicateForObjects(with: Set([uuid]))
        let workouts: [HKWorkout] = await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HKObjectType.workoutType(),
                predicate: predicate,
                limit: 1,
                sortDescriptors: nil
            ) { _, results, _ in
                continuation.resume(returning: (results as? [HKWorkout]) ?? [])
            }
            healthStore.execute(query)
        }

        guard let workout = workouts.first else {
            print("🗺️ fetchRoute(byUUID): no workout found for UUID \(uuid)")
            return []
        }
        print("🗺️ fetchRoute(byUUID): found workout from \(workout.sourceRevision.source.name)")
        return await fetchRouteCoordinates(for: workout)
    }

    func fetchRouteCoordinates(for workout: HKWorkout) async -> [CLLocationCoordinate2D] {
        let routeType = HKSeriesType.workoutRoute()

        // Primary: routes linked directly to the workout object (Apple Watch native, Apple Fitness+)
        let linkedPredicate = HKQuery.predicateForObjects(from: workout)
        var routes: [HKWorkoutRoute] = await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: routeType,
                predicate: linkedPredicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, results, _ in
                continuation.resume(returning: (results as? [HKWorkoutRoute]) ?? [])
            }
            healthStore.execute(query)
        }

        // Fallback: routes that overlap the workout's time range (some third-party apps like Garmin)
        if routes.isEmpty {
            print("🗺️ No linked routes found — trying time-based fallback")
            let timePredicate = HKQuery.predicateForSamples(
                withStart: workout.startDate,
                end: workout.endDate,
                options: .strictStartDate
            )
            routes = await withCheckedContinuation { continuation in
                let query = HKSampleQuery(
                    sampleType: routeType,
                    predicate: timePredicate,
                    limit: 1,
                    sortDescriptors: nil
                ) { _, results, _ in
                    continuation.resume(returning: (results as? [HKWorkoutRoute]) ?? [])
                }
                healthStore.execute(query)
            }
        }

        guard let route = routes.first else {
            print("🗺️ No HKWorkoutRoute found for workout from \(workout.sourceRevision.source.name)")
            return []
        }

        // @unchecked Sendable: HealthKit serializes route callbacks so no data race occurs.
        final class Accumulator: @unchecked Sendable {
            var coordinates: [CLLocationCoordinate2D] = []
        }
        let accumulator = Accumulator()

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            var resumed = false
            let query = HKWorkoutRouteQuery(route: route) { _, locations, done, _ in
                if let locations {
                    accumulator.coordinates.append(contentsOf: locations.map(\.coordinate))
                }
                if done && !resumed {
                    resumed = true
                    continuation.resume()
                }
            }
            healthStore.execute(query)
        }

        return accumulator.coordinates
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

        self.snapshot.latestWeight = weight
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

        self.snapshot.weightHistory = history
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
    
    // MARK: - Phase 1: Sleep Tracking
    
    /// Fetches last night's sleep data from HealthKit
    func fetchLastNightSleep() async {
        guard let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else { return }
        
        let calendar = Calendar.current
        let now = Date()
        
        // Define "Last Night" window:
        // From: Yesterday at 6:00 PM
        // To: Now
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
              let startLookback = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: yesterday) else { return }
        
        let predicate = HKQuery.predicateForSamples(withStart: startLookback, end: now, options: .strictEndDate)
        
        let samples: [HKCategorySample] = await withCheckedContinuation { continuation in
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: true)
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, results, error in
                guard let samples = results as? [HKCategorySample] else {
                    if let error = error {
                        print("😴 Sleep fetch error: \(error.localizedDescription)")
                    }
                    continuation.resume(returning: [])
                    return
                }
                continuation.resume(returning: samples)
            }
            healthStore.execute(query)
        }
        
        guard !samples.isEmpty else {
            print("😴 No sleep data found for last night")
            DispatchQueue.main.async {
                self.snapshot.lastNightSleep = nil // Clear old data if no new data exists
            }
            return
        }
        
        // Double check that the latest sample actually falls within our lookback window
        // (The predicate should handle this, but being explicit helps safety)
        if let latestEnd = samples.last?.endDate, latestEnd < startLookback {
             print("😴 Found sleep data, but it's too old (ended before 6pm yesterday). Ignoring.")
             DispatchQueue.main.async {
                 self.snapshot.lastNightSleep = nil
             }
             return
        }
        
        let parsedSleep = parseSleepSamples(samples)
        DispatchQueue.main.async {
            self.snapshot.lastNightSleep = parsedSleep
        }
    }
    
    /// Fetches the last 7 days of sleep data
    func fetchWeeklySleep() async {
        guard let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else { return }
        
        let calendar = Calendar.current
        let now = Date()
        guard let weekAgo = calendar.date(byAdding: .day, value: -7, to: calendar.startOfDay(for: now)) else { return }
        
        let predicate = HKQuery.predicateForSamples(withStart: weekAgo, end: now, options: .strictStartDate)
        
        let samples: [HKCategorySample] = await withCheckedContinuation { continuation in
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: true)
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, results, error in
                guard let samples = results as? [HKCategorySample] else {
                    continuation.resume(returning: [])
                    return
                }
                continuation.resume(returning: samples)
            }
            healthStore.execute(query)
        }
        
        // Group samples by night (each night ends before noon the next day)
        var nightGroups: [[HKCategorySample]] = []
        var currentGroup: [HKCategorySample] = []
        var currentNightDate: Date? = nil
        
        for sample in samples {
            let sampleNight = calendar.startOfDay(for: sample.startDate)
            // If bedtime is after noon, it belongs to the next day's "night"
            let hour = calendar.component(.hour, from: sample.startDate)
            let adjustedNight = hour >= 12 ? calendar.date(byAdding: .day, value: 1, to: sampleNight)! : sampleNight
            
            if currentNightDate == nil || adjustedNight == currentNightDate {
                currentGroup.append(sample)
                currentNightDate = adjustedNight
            } else {
                if !currentGroup.isEmpty {
                    nightGroups.append(currentGroup)
                }
                currentGroup = [sample]
                currentNightDate = adjustedNight
            }
        }
        if !currentGroup.isEmpty {
            nightGroups.append(currentGroup)
        }
        
        self.snapshot.weeklySleep = nightGroups.map { parseSleepSamples($0) }
    }
    
    /// Parses raw HealthKit sleep samples into a structured SleepData object
    private func parseSleepSamples(_ samples: [HKCategorySample]) -> SleepData {
        var totalAsleep: TimeInterval = 0
        var totalInBed: TimeInterval = 0
        var deepSleep: TimeInterval = 0
        var coreSleep: TimeInterval = 0
        var remSleep: TimeInterval = 0
        var awake: TimeInterval = 0
        
        var earliestStart = Date.distantFuture
        var latestEnd = Date.distantPast
        
        for sample in samples {
            let duration = sample.endDate.timeIntervalSince(sample.startDate)
            
            if sample.startDate < earliestStart { earliestStart = sample.startDate }
            if sample.endDate > latestEnd { latestEnd = sample.endDate }
            
            switch sample.value {
            case HKCategoryValueSleepAnalysis.inBed.rawValue:
                totalInBed += duration
            case HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue:
                totalAsleep += duration
                coreSleep += duration
            case HKCategoryValueSleepAnalysis.asleepCore.rawValue:
                totalAsleep += duration
                coreSleep += duration
            case HKCategoryValueSleepAnalysis.asleepDeep.rawValue:
                totalAsleep += duration
                deepSleep += duration
            case HKCategoryValueSleepAnalysis.asleepREM.rawValue:
                totalAsleep += duration
                remSleep += duration
            case HKCategoryValueSleepAnalysis.awake.rawValue:
                awake += duration
            default:
                break
            }
        }
        
        // If totalInBed is 0 but we have sleep data, estimate it
        if totalInBed == 0 && totalAsleep > 0 {
            totalInBed = latestEnd.timeIntervalSince(earliestStart)
        }
        
        return SleepData(
            date: earliestStart,
            bedtime: earliestStart,
            wakeTime: latestEnd,
            totalSleepSeconds: totalAsleep,
            timeInBedSeconds: totalInBed,
            deepSleepSeconds: deepSleep,
            coreSleepSeconds: coreSleep,
            remSleepSeconds: remSleep,
            awakeSeconds: awake
        )
    }
    
    // MARK: - Phase 1: HRV (Heart Rate Variability)
    
    /// Fetches the most recent HRV reading
    func fetchLatestHRV() async {
        guard let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else { return }
        
        let hrv: Double? = await withCheckedContinuation { continuation in
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let query = HKSampleQuery(
                sampleType: hrvType,
                predicate: nil,
                limit: 1,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                guard let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume(returning: nil)
                    return
                }
                let value = sample.quantity.doubleValue(for: .secondUnit(with: .milli))
                continuation.resume(returning: value)
            }
            healthStore.execute(query)
        }
        
        self.snapshot.latestHRV = hrv
        print("💓 Latest HRV: \(hrv.map { "\(Int($0)) ms" } ?? "N/A")")
    }
    
    /// Fetches the last 7 days of HRV data
    func fetchWeeklyHRV() async {
        guard let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else { return }
        
        let calendar = Calendar.current
        let now = Date()
        guard let weekAgo = calendar.date(byAdding: .day, value: -7, to: calendar.startOfDay(for: now)) else { return }
        
        let predicate = HKQuery.predicateForSamples(withStart: weekAgo, end: now, options: .strictStartDate)
        
        let data: [(date: Date, hrv: Double)] = await withCheckedContinuation { continuation in
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: true)
            let query = HKSampleQuery(
                sampleType: hrvType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                guard let samples = samples as? [HKQuantitySample] else {
                    continuation.resume(returning: [])
                    return
                }
                let results = samples.map { sample in
                    (date: sample.endDate, hrv: sample.quantity.doubleValue(for: .secondUnit(with: .milli)))
                }
                continuation.resume(returning: results)
            }
            healthStore.execute(query)
        }
        
        let avg = data.isEmpty ? nil : data.reduce(0) { $0 + $1.hrv } / Double(data.count)
        update {
            $0.weeklyHRV = data
            if let avg { $0.averageHRV = avg }
        }
    }
    
    // MARK: - Phase 1: Resting Heart Rate
    
    /// Fetches the most recent resting heart rate
    func fetchRestingHeartRate() async {
        guard let restingHRType = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) else { return }
        
        let hr: Double? = await withCheckedContinuation { continuation in
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let query = HKSampleQuery(
                sampleType: restingHRType,
                predicate: nil,
                limit: 1,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                guard let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume(returning: nil)
                    return
                }
                let bpm = sample.quantity.doubleValue(for: HKUnit(from: "count/min"))
                continuation.resume(returning: bpm)
            }
            healthStore.execute(query)
        }
        
        self.snapshot.latestRestingHR = hr
        print("❤️ Resting HR: \(hr.map { "\(Int($0)) bpm" } ?? "N/A")")
    }
    
    /// Fetches the last 7 days of resting heart rate
    func fetchWeeklyRestingHR() async {
        guard let restingHRType = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) else { return }
        
        let calendar = Calendar.current
        let now = Date()
        guard let weekAgo = calendar.date(byAdding: .day, value: -7, to: calendar.startOfDay(for: now)) else { return }
        
        let predicate = HKQuery.predicateForSamples(withStart: weekAgo, end: now, options: .strictStartDate)
        
        let data: [(date: Date, hr: Double)] = await withCheckedContinuation { continuation in
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: true)
            let query = HKSampleQuery(
                sampleType: restingHRType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                guard let samples = samples as? [HKQuantitySample] else {
                    continuation.resume(returning: [])
                    return
                }
                let results = samples.map { sample in
                    (date: sample.endDate, hr: sample.quantity.doubleValue(for: HKUnit(from: "count/min")))
                }
                continuation.resume(returning: results)
            }
            healthStore.execute(query)
        }
        
        self.snapshot.weeklyRestingHR = data
    }
    
    // MARK: - Phase 1: Recovery Score Calculation
    
    /// Fetches all Phase 1 health data and computes a recovery score
    func fetchRecoveryData(forceRefresh: Bool = false) async {
        let state = hkSignposter.beginInterval("fetchRecoveryData")
        defer { hkSignposter.endInterval("fetchRecoveryData", state) }

        // Check cache (5 minute input throttle)
        if !forceRefresh, let lastFetch = lastRecoveryFetch, Date().timeIntervalSince(lastFetch) < 300 {
            return
        }

        // Fetch all data in parallel
        async let sleepTask: () = fetchLastNightSleep()
        async let weeklySleepTask: () = fetchWeeklySleep()
        async let hrvTask: () = fetchLatestHRV()
        async let weeklyHRVTask: () = fetchWeeklyHRV()
        async let restingHRTask: () = fetchRestingHeartRate()
        async let weeklyHRTask: () = fetchWeeklyRestingHR()
        
        _ = await (sleepTask, weeklySleepTask, hrvTask, weeklyHRVTask, restingHRTask, weeklyHRTask)
        
        // Fallback: if lastNightSleep is nil but we have weekly data,
        // use the most recent night from weeklySleep
        if lastNightSleep == nil, let mostRecent = weeklySleep.last {
            self.snapshot.lastNightSleep = mostRecent
            print("😴 Using most recent weekly sleep as last night fallback")
        }
        
        // Calculate recovery score
        calculateRecoveryScore()
    }
    
    /// Computes a 0-100 recovery score based on sleep, HRV, and resting HR
    private func calculateRecoveryScore() {
        var score: Double = 50 // Start at baseline
        var dataPoints = 0
        
        // 1. Sleep Score (0-40 points)
        if let sleep = lastNightSleep {
            let sleepHours = sleep.totalSleepSeconds / 3600
            let sleepScore: Double
            
            if sleepHours >= 8 {
                sleepScore = 40  // Excellent
            } else if sleepHours >= 7 {
                sleepScore = 35  // Good
            } else if sleepHours >= 6 {
                sleepScore = 25  // Fair
            } else if sleepHours >= 5 {
                sleepScore = 15  // Poor
            } else {
                sleepScore = 5   // Very poor
            }
            
            // Bonus for deep sleep (should be 15-20% of total)
            let deepPercent = sleep.totalSleepSeconds > 0 ? (sleep.deepSleepSeconds / sleep.totalSleepSeconds) * 100 : 0
            let deepBonus: Double = deepPercent >= 15 ? 5 : (deepPercent >= 10 ? 2 : 0)
            
            score = sleepScore + deepBonus
            dataPoints += 1
        }
        
        // 2. HRV Score (0-35 points)
        if let hrv = latestHRV {
            let hrvScore: Double
            
            // HRV norms vary by age, using general population benchmarks
            if hrv >= 60 {
                hrvScore = 35  // Excellent
            } else if hrv >= 45 {
                hrvScore = 28  // Good
            } else if hrv >= 30 {
                hrvScore = 20  // Fair
            } else if hrv >= 20 {
                hrvScore = 12  // Below average
            } else {
                hrvScore = 5   // Low
            }
            
            // Trend bonus: if today's HRV is above 7-day average, add points
            if let avg = averageHRV, avg > 0 {
                let percentAbove = ((hrv - avg) / avg) * 100
                if percentAbove > 10 {
                    score += 5  // Trending up significantly
                } else if percentAbove > 0 {
                    score += 2  // Slightly above average
                } else if percentAbove < -15 {
                    score -= 5  // HRV dropped significantly
                }
            }
            
            score += hrvScore
            dataPoints += 1
        }
        
        // 3. Resting Heart Rate Score (0-25 points)
        if let restingHR = latestRestingHR {
            let hrScore: Double
            
            if restingHR <= 55 {
                hrScore = 25  // Athletic
            } else if restingHR <= 65 {
                hrScore = 20  // Good
            } else if restingHR <= 75 {
                hrScore = 15  // Average
            } else if restingHR <= 85 {
                hrScore = 8   // Below average
            } else {
                hrScore = 3   // High
            }
            
            score += hrScore
            dataPoints += 1
        }
        
        // If we have no data at all, show unknown
        guard dataPoints > 0 else {
            update {
                $0.recoveryScore = nil
                $0.recoveryStatus = .unknown
            }
            return
        }

        // Normalize if we're missing data points (scale up proportionally)
        if dataPoints < 3 {
            score = (score / Double(dataPoints)) * 3.0
        }

        // Clamp to 0-100
        let finalScore = Int(min(100, max(0, score)))

        let status: RecoveryStatus
        switch finalScore {
        case 80...100: status = .peak
        case 60..<80:  status = .good
        case 40..<60:  status = .fair
        case 20..<40:  status = .low
        default:       status = .critical
        }

        update {
            $0.recoveryScore = finalScore
            $0.recoveryStatus = status
        }

        print("🔋 Recovery Score: \(finalScore) (\(status.label))")

        self.lastRecoveryFetch = Date()
    }
    
    // MARK: - Phase 2: Activity & Strain
    
    /// Fetches all data needed for Phase 2: workouts, strain, weekly trends
    func fetchStrainData(forceRefresh: Bool = false) async {
        let state = hkSignposter.beginInterval("fetchStrainData")
        defer { hkSignposter.endInterval("fetchStrainData", state) }

        // Check cache (5 minute input throttle)
        if !forceRefresh, let lastFetch = lastStrainFetch, Date().timeIntervalSince(lastFetch) < 300 {
            return
        }

        async let workoutsTask: () = fetchTodayWorkouts()
        async let weeklyWorkoutsTask: () = fetchWeeklyWorkouts()
        
        _ = await (workoutsTask, weeklyWorkoutsTask)
        
        // Calculate today's strain
        await calculateStrainScore()
        
        // Build weekly strain/recovery trends
        await buildWeeklyTrends()
        
        self.lastStrainFetch = Date()
    }
    
    /// Fetches today's workouts from HealthKit
    func fetchTodayWorkouts() async {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let now = Date()
        
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)
        
        let workouts: [HKWorkout] = await withCheckedContinuation { continuation in
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let query = HKSampleQuery(
                sampleType: HKObjectType.workoutType(),
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, results, error in
                guard let workouts = results as? [HKWorkout] else {
                    if let error = error {
                        print("🏋️ Workout fetch error: \(error.localizedDescription)")
                    }
                    continuation.resume(returning: [])
                    return
                }
                continuation.resume(returning: workouts)
            }
            healthStore.execute(query)
        }
        
        var summaries: [WorkoutSummary] = []
        for workout in workouts {
            var summary = WorkoutSummary(from: workout)
            if summary.activityType == .running {
                if summary.avgHeartRate == nil {
                    summary.avgHeartRate = await fetchAvgHeartRate(for: workout)
                }
                if summary.elevationAscendedMeters == nil || summary.elevationAscendedMeters == 0 {
                    summary.elevationAscendedMeters = await fetchElevationGain(for: workout)
                }
            }
            summaries.append(summary)
        }
        
        self.snapshot.todayWorkouts = summaries
        print("🏋️ Found \(todayWorkouts.count) workouts today")
    }
    
    /// Fetches the last 7 days of workouts from HealthKit
    func fetchWeeklyWorkouts() async {
        let calendar = Calendar.current
        let now = Date()
        guard let weekAgo = calendar.date(byAdding: .day, value: -7, to: calendar.startOfDay(for: now)) else { return }
        
        let predicate = HKQuery.predicateForSamples(withStart: weekAgo, end: now, options: .strictStartDate)
        
        let workouts: [HKWorkout] = await withCheckedContinuation { continuation in
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let query = HKSampleQuery(
                sampleType: HKObjectType.workoutType(),
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, results, error in
                guard let workouts = results as? [HKWorkout] else {
                    continuation.resume(returning: [])
                    return
                }
                continuation.resume(returning: workouts)
            }
            healthStore.execute(query)
        }
        
        var summaries: [WorkoutSummary] = []
        for workout in workouts {
            var summary = WorkoutSummary(from: workout)
            if summary.activityType == .running {
                if summary.avgHeartRate == nil {
                    summary.avgHeartRate = await fetchAvgHeartRate(for: workout)
                }
                if summary.elevationAscendedMeters == nil || summary.elevationAscendedMeters == 0 {
                    summary.elevationAscendedMeters = await fetchElevationGain(for: workout)
                }
            }
            summaries.append(summary)
        }
        
        self.snapshot.weeklyWorkouts = summaries
        print("🏋️ Found \(weeklyWorkouts.count) workouts this week")
    }
    
    /// Fetches recent running workouts from HealthKit. Newest first.
    /// Uses a date-only predicate and filters activity type in Swift to avoid
    /// compound-predicate quirks. Returns runs with distance > 0.
    /// Fetches a Mon-anchored ISO weekly mileage history covering the last
    /// `weeksBack` weeks. Includes empty weeks (0 km) so charts render a
    /// continuous timeline.
    struct WeeklyMileageBucket: Identifiable, Hashable {
        let weekStart: Date
        let km: Double
        var id: Date { weekStart }
    }

    func fetchWeeklyMileageHistory(weeksBack: Int = 26) async -> [WeeklyMileageBucket] {
        var cal = Calendar(identifier: .iso8601)
        cal.firstWeekday = 2
        guard let currentWeekStart = cal.dateInterval(of: .weekOfYear, for: Date())?.start else { return [] }

        // Lightweight: pull raw running workouts and read distance directly. This
        // deliberately AVOIDS `fetchRecentRuns`, which enriches every workout with
        // per-workout heart-rate + elevation sub-queries — over a long history that's
        // hundreds of extra HealthKit round-trips, slow enough that the chart card's
        // `.task` was often cancelled (user navigates away) before it finished, leaving
        // the card blank until the next visit. The chart only needs distance + date.
        let windowStart = cal.date(byAdding: .weekOfYear, value: -weeksBack, to: currentWeekStart) ?? Date()
        let workouts = await fetchRunningWorkouts(since: windowStart)

        var totals: [Date: Double] = [:]
        for workout in workouts {
            let meters = workout.totalDistance?.doubleValue(for: .meter()) ?? 0
            guard meters > 0,
                  let weekStart = cal.dateInterval(of: .weekOfYear, for: workout.endDate)?.start else { continue }
            totals[weekStart, default: 0] += meters / 1000.0
        }

        var buckets: [WeeklyMileageBucket] = []
        for offset in stride(from: weeksBack - 1, through: 0, by: -1) {
            guard let start = cal.date(byAdding: .weekOfYear, value: -offset, to: currentWeekStart) else { continue }
            buckets.append(.init(weekStart: start, km: totals[start] ?? 0))
        }
        return buckets
    }

    func fetchRecentRuns(limit: Int = 10, daysBack: Int = 90) async -> [WorkoutSummary] {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("🏃 HealthKit not available on device")
            return []
        }

        let calendar = Calendar.current
        let now = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -daysBack, to: now) else { return [] }

        let datePredicate = HKQuery.predicateForSamples(withStart: startDate, end: now, options: [])

        let workouts: [HKWorkout] = await withCheckedContinuation { continuation in
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let query = HKSampleQuery(
                sampleType: HKObjectType.workoutType(),
                predicate: datePredicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, results, error in
                if let error = error {
                    print("🏃 Run fetch error: \(error.localizedDescription)")
                }
                continuation.resume(returning: (results as? [HKWorkout]) ?? [])
            }
            healthStore.execute(query)
        }

        let running = workouts.filter { $0.workoutActivityType == .running }
        var summaries: [WorkoutSummary] = []
        for workout in running {
            var summary = WorkoutSummary(from: workout)
            if summary.avgHeartRate == nil {
                summary.avgHeartRate = await fetchAvgHeartRate(for: workout)
            }
            if summary.elevationAscendedMeters == nil || summary.elevationAscendedMeters == 0 {
                summary.elevationAscendedMeters = await fetchElevationGain(for: workout)
            }
            summaries.append(summary)
        }
        
        let withDistance = summaries.filter { ($0.distanceMeters ?? 0) > 0 }

        print("🏃 HealthKit: \(workouts.count) total workouts in last \(daysBack)d → \(running.count) runs → \(withDistance.count) with distance")

        return Array(withDistance.prefix(limit))
    }

    /// Returns raw running `HKWorkout` objects since `startDate`, newest-first.
    /// Used by the importer + auto-sync paths where we need the workouts
    /// themselves (not the lightweight `WorkoutSummary` projection) so we
    /// can stream route/HR/elevation samples per workout.
    func fetchRunningWorkouts(since startDate: Date) async -> [HKWorkout] {
        guard HKHealthStore.isHealthDataAvailable() else { return [] }

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: Date(), options: [])

        let workouts: [HKWorkout] = await withCheckedContinuation { continuation in
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let query = HKSampleQuery(
                sampleType: HKObjectType.workoutType(),
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, results, error in
                if let error = error {
                    print("🏃 HK fetch error: \(error.localizedDescription)")
                }
                continuation.resume(returning: (results as? [HKWorkout]) ?? [])
            }
            healthStore.execute(query)
        }

        // Filter to running with non-trivial distance — manual rest-day entries
        // and zero-distance shells aren't useful for a route heatmap.
        return workouts.filter {
            $0.workoutActivityType == .running &&
            ($0.totalDistance?.doubleValue(for: .meter()) ?? 0) > 100
        }
    }

    /// Year-range convenience over `fetchRunningWorkouts(since:)` for the
    /// explicit "Import from HealthKit" flow. `yearsBack == nil` means
    /// "all time" — capped at HK's distantPast bound.
    func fetchRunningWorkoutsForImport(yearsBack: Int?) async -> [HKWorkout] {
        let startDate: Date
        if let years = yearsBack, years > 0 {
            startDate = Calendar.current.date(byAdding: .year, value: -years, to: Date()) ?? .distantPast
        } else {
            startDate = .distantPast
        }
        return await fetchRunningWorkouts(since: startDate)
    }

    /// Updates `thisWeekRunKm` and `weeklyRunStreak`. Skips the HealthKit scan if
    /// data is fresh (< 30 min) unless `forceRefresh` is true.
    func refreshWeeklyRunStats(goalKm: Double, forceRefresh: Bool = false) async {
        let state = hkSignposter.beginInterval("refreshWeeklyRunStats")
        defer { hkSignposter.endInterval("refreshWeeklyRunStats", state) }

        if !forceRefresh,
           let lastFetch = lastWeeklyRunStatsFetch,
           Date().timeIntervalSince(lastFetch) < Self.heavyScanTTL,
           lastFetch.isInSameISOWeek(as: Date()) {
            // Skip the heavy HealthKit scan but still push the goal to the
            // widget. The cached weekly km is already accurate; only the goal
            // may have changed (e.g. a new running plan was created).
            if let defaults = UserDefaults(suiteName: "group.com.jesseta.yumo") {
                defaults.set(thisWeekRunKm, forKey: "weekly_run_km")
                defaults.set(goalKm, forKey: "weekly_run_goal_km")
                WidgetCenter.shared.reloadTimelines(ofKind: "WeeklyMileageWidget")
            }
            return
        }

        // Grab ~12 weeks of runs in one shot.
        let runs = await fetchRecentRuns(limit: 500, daysBack: 84)

        var cal = Calendar(identifier: .iso8601) // ISO week (Mon-first, always)
        cal.firstWeekday = 2
        let now = Date()
        guard let currentWeekStart = cal.dateInterval(of: .weekOfYear, for: now)?.start else {
            await MainActor.run {
                update {
                    $0.thisWeekRunKm = 0
                    $0.weeklyRunStreak = 0
                }
            }
            return
        }

        // Bucket runs by week-start date.
        var kmByWeekStart: [Date: Double] = [:]
        for run in runs {
            guard let meters = run.distanceMeters, meters > 0,
                  let weekStart = cal.dateInterval(of: .weekOfYear, for: run.date)?.start else { continue }
            kmByWeekStart[weekStart, default: 0] += meters / 1000.0
        }

        let currentWeekKm = kmByWeekStart[currentWeekStart] ?? 0

        // Walk backward from the previous full week; stop when a week misses the goal.
        var streak = 0
        var cursor = currentWeekStart
        for _ in 0..<12 {
            guard let prev = cal.date(byAdding: .weekOfYear, value: -1, to: cursor) else { break }
            let weekKm = kmByWeekStart[prev] ?? 0
            if goalKm > 0 && weekKm >= goalKm {
                streak += 1
                cursor = prev
            } else {
                break
            }
        }

        // If the current week has already hit the goal, include it in the streak.
        let liveStreak = (goalKm > 0 && currentWeekKm >= goalKm) ? streak + 1 : streak

        // --- Recent fitness signals (for personalized race plan) ---

        // Avg of last 4 completed weeks (excludes the in-progress current week).
        var recentWeeks: [Double] = []
        var avgCursor = currentWeekStart
        for _ in 0..<4 {
            guard let prev = cal.date(byAdding: .weekOfYear, value: -1, to: avgCursor) else { break }
            recentWeeks.append(kmByWeekStart[prev] ?? 0)
            avgCursor = prev
        }
        let recentAvg = recentWeeks.isEmpty ? 0 : recentWeeks.reduce(0, +) / Double(recentWeeks.count)

        // Last completed week.
        let lastWeek: Double = {
            guard let prev = cal.date(byAdding: .weekOfYear, value: -1, to: currentWeekStart) else { return 0 }
            return kmByWeekStart[prev] ?? 0
        }()

        // Longest single run in the last 4 weeks (completed + in-progress).
        let fourWeeksAgo = cal.date(byAdding: .weekOfYear, value: -4, to: currentWeekStart) ?? currentWeekStart
        let maxLongRun = runs
            .filter { $0.date >= fourWeeksAgo }
            .compactMap { $0.distanceMeters }
            .map { $0 / 1000.0 }
            .max() ?? 0

        await MainActor.run {
            update {
                $0.thisWeekRunKm = currentWeekKm
                $0.weeklyRunStreak = liveStreak
                $0.recentAvgWeeklyRunKm = recentAvg
                $0.lastWeekRunKm = lastWeek
                $0.recentMaxLongRunKm = maxLongRun
            }
        }

        // Share to widget via App Group so the mileage widget can read without HK access.
        if let defaults = UserDefaults(suiteName: "group.com.jesseta.yumo") {
            defaults.set(currentWeekKm, forKey: "weekly_run_km")
            defaults.set(goalKm, forKey: "weekly_run_goal_km")
            WidgetCenter.shared.reloadTimelines(ofKind: "WeeklyMileageWidget")
        }

        self.lastWeeklyRunStatsFetch = Date()
    }

    /// Scans running workouts and infers PRs at the standard race distances.
    /// Skips the 730-day HealthKit scan if data is fresh (< 30 min) unless forced.
    func refreshPersonalBests(forceRefresh: Bool = false) async {
        let state = hkSignposter.beginInterval("refreshPersonalBests")
        defer { hkSignposter.endInterval("refreshPersonalBests", state) }

        if !forceRefresh,
           let lastFetch = lastPersonalBestsFetch,
           Date().timeIntervalSince(lastFetch) < Self.heavyScanTTL {
            return
        }

        // Fetch raw HKWorkouts (not summaries) so we can pull each one's GPS route
        // and find PBs *inside* longer runs — e.g., the fastest single km in a 10K.
        let calendar = Calendar.current
        let now = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -730, to: now) else { return }
        let datePredicate = HKQuery.predicateForSamples(withStart: startDate, end: now, options: [])

        let workouts: [HKWorkout] = await withCheckedContinuation { cont in
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let query = HKSampleQuery(
                sampleType: HKObjectType.workoutType(),
                predicate: datePredicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sort]
            ) { _, results, _ in
                cont.resume(returning: (results as? [HKWorkout]) ?? [])
            }
            healthStore.execute(query)
        }

        let runs = workouts
            .filter { $0.workoutActivityType == .running }
            .filter { ($0.totalDistance?.doubleValue(for: .meter()) ?? 0) >= 500 }
            .prefix(200)

        let buckets: [(label: String, km: Double, range: ClosedRange<Double>)] = [
            ("1K",   1.0,      0.9...1.5),
            ("5K",   5.0,      4.5...6.2),
            ("10K",  10.0,     9.0...12.0),
            ("Half", 21.0975,  20.0...23.5),
            ("Full", 42.195,   41.0...46.0)
        ]

        var bests: [String: (time: TimeInterval, date: Date)] = [:]

        // Step 1: whole-workout candidates. Any run at least as long as the bucket
        // contributes its average-pace projection (`avgPace × bucketKm`). This is a
        // conservative ceiling — the runner's actual fastest segment of that length
        // is at least this fast — but it's the best we can do for runs without GPS
        // route data (Huawei syncs, treadmill, manual logs). Sliding-window from
        // step 2 will beat this whenever a route is present.
        for run in runs {
            let meters = run.totalDistance?.doubleValue(for: .meter()) ?? 0
            let km = meters / 1000.0
            let durationSec = run.duration
            guard durationSec > 0 else { continue }
            for bucket in buckets {
                // Allow runs slightly short of the bucket (e.g., 0.9km counts as a
                // 1K candidate, scaled up). Anything longer also contributes via
                // avg-pace projection.
                guard km >= bucket.km * 0.9 else { continue }
                let scaledTime = durationSec * (bucket.km / km)
                if let existing = bests[bucket.label] {
                    if scaledTime < existing.time { bests[bucket.label] = (scaledTime, run.endDate) }
                } else {
                    bests[bucket.label] = (scaledTime, run.endDate)
                }
            }
        }

        // Step 2: sliding-window candidates from each route. Run with bounded
        // concurrency so we don't fan out hundreds of HK queries at once.
        let chunkSize = 8
        let runsArray = Array(runs)
        for chunkStart in stride(from: 0, to: runsArray.count, by: chunkSize) {
            let end = min(chunkStart + chunkSize, runsArray.count)
            let chunk = Array(runsArray[chunkStart..<end])
            let routes: [(HKWorkout, [CLLocation])] = await withTaskGroup(of: (HKWorkout, [CLLocation]).self) { group in
                for run in chunk {
                    group.addTask { [self] in
                        let route = await self.fetchRouteLocations(for: run)
                        return (run, route)
                    }
                }
                var collected: [(HKWorkout, [CLLocation])] = []
                for await pair in group { collected.append(pair) }
                return collected
            }
            for (run, route) in routes {
                guard route.count > 1 else { continue }
                let totalMeters = run.totalDistance?.doubleValue(for: .meter()) ?? 0
                for bucket in buckets {
                    let bucketMeters = bucket.km * 1000
                    guard totalMeters >= bucketMeters else { continue }
                    if let segSec = bestSegmentSeconds(in: route, distanceMeters: bucketMeters) {
                        if let existing = bests[bucket.label] {
                            if segSec < existing.time { bests[bucket.label] = (segSec, run.endDate) }
                        } else {
                            bests[bucket.label] = (segSec, run.endDate)
                        }
                    }
                }
            }
        }

        let result: [PersonalBest] = buckets.compactMap { bucket in
            guard let b = bests[bucket.label] else { return nil }
            return PersonalBest(
                distanceKm: bucket.km,
                label: bucket.label,
                timeSeconds: b.time,
                date: b.date
            )
        }

        await MainActor.run {
            self.snapshot.personalBests = result
        }
        self.lastPersonalBestsFetch = Date()
    }

    /// Calculates today's strain score (0-21 scale, inspired by Whoop)
    /// Factors: active calories (40%), workout intensity (35%), steps (25%)
    func calculateStrainScore() async {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let now = Date()
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)
        
        // 1. Active calories
        let activeCalories: Double
        if let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
            activeCalories = await fetchSum(for: energyType, predicate: predicate, unit: .kilocalorie())
        } else {
            activeCalories = 0
        }

        // 2. Steps
        let steps: Double
        if let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) {
            steps = await fetchSum(for: stepType, predicate: predicate, unit: .count())
        } else {
            steps = 0
        }

        // Single coalesced publish so UI updates once instead of 4 times.
        update {
            $0.todayBurntCalories = activeCalories
            $0.todaySteps = steps
        }
        
        // 3. Workout minutes and intensity
        let totalWorkoutMinutes = todayWorkouts.reduce(0.0) { $0 + $1.durationMinutes }
        let workoutCalories = todayWorkouts.reduce(0.0) { $0 + $1.caloriesBurned }
        
        // Calculate workout intensity factor (higher cal/min = more intense)
        let intensityFactor: Double
        if totalWorkoutMinutes > 0 {
            let calPerMin = workoutCalories / totalWorkoutMinutes
            intensityFactor = min(calPerMin / 15.0, 1.0) // 15 cal/min is very intense
        } else {
            intensityFactor = 0
        }
        
        // Strain score calculation using logarithmic scale (0-21)
        // Similar to Whoop's approach where strain gets harder to accumulate
        
        // Calorie component (0-8.4 points, 40%)
        let calorieScore = min(log2(1 + activeCalories / 100.0) * 2.0, 8.4)
        
        // Workout intensity component (0-7.35 points, 35%)
        let workoutScore: Double
        if totalWorkoutMinutes > 0 {
            let baseWorkoutScore = min(log2(1 + totalWorkoutMinutes / 10.0) * 1.5, 5.0)
            workoutScore = baseWorkoutScore * (1.0 + intensityFactor * 0.47) // Boost by intensity
        } else {
            workoutScore = 0
        }
        
        // Step component (0-5.25 points, 25%)
        let stepScore = min(log2(1 + steps / 1000.0) * 1.2, 5.25)
        
        let totalStrain = calorieScore + workoutScore + stepScore
        self.snapshot.strainScore = min(21, max(0, totalStrain))
        
        print("⚡ Strain Score: \(String(format: "%.1f", self.strainScore ?? 0))/21 (Cal: \(String(format: "%.1f", calorieScore)), Workout: \(String(format: "%.1f", workoutScore)), Steps: \(String(format: "%.1f", stepScore)))")
    }
    
    /// Builds weekly trend data for recovery, strain, and sleep
    private func buildWeeklyTrends() async {
        let calendar = Calendar.current
        let now = Date()
        
        var strainTrend: [(date: Date, strain: Double)] = []
        var combinedTrend: [(date: Date, sleepHours: Double, recovery: Int, strain: Double)] = []
        
        for dayOffset in (0..<7).reversed() {
            guard let dayDate = calendar.date(byAdding: .day, value: -dayOffset, to: calendar.startOfDay(for: now)) else { continue }
            guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayDate) else { continue }
            
            let predicate = HKQuery.predicateForSamples(withStart: dayDate, end: dayEnd, options: .strictStartDate)
            
            // Fetch active calories for this day
            var dayCal = 0.0
            if let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
                dayCal = await fetchSum(for: energyType, predicate: predicate, unit: .kilocalorie())
            }
            
            // Fetch steps for this day
            var daySteps = 0.0
            if let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) {
                daySteps = await fetchSum(for: stepType, predicate: predicate, unit: .count())
            }
            
            // Workout data for this day
            let dayWorkouts = weeklyWorkouts.filter { w in
                calendar.isDate(w.date, inSamePeriodAs: dayDate, granularity: .day)
            }
            let dayWorkoutMins = dayWorkouts.reduce(0.0) { $0 + $1.durationMinutes }
            let dayWorkoutCal = dayWorkouts.reduce(0.0) { $0 + $1.caloriesBurned }
            let dayIntensity: Double
            if dayWorkoutMins > 0 {
                dayIntensity = min((dayWorkoutCal / dayWorkoutMins) / 15.0, 1.0)
            } else {
                dayIntensity = 0
            }
            
            // Calculate strain for this day
            let calScore = min(log2(1 + dayCal / 100.0) * 2.0, 8.4)
            let wScore: Double
            if dayWorkoutMins > 0 {
                let base = min(log2(1 + dayWorkoutMins / 10.0) * 1.5, 5.0)
                wScore = base * (1.0 + dayIntensity * 0.47)
            } else {
                wScore = 0
            }
            let sScore = min(log2(1 + daySteps / 1000.0) * 1.2, 5.25)
            let dayStrain = min(21, calScore + wScore + sScore)
            
            strainTrend.append((date: dayDate, strain: dayStrain))
            
            // Sleep for this night (find matching entry)
            let sleepHours = weeklySleep.first(where: {
                calendar.isDate($0.date, inSamePeriodAs: dayDate, granularity: .day)
            })?.totalSleepHours ?? 0
            
            // Recovery for this day (simplified — use overall score for today, estimated for past)
            let recoveryEst: Int
            if dayOffset == 0 {
                recoveryEst = recoveryScore ?? 50
            } else {
                // Rough estimation based on sleep
                recoveryEst = sleepHours >= 7 ? 75 : (sleepHours >= 5 ? 55 : 35)
            }
            
            combinedTrend.append((date: dayDate, sleepHours: sleepHours, recovery: recoveryEst, strain: dayStrain))
        }
        
        update {
            $0.weeklyStrain = strainTrend
            $0.weeklyRecoverySleep = combinedTrend
        }

        print("📊 Built weekly trends: \(strainTrend.count) days")
    }
}

// MARK: - Supporting Data Types

/// Aggregated health state. Held by `HealthKitManager.snapshot` so observers
/// have one dependency edge instead of 30, and so multi-field updates (built
/// via `HealthKitManager.update { ... }`) publish once.
struct HealthSnapshot {
    var isAuthorized = false

    // Today's data
    var todaySteps: Double = 0
    var todayBurntCalories: Double = 0
    var todayActiveMinutes: Double = 0

    // Weekly data
    var weeklyBurntCalories: [(date: Date, calories: Double)] = []

    // Weight data
    var latestWeight: Double? = nil
    var weightHistory: [(date: Date, weightKg: Double)] = []

    // Profile data (for onboarding)
    var profileHeight: Double? = nil
    var profileDateOfBirth: Date? = nil
    var profileBiologicalSex: HKBiologicalSex? = nil

    // Sleep
    var lastNightSleep: SleepData? = nil
    var weeklySleep: [SleepData] = []

    // HRV
    var latestHRV: Double? = nil
    var weeklyHRV: [(date: Date, hrv: Double)] = []
    var averageHRV: Double? = nil

    // Resting HR
    var latestRestingHR: Double? = nil
    var weeklyRestingHR: [(date: Date, hr: Double)] = []

    // Recovery
    var recoveryScore: Int? = nil
    var recoveryStatus: RecoveryStatus = .unknown

    // Workouts
    var todayWorkouts: [WorkoutSummary] = []
    var weeklyWorkouts: [WorkoutSummary] = []

    // Running volume
    var thisWeekRunKm: Double = 0
    var weeklyRunStreak: Int = 0
    var recentAvgWeeklyRunKm: Double = 0
    var lastWeekRunKm: Double = 0
    var recentMaxLongRunKm: Double = 0

    // Personal bests
    var personalBests: [PersonalBest] = []

    // Strain & weekly trends
    var strainScore: Double? = nil
    var weeklyStrain: [(date: Date, strain: Double)] = []
    var weeklyRecovery: [(date: Date, score: Int)] = []
    var weeklyRecoverySleep: [(date: Date, sleepHours: Double, recovery: Int, strain: Double)] = []
}

struct SleepData: Identifiable {
    let id = UUID()
    let date: Date
    let bedtime: Date
    let wakeTime: Date
    let totalSleepSeconds: TimeInterval
    let timeInBedSeconds: TimeInterval
    let deepSleepSeconds: TimeInterval
    let coreSleepSeconds: TimeInterval
    let remSleepSeconds: TimeInterval
    let awakeSeconds: TimeInterval
    
    var totalSleepHours: Double {
        totalSleepSeconds / 3600
    }
    
    var timeInBedHours: Double {
        timeInBedSeconds / 3600
    }
    
    var sleepEfficiency: Double {
        guard timeInBedSeconds > 0 else { return 0 }
        return (totalSleepSeconds / timeInBedSeconds) * 100
    }
    
    var sleepQuality: String {
        let hours = totalSleepHours
        if hours >= 8 { return "Excellent" }
        if hours >= 7 { return "Good" }
        if hours >= 6 { return "Fair" }
        return "Poor"
    }
    
    var sleepQualityColor: String {
        let hours = totalSleepHours
        if hours >= 8 { return "green" }
        if hours >= 7 { return "yellow" }
        if hours >= 6 { return "orange" }
        return "red"
    }
    
    /// Formatted duration string like "7h 32m"
    static func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}

enum RecoveryStatus {
    case peak, good, fair, low, critical, unknown
    
    var label: String {
        switch self {
        case .peak: return "Peak"
        case .good: return "Good"
        case .fair: return "Fair"
        case .low: return "Low"
        case .critical: return "Critical"
        case .unknown: return "No Data"
        }
    }
    
    var emoji: String {
        switch self {
        case .peak: return "🟢"
        case .good: return "🟡"
        case .fair: return "🟠"
        case .low: return "🔴"
        case .critical: return "⚫️"
        case .unknown: return "⚪️"
        }
    }
    
    var message: String {
        switch self {
        case .peak: return "Your body is fully recovered. Push hard today!"
        case .good: return "Good recovery. You're ready for a solid workout."
        case .fair: return "Moderate recovery. Listen to your body today."
        case .low: return "Recovery is low. Consider lighter activity."
        case .critical: return "Your body needs rest. Prioritize sleep and nutrition."
        case .unknown: return "Connect Apple Watch to track recovery."
        }
    }
}

enum HealthKitError: Error {
    case notAvailable
}

// MARK: - Workout Summary

struct PersonalBest: Identifiable, Hashable {
    let id = UUID()
    let distanceKm: Double
    let label: String           // "1K", "5K", "10K", "Half", "Full"
    let timeSeconds: TimeInterval
    let date: Date

    /// Formatted time like "4:32" for under an hour, "1:45:20" otherwise.
    var formattedTime: String {
        let total = Int(timeSeconds.rounded())
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%d:%02d", m, s)
    }

    /// Pace per km as "4:32 /km"
    var formattedPace: String {
        let paceSec = timeSeconds / distanceKm
        let m = Int(paceSec) / 60
        let s = Int(paceSec) % 60
        return String(format: "%d:%02d /km", m, s)
    }
}

struct WorkoutSummary: Identifiable {
    let id = UUID()
    let hkWorkoutUUID: UUID      // actual HKWorkout.uuid — used for exact route lookup
    let date: Date
    let activityType: HKWorkoutActivityType
    let durationMinutes: Double
    let caloriesBurned: Double
    let distanceMeters: Double?
    let sourceName: String
    var avgHeartRate: Int?
    var elevationAscendedMeters: Double?

    init(from workout: HKWorkout) {
        self.hkWorkoutUUID = workout.uuid
        self.date = workout.startDate
        self.activityType = workout.workoutActivityType
        self.durationMinutes = workout.duration / 60.0
        self.caloriesBurned = workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()) ?? 0
        self.distanceMeters = workout.totalDistance?.doubleValue(for: .meter())
        self.sourceName = workout.sourceRevision.source.name
        
        if let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate),
           let stats = workout.statistics(for: hrType),
           let avg = stats.averageQuantity() {
            self.avgHeartRate = Int(avg.doubleValue(for: HKUnit.count().unitDivided(by: .minute())))
        } else {
            self.avgHeartRate = nil
        }
        
        if let elevationQuantity = workout.metadata?[HKMetadataKeyElevationAscended] as? HKQuantity {
            self.elevationAscendedMeters = elevationQuantity.doubleValue(for: .meter())
        } else {
            self.elevationAscendedMeters = nil
        }
    }
    
    var typeName: String {
        switch activityType {
        case .running: return "Running"
        case .cycling: return "Cycling"
        case .swimming: return "Swimming"
        case .walking: return "Walking"
        case .hiking: return "Hiking"
        case .yoga: return "Yoga"
        case .functionalStrengthTraining, .traditionalStrengthTraining: return "Strength"
        case .highIntensityIntervalTraining: return "HIIT"
        case .dance: return "Dance"
        case .elliptical: return "Elliptical"
        case .rowing: return "Rowing"
        case .stairClimbing: return "Stair Climbing"
        case .pilates: return "Pilates"
        case .crossTraining: return "Cross Training"
        case .coreTraining: return "Core Training"
        case .flexibility: return "Flexibility"
        case .mixedCardio: return "Cardio"
        case .cooldown: return "Cooldown"
        case .socialDance: return "Social Dance"
        default: return "Workout"
        }
    }
    
    var icon: String {
        switch activityType {
        case .running: return "figure.run"
        case .cycling: return "figure.outdoor.cycle"
        case .swimming: return "figure.pool.swim"
        case .walking: return "figure.walk"
        case .hiking: return "figure.hiking"
        case .yoga: return "figure.yoga"
        case .functionalStrengthTraining, .traditionalStrengthTraining: return "figure.strengthtraining.traditional"
        case .highIntensityIntervalTraining: return "figure.highintensity.intervaltraining"
        case .dance, .socialDance: return "figure.dance"
        case .elliptical: return "figure.elliptical"
        case .rowing: return "figure.rower"
        case .stairClimbing: return "figure.stair.stepper"
        case .pilates: return "figure.pilates"
        case .crossTraining: return "figure.cross.training"
        case .coreTraining: return "figure.core.training"
        case .flexibility: return "figure.flexibility"
        case .mixedCardio: return "figure.mixed.cardio"
        case .cooldown: return "figure.cooldown"
        default: return "figure.mixed.cardio"
        }
    }
    
    var color: Color {
        switch activityType {
        case .running: return .green
        case .cycling: return .orange
        case .swimming: return .cyan
        case .walking: return .blue
        case .hiking: return .brown
        case .yoga, .pilates, .flexibility: return .purple
        case .functionalStrengthTraining, .traditionalStrengthTraining: return .red
        case .highIntensityIntervalTraining: return .pink
        case .dance, .socialDance: return .indigo
        default: return .blue
        }
    }
    
    var formattedDuration: String {
        let hours = Int(durationMinutes) / 60
        let mins = Int(durationMinutes) % 60
        if hours > 0 {
            return "\(hours)h \(mins)m"
        }
        return "\(mins)m"
    }
    
    var formattedDistance: String? {
        guard let meters = distanceMeters, meters > 0 else { return nil }
        let km = meters / 1000.0
        return String(format: "%.2fkm", km)
    }

    var formattedPace: String? {
        guard let meters = distanceMeters, meters > 0, durationMinutes > 0 else { return nil }
        let km = meters / 1000.0
        let paceSecPerKm = (durationMinutes * 60.0) / km
        let paceMin = Int(paceSecPerKm) / 60
        let paceSec = Int(paceSecPerKm) % 60
        return String(format: "%d:%02d /km", paceMin, paceSec)
    }
}

import SwiftUI

// MARK: - Calendar Extension
extension Calendar {
    func isDate(_ date1: Date, inSamePeriodAs date2: Date, granularity: Calendar.Component) -> Bool {
        return self.isDate(date1, equalTo: date2, toGranularity: granularity)
    }
}

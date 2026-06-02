import Foundation
import HealthKit
import CoreLocation

/// Rich per-run analytics derived from HealthKit (Apple Watch). Each field is
/// optional so cards can hide individually when the source data isn't present
/// (third-party syncs that only write the workout shell, indoor runs without GPS, etc.).
struct RunAnalytics {
    struct PacePoint { let distanceKm: Double; let paceSecPerKm: Double }
    struct ElevationPoint { let distanceKm: Double; let altitudeMeters: Double }
    struct HRPoint { let elapsed: TimeInterval; let bpm: Double }
    struct CadencePoint { let elapsed: TimeInterval; let spm: Double }

    struct Split: Identifiable {
        let id = UUID()
        let index: Int
        let distanceKm: Double
        let durationSeconds: TimeInterval
        let avgHRBpm: Int?
        var paceSecPerKm: Double { distanceKm > 0 ? durationSeconds / distanceKm : 0 }
    }

    struct HRZoneDistribution {
        /// Seconds spent in each zone (Z1 .. Z5)
        let secondsPerZone: [TimeInterval]
        /// Estimated max HR used to compute the zones (220 - age).
        let maxHR: Int

        var totalSeconds: TimeInterval { secondsPerZone.reduce(0, +) }
        func percent(forZone i: Int) -> Double {
            guard totalSeconds > 0, i >= 0, i < secondsPerZone.count else { return 0 }
            return secondsPerZone[i] / totalSeconds
        }
    }

    let pacePoints: [PacePoint]?
    let elevationPoints: [ElevationPoint]?
    let hrPoints: [HRPoint]?
    let cadencePoints: [CadencePoint]?
    let splits: [Split]?
    let hrZoneDistribution: HRZoneDistribution?
    let elevationGainMeters: Int?
    let avgHeartRate: Int?
    let maxHeartRate: Int?
    let avgCadenceSPM: Int?

    var hasAnyChartData: Bool {
        pacePoints != nil || elevationPoints != nil || hrPoints != nil
            || cadencePoints != nil || splits != nil
    }
}

extension HealthKitManager {

    /// Builds a cloud-persistable blob from a logged run's HealthKit data.
    /// Returns nil when the device has no HK data for the run (e.g. the run
    /// was logged on a different device, or HK auth is denied) so callers
    /// can decide whether to skip persisting a useless empty blob.
    func buildAnalyticsBlob(matching run: LoggedRun) async -> RunAnalyticsBlob? {
        async let analyticsTask = fetchRunAnalytics(matching: run)
        async let routeTask = fetchRoute(matching: run)
        let analytics = await analyticsTask
        let route = await routeTask
        return RunAnalyticsBlob(analytics: analytics, route: route)
    }

    /// Variant used by the historical importer. Skips the date+distance
    /// workout lookup since the caller already has the `HKWorkout` in hand —
    /// halves HK round-trips when processing hundreds of workouts in a row.
    func buildAnalyticsBlob(for workout: HKWorkout) async -> RunAnalyticsBlob? {
        async let analyticsTask = fetchRunAnalytics(for: workout)
        async let routeTask = fetchRouteCoordinates(for: workout)
        let analytics = await analyticsTask
        let route = await routeTask
        return RunAnalyticsBlob(analytics: analytics, route: route)
    }

    /// Pulls all the rich analytics needed for `RunDetailView` charts. Locates the
    /// matching `HKWorkout` (same fuzzy date+distance match used elsewhere), then
    /// fans out parallel queries for HR samples, route locations, and (iOS 16+)
    /// running-speed samples. Returns whichever data Apple Health has — caller
    /// hides any cards whose underlying field is `nil`.
    func fetchRunAnalytics(matching run: LoggedRun) async -> RunAnalytics? {
        guard HKHealthStore.isHealthDataAvailable() else { return nil }
        guard let workout = await findMatchingWorkout(for: run) else { return nil }
        return await fetchRunAnalytics(for: workout)
    }

    /// Same analytics extraction as `fetchRunAnalytics(matching:)` but without
    /// the workout lookup. Importer path uses this directly.
    func fetchRunAnalytics(for workout: HKWorkout) async -> RunAnalytics? {
        guard HKHealthStore.isHealthDataAvailable() else { return nil }

        async let routeLocations = fetchRouteLocations(for: workout)
        async let hrSamples = fetchHeartRateSamples(during: workout)
        async let stepSamplesTask = fetchStepCountSamples(during: workout)

        let route = await routeLocations
        let hr = await hrSamples
        // Step samples are written by both the Apple Watch and the paired iPhone during a
        // workout. Mixing the two sources gives overlapping intervals which makes the chart
        // line loop back on itself, so we keep only the workout-recording source's samples.
        let workoutSource = workout.sourceRevision.source
        let steps = await stepSamplesTask.filter { $0.sourceRevision.source == workoutSource }

        let elevationPoints = elevationPoints(from: route)
        let pacePoints = pacePoints(from: route)
        let hrPoints = hrPoints(from: hr, workoutStart: workout.startDate)
        let cadencePoints = cadencePoints(from: steps, workoutStart: workout.startDate)
        let splits = computeSplits(route: route, hrSamples: hr)
        let zones = computeHRZones(samples: hr, workoutEnd: workout.endDate)
        let avgCadence = cadencePoints.isEmpty ? nil : Int(cadencePoints.map(\.spm).reduce(0, +) / Double(cadencePoints.count))

        let bpmUnit = HKUnit.count().unitDivided(by: .minute())
        let avgHR: Int? = {
            guard !hr.isEmpty else { return nil }
            let sum = hr.reduce(0.0) { $0 + $1.quantity.doubleValue(for: bpmUnit) }
            return Int(sum / Double(hr.count))
        }()
        let maxHR = hr.map { $0.quantity.doubleValue(for: bpmUnit) }.max().map { Int($0) }
        let elevGain = elevationGainTotal(from: route)

        return RunAnalytics(
            pacePoints: pacePoints.isEmpty ? nil : pacePoints,
            elevationPoints: elevationPoints.isEmpty ? nil : elevationPoints,
            hrPoints: hrPoints.isEmpty ? nil : hrPoints,
            cadencePoints: cadencePoints.isEmpty ? nil : cadencePoints,
            splits: splits.isEmpty ? nil : splits,
            hrZoneDistribution: zones,
            elevationGainMeters: elevGain,
            avgHeartRate: avgHR,
            maxHeartRate: maxHR,
            avgCadenceSPM: avgCadence
        )
    }

    // MARK: - Workout match

    private func findMatchingWorkout(for run: LoggedRun) async -> HKWorkout? {
        let cal = Calendar.current
        let dayStart = cal.date(byAdding: .day, value: -1, to: cal.startOfDay(for: run.runDate)) ?? run.runDate
        guard let dayEnd = cal.date(byAdding: .day, value: 2, to: cal.startOfDay(for: run.runDate)) else { return nil }
        let predicate = HKQuery.predicateForSamples(withStart: dayStart, end: dayEnd, options: [])

        let workouts: [HKWorkout] = await withCheckedContinuation { cont in
            let query = HKSampleQuery(
                sampleType: HKObjectType.workoutType(),
                predicate: predicate,
                limit: 50,
                sortDescriptors: nil
            ) { _, results, _ in
                cont.resume(returning: (results as? [HKWorkout]) ?? [])
            }
            healthStore.execute(query)
        }

        let target = run.distanceKm * 1000
        let runningOnly = workouts.filter { $0.workoutActivityType == .running }
        let candidates = runningOnly.isEmpty ? workouts : runningOnly
        return candidates.min(by: {
            let dA = abs(($0.totalDistance?.doubleValue(for: .meter()) ?? 0) - target)
            let dB = abs(($1.totalDistance?.doubleValue(for: .meter()) ?? 0) - target)
            return dA < dB
        })
    }

    // MARK: - Route locations (with altitude + timestamps)

    func fetchRouteLocations(for workout: HKWorkout) async -> [CLLocation] {
        let routeType = HKSeriesType.workoutRoute()
        let linkedPredicate = HKQuery.predicateForObjects(from: workout)
        var routes: [HKWorkoutRoute] = await withCheckedContinuation { cont in
            let query = HKSampleQuery(
                sampleType: routeType,
                predicate: linkedPredicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, results, _ in
                cont.resume(returning: (results as? [HKWorkoutRoute]) ?? [])
            }
            healthStore.execute(query)
        }
        if routes.isEmpty {
            let timePredicate = HKQuery.predicateForSamples(
                withStart: workout.startDate,
                end: workout.endDate,
                options: .strictStartDate
            )
            routes = await withCheckedContinuation { cont in
                let query = HKSampleQuery(
                    sampleType: routeType,
                    predicate: timePredicate,
                    limit: 1,
                    sortDescriptors: nil
                ) { _, results, _ in
                    cont.resume(returning: (results as? [HKWorkoutRoute]) ?? [])
                }
                healthStore.execute(query)
            }
        }

        guard let route = routes.first else { return [] }

        final class Accumulator: @unchecked Sendable {
            var locations: [CLLocation] = []
        }
        let acc = Accumulator()

        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            var resumed = false
            let query = HKWorkoutRouteQuery(route: route) { _, locations, done, _ in
                if let locations { acc.locations.append(contentsOf: locations) }
                if done && !resumed {
                    resumed = true
                    cont.resume()
                }
            }
            healthStore.execute(query)
        }

        return acc.locations.sorted { $0.timestamp < $1.timestamp }
    }

    // MARK: - HR samples

    private func fetchHeartRateSamples(during workout: HKWorkout) async -> [HKQuantitySample] {
        guard let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return [] }
        let predicate = HKQuery.predicateForSamples(
            withStart: workout.startDate,
            end: workout.endDate,
            options: .strictStartDate
        )
        return await withCheckedContinuation { cont in
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
            let query = HKSampleQuery(
                sampleType: hrType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sort]
            ) { _, results, _ in
                cont.resume(returning: (results as? [HKQuantitySample]) ?? [])
            }
            healthStore.execute(query)
        }
    }

    private func fetchStepCountSamples(during workout: HKWorkout) async -> [HKQuantitySample] {
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return [] }
        let predicate = HKQuery.predicateForSamples(
            withStart: workout.startDate,
            end: workout.endDate,
            options: .strictStartDate
        )
        return await withCheckedContinuation { cont in
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
            let query = HKSampleQuery(
                sampleType: stepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sort]
            ) { _, results, _ in
                cont.resume(returning: (results as? [HKQuantitySample]) ?? [])
            }
            healthStore.execute(query)
        }
    }

    // MARK: - Derivations

    private func elevationPoints(from locations: [CLLocation]) -> [RunAnalytics.ElevationPoint] {
        guard locations.count > 1 else { return [] }
        var points: [RunAnalytics.ElevationPoint] = []
        var cumulativeMeters: Double = 0
        points.reserveCapacity(locations.count)
        for i in 0..<locations.count {
            if i > 0 { cumulativeMeters += locations[i].distance(from: locations[i - 1]) }
            if locations[i].verticalAccuracy >= 0 {
                points.append(.init(distanceKm: cumulativeMeters / 1000, altitudeMeters: locations[i].altitude))
            }
        }
        return downsample(points, target: 120) { $0.distanceKm }
    }

    private func pacePoints(from locations: [CLLocation]) -> [RunAnalytics.PacePoint] {
        guard locations.count > 5 else { return [] }
        // Use a 50m sliding window for instantaneous pace (smooths out GPS jitter without
        // losing detail). For each anchor point, look back ~50m and divide that
        // segment's elapsed time by its distance.
        let windowMeters: Double = 50
        var cumulative: [Double] = [0]
        for i in 1..<locations.count {
            cumulative.append(cumulative[i - 1] + locations[i].distance(from: locations[i - 1]))
        }

        var points: [RunAnalytics.PacePoint] = []
        for i in 0..<locations.count {
            let dist = cumulative[i]
            // Find the earliest j where cumulative[i] - cumulative[j] >= windowMeters
            var j = i
            while j > 0 && (dist - cumulative[j]) < windowMeters { j -= 1 }
            let dDist = dist - cumulative[j]
            let dTime = locations[i].timestamp.timeIntervalSince(locations[j].timestamp)
            guard dDist > 5, dTime > 0 else { continue }
            let speedMps = dDist / dTime
            guard speedMps > 0.5 else { continue } // ignore standing still
            let paceSecPerKm = 1000 / speedMps
            // Sanity clamp 2:00–20:00 /km
            guard paceSecPerKm > 120, paceSecPerKm < 1200 else { continue }
            points.append(.init(distanceKm: dist / 1000, paceSecPerKm: paceSecPerKm))
        }
        return downsample(points, target: 120) { $0.distanceKm }
    }

    private func hrPoints(from samples: [HKQuantitySample], workoutStart: Date) -> [RunAnalytics.HRPoint] {
        guard !samples.isEmpty else { return [] }
        let bpmUnit = HKUnit.count().unitDivided(by: .minute())
        let raw = samples.map { sample in
            RunAnalytics.HRPoint(
                elapsed: sample.startDate.timeIntervalSince(workoutStart),
                bpm: sample.quantity.doubleValue(for: bpmUnit)
            )
        }
        return downsample(raw, target: 120) { $0.elapsed }
    }

    /// Apple Watch writes step-count samples at intervals during a workout, each with
    /// a step count over its own duration. Cadence (SPM) = steps / duration_seconds * 60.
    /// Filters out tiny samples that would produce unreliable rates.
    private func cadencePoints(from samples: [HKQuantitySample], workoutStart: Date) -> [RunAnalytics.CadencePoint] {
        guard !samples.isEmpty else { return [] }
        let countUnit = HKUnit.count()
        var raw: [RunAnalytics.CadencePoint] = []
        raw.reserveCapacity(samples.count)
        for sample in samples {
            let duration = sample.endDate.timeIntervalSince(sample.startDate)
            guard duration >= 5 else { continue } // need at least 5s to derive a stable rate
            let steps = sample.quantity.doubleValue(for: countUnit)
            let spm = steps / duration * 60
            // Sanity clamp: walking ~80 SPM, sprinting ~220 SPM
            guard spm > 60, spm < 240 else { continue }
            // Anchor each point at the sample's midpoint for a smoother chart
            let midpoint = sample.startDate.addingTimeInterval(duration / 2)
            raw.append(.init(elapsed: midpoint.timeIntervalSince(workoutStart), spm: spm))
        }
        // Belt-and-braces: enforce monotonic X order so the chart's `.monotone` interpolation
        // can't produce visible loops if the source wrote samples out-of-order.
        let sorted = raw.sorted { $0.elapsed < $1.elapsed }
        return downsample(sorted, target: 120) { $0.elapsed }
    }

    private func computeSplits(route: [CLLocation], hrSamples: [HKQuantitySample]) -> [RunAnalytics.Split] {
        guard route.count > 1 else { return [] }
        let bpmUnit = HKUnit.count().unitDivided(by: .minute())

        var splits: [RunAnalytics.Split] = []
        var cumulative: Double = 0
        var splitStartTime = route.first!.timestamp
        var splitStartCumulative: Double = 0
        var nextKm: Double = 1000

        for i in 1..<route.count {
            cumulative += route[i].distance(from: route[i - 1])
            while cumulative >= nextKm {
                // Linear interpolate the moment the runner crossed the km boundary
                let prevCum = cumulative - route[i].distance(from: route[i - 1])
                let frac = (nextKm - prevCum) / (cumulative - prevCum)
                let crossingTime = route[i - 1].timestamp.addingTimeInterval(
                    route[i].timestamp.timeIntervalSince(route[i - 1].timestamp) * frac
                )
                let duration = crossingTime.timeIntervalSince(splitStartTime)
                let avgHR = averageHR(samples: hrSamples, start: splitStartTime, end: crossingTime, unit: bpmUnit)
                splits.append(.init(
                    index: splits.count + 1,
                    distanceKm: (nextKm - splitStartCumulative) / 1000,
                    durationSeconds: duration,
                    avgHRBpm: avgHR
                ))
                splitStartTime = crossingTime
                splitStartCumulative = nextKm
                nextKm += 1000
            }
        }
        // Trailing partial split if leftover distance > 50m
        let trailing = cumulative - splitStartCumulative
        if trailing > 50 {
            let endTime = route.last!.timestamp
            let avgHR = averageHR(samples: hrSamples, start: splitStartTime, end: endTime, unit: bpmUnit)
            splits.append(.init(
                index: splits.count + 1,
                distanceKm: trailing / 1000,
                durationSeconds: endTime.timeIntervalSince(splitStartTime),
                avgHRBpm: avgHR
            ))
        }
        return splits
    }

    private func averageHR(samples: [HKQuantitySample], start: Date, end: Date, unit: HKUnit) -> Int? {
        let inRange = samples.filter { $0.startDate >= start && $0.startDate <= end }
        guard !inRange.isEmpty else { return nil }
        let sum = inRange.reduce(0.0) { $0 + $1.quantity.doubleValue(for: unit) }
        return Int(sum / Double(inRange.count))
    }

    private func computeHRZones(samples: [HKQuantitySample], workoutEnd: Date) -> RunAnalytics.HRZoneDistribution? {
        guard !samples.isEmpty else { return nil }
        guard let dob = (try? healthStore.dateOfBirthComponents()).flatMap({ Calendar.current.date(from: $0) }) else { return nil }
        let years = Calendar.current.dateComponents([.year], from: dob, to: Date()).year ?? 30
        let maxHR = max(120, 220 - years)
        let bpmUnit = HKUnit.count().unitDivided(by: .minute())

        // Each sample represents an HR reading at a point. Treat each sample as
        // "valid until the next sample's startDate" and bucket the duration into
        // a zone based on the sample's BPM as a fraction of maxHR.
        // Z1: <60%, Z2: 60-70%, Z3: 70-80%, Z4: 80-90%, Z5: ≥90%.
        var zoneSeconds = [TimeInterval](repeating: 0, count: 5)
        for i in 0..<samples.count {
            let bpm = samples[i].quantity.doubleValue(for: bpmUnit)
            let pct = bpm / Double(maxHR)
            let zoneIdx: Int
            switch pct {
            case ..<0.60:    zoneIdx = 0
            case 0.60..<0.70: zoneIdx = 1
            case 0.70..<0.80: zoneIdx = 2
            case 0.80..<0.90: zoneIdx = 3
            default:         zoneIdx = 4
            }
            let nextStart = i + 1 < samples.count ? samples[i + 1].startDate : workoutEnd
            let duration = max(0, nextStart.timeIntervalSince(samples[i].startDate))
            // Cap any single sample's contribution at 60s to avoid wildly long
            // gaps (e.g., HR sensor dropout) skewing the distribution.
            zoneSeconds[zoneIdx] += min(duration, 60)
        }

        let total = zoneSeconds.reduce(0, +)
        guard total > 0 else { return nil }
        return RunAnalytics.HRZoneDistribution(secondsPerZone: zoneSeconds, maxHR: maxHR)
    }

    private func elevationGainTotal(from locations: [CLLocation]) -> Int? {
        guard locations.count > 1 else { return nil }
        let altitudes = locations.compactMap { $0.verticalAccuracy >= 0 ? $0.altitude : nil }
        guard altitudes.count > 1 else { return nil }
        let radius = 2
        var smoothed: [Double] = []
        smoothed.reserveCapacity(altitudes.count)
        for i in 0..<altitudes.count {
            let lo = max(0, i - radius)
            let hi = min(altitudes.count, i + radius + 1)
            let slice = altitudes[lo..<hi]
            smoothed.append(slice.reduce(0, +) / Double(slice.count))
        }
        let noise: Double = 1.0
        var total: Double = 0
        var pending: Double = 0
        for i in 1..<smoothed.count {
            let delta = smoothed[i] - smoothed[i - 1]
            if delta > 0 { pending += delta }
            else if delta < 0 {
                if pending >= noise { total += pending }
                pending = 0
            }
        }
        if pending >= noise { total += pending }
        return total > 0 ? Int(total) : nil
    }

    /// Sliding-window fastest-segment finder. Walks the route and, for each end
    /// anchor `i`, advances a start anchor so the segment covers exactly
    /// `targetMeters` (linearly interpolating across the boundary segment).
    /// Used to derive PBs for benchmark distances from inside longer runs —
    /// e.g., the fastest single km buried inside a 10K.
    func bestSegmentSeconds(in route: [CLLocation], distanceMeters target: Double) -> TimeInterval? {
        guard route.count > 1, target > 0 else { return nil }

        var cumulative: [Double] = [0]
        cumulative.reserveCapacity(route.count)
        for i in 1..<route.count {
            cumulative.append(cumulative[i - 1] + route[i].distance(from: route[i - 1]))
        }
        guard let totalDist = cumulative.last, totalDist >= target else { return nil }

        var best: TimeInterval = .infinity
        var j = 0
        for i in 1..<route.count {
            let threshold = cumulative[i] - target
            if threshold < 0 { continue }
            // Advance j to the latest index where cumulative[j] <= threshold.
            while j + 1 < i && cumulative[j + 1] <= threshold {
                j += 1
            }
            let segDist = cumulative[j + 1] - cumulative[j]
            let frac = segDist > 0 ? (threshold - cumulative[j]) / segDist : 0
            let dt = route[j + 1].timestamp.timeIntervalSince(route[j].timestamp)
            let interpStart = route[j].timestamp.addingTimeInterval(dt * frac)
            let elapsed = route[i].timestamp.timeIntervalSince(interpStart)
            // Sanity: segment pace must be between 2:00 and 20:00 /km
            // (`target` is in metres so this is just `target / pace`).
            guard elapsed > 0 else { continue }
            let paceSecPerKm = elapsed / (target / 1000)
            guard paceSecPerKm > 120, paceSecPerKm < 1200 else { continue }
            if elapsed < best { best = elapsed }
        }
        return best.isFinite ? best : nil
    }

    /// Reduces a series to roughly `target` evenly-spaced points. Charts render
    /// noticeably faster on a few hundred data points than several thousand
    /// raw HR/route samples, with no visible quality loss.
    private func downsample<T>(_ items: [T], target: Int, key: (T) -> Double) -> [T] {
        guard items.count > target * 2 else { return items }
        let stride = items.count / target
        var out: [T] = []
        out.reserveCapacity(target)
        var i = 0
        while i < items.count {
            out.append(items[i])
            i += stride
        }
        if out.last.map({ key($0) }) != items.last.map({ key($0) }) { out.append(items.last!) }
        return out
    }
}

//
//  HealthKitRunTimes.swift
//  Yumo
//
//  Pulls the user's best times per benchmark distance (1K, 5K, 10K, HM, Full)
//  from recent Apple Health running workouts. Used to pre-fill the running
//  onboarding's recent-times page so the AI plan generator has accurate
//  pace calibration data.
//

import Foundation

struct RunTimeCandidates: Sendable, Equatable {
    var k1Seconds: Int?
    var k5Seconds: Int?
    var k10Seconds: Int?
    var halfMarathonSeconds: Int?
    var marathonSeconds: Int?

    var hasAny: Bool {
        k1Seconds != nil || k5Seconds != nil || k10Seconds != nil
            || halfMarathonSeconds != nil || marathonSeconds != nil
    }
}

enum HealthKitRunTimes {

    /// Fetches recent runs from HealthKit and returns the fastest time found
    /// for each benchmark distance (within ±5% tolerance). Intended for
    /// "auto-fill from Apple Health" in onboarding.
    static func fetchRecentBestTimes(daysBack: Int = 120) async -> RunTimeCandidates {
        let manager = HealthKitManager.shared
        let runs = await manager.fetchRecentRuns(limit: 500, daysBack: daysBack)

        var candidates = RunTimeCandidates()

        for run in runs {
            guard let meters = run.distanceMeters, meters > 0 else { continue }
            let km = meters / 1000.0
            let seconds = Int((run.durationMinutes * 60.0).rounded())
            guard seconds > 0 else { continue }

            // Only count workouts that are within ±5% of the benchmark distance.
            // A 5K workout at 4.8–5.25 km counts as a 5K time.
            if km >= 0.95 && km <= 1.05 {
                candidates.k1Seconds = min(candidates.k1Seconds ?? .max, seconds)
            }
            if km >= 4.75 && km <= 5.25 {
                candidates.k5Seconds = min(candidates.k5Seconds ?? .max, seconds)
            }
            if km >= 9.5 && km <= 10.5 {
                candidates.k10Seconds = min(candidates.k10Seconds ?? .max, seconds)
            }
            if km >= 20.05 && km <= 22.15 {
                candidates.halfMarathonSeconds = min(candidates.halfMarathonSeconds ?? .max, seconds)
            }
            if km >= 40.1 && km <= 44.3 {
                candidates.marathonSeconds = min(candidates.marathonSeconds ?? .max, seconds)
            }
        }

        // Never return .max sentinels from the `min` trick above.
        func clean(_ v: Int?) -> Int? { (v == .max) ? nil : v }
        candidates.k1Seconds = clean(candidates.k1Seconds)
        candidates.k5Seconds = clean(candidates.k5Seconds)
        candidates.k10Seconds = clean(candidates.k10Seconds)
        candidates.halfMarathonSeconds = clean(candidates.halfMarathonSeconds)
        candidates.marathonSeconds = clean(candidates.marathonSeconds)

        return candidates
    }
}

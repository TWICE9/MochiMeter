//
//  RunningPlanPreviewBuilder.swift
//  Yumo
//
//  Builds a representative first-week training schedule from the user's
//  onboarding answers. Used purely for the on-screen preview before plan
//  generation — the actual plan still comes from the AI generator and may
//  differ. The goal here is to set expectations and add a "wow" moment
//  before the user commits to "Finish Setup".
//

import Foundation

struct PreviewSession: Identifiable {
    let id = UUID()
    let weekday: Weekday
    let type: RunningSessionType
    let title: String
    let detail: String

    var isRun: Bool { type.isRun }
}

enum RunningPlanPreviewBuilder {

    /// Returns 7 sessions, one per weekday in Mon→Sun order.
    static func buildWeek(from fm: RunningOnboardingFlowManager) -> [PreviewSession] {
        let allDays: [Weekday] = [.mon, .tue, .wed, .thu, .fri, .sat, .sun]
        let availableSorted = allDays.filter { fm.availableDays.contains($0) }

        guard !availableSorted.isEmpty else {
            return allDays.map { PreviewSession(weekday: $0, type: .rest, title: "Rest", detail: "Add at least one running day") }
        }

        // Flatten the per-activity schedule so the canonical day selection
        // can dodge days the user already trains.
        let crossDays = Set(fm.crossTrainingSchedule.values.flatMap { $0 })

        // Honour the user's weekly target — they may flag more days as "available"
        // than they actually want to run (validation only requires
        // availableDays.count >= weeklyRunDaysTarget).
        let runDays = chooseRunDays(
            from: availableSorted,
            target: max(1, fm.weeklyRunDaysTarget),
            longRunDay: fm.longRunDay,
            crossTrainingDays: crossDays
        )

        let assignments = assignTypes(
            runDays: runDays,
            longRunDay: fm.longRunDay,
            goal: fm.primaryGoal,
            raceDistance: fm.targetRaceDistance,
            experience: fm.experience
        )

        let scale = volumeScale(for: fm)
        let imperial = fm.isImperial

        return allDays.map { day in
            guard let type = assignments[day] else {
                return PreviewSession(weekday: day, type: .rest, title: "Rest", detail: "Recovery & gentle stretching")
            }
            return session(for: type, on: day, scale: scale, imperial: imperial, experience: fm.experience)
        }
    }

    /// Selects exactly `target` days out of the available set, anchored on the
    /// long-run day (when set) and spaced as evenly as possible across the rest
    /// to avoid back-to-back runs. Returns Mon→Sun order.
    ///
    /// Internal (not private) so the onboarding submit path can call this with
    /// the exact same state the preview saw, then send the canonical days to
    /// the edge function. That guarantees `preview ≡ generated plan` regardless
    /// of any drift in `long_run_day` between client and server.
    ///
    /// `crossTrainingDays` is a soft constraint: the algorithm prefers days
    /// the user *isn't* already cross-training on. Falls back to the full
    /// available set if dodging cross days would leave us short of `target`,
    /// or if even the long-run day lands on a cross day with no alternative.
    static func chooseRunDays(
        from available: [Weekday],
        target: Int,
        longRunDay: Weekday?,
        crossTrainingDays: Set<Weekday> = []
    ) -> [Weekday] {
        guard available.count > target else { return available }

        // Decide whether to honour the user's long-run-day anchor. If it
        // collides with a cross-training day AND we have enough non-cross
        // days to meet the target, we ignore the anchor — silently picking
        // a long-run day that conflicts with the user's gym schedule is
        // worse UX than nudging them to a freer day.
        let nonCrossAvailable = available.filter { !crossTrainingDays.contains($0) }
        let hasNonCrossRoom = nonCrossAvailable.count >= target

        var picked: Set<Weekday> = []
        if let day = longRunDay,
           available.contains(day),
           !(crossTrainingDays.contains(day) && hasNonCrossRoom) {
            picked.insert(day)
        }

        let remaining = available.filter { !picked.contains($0) }
        let needed = target - picked.count

        if needed > 0 {
            // Prefer days the user isn't already training on. Only drop this
            // preference if we'd otherwise be unable to fill `target`.
            let nonCrossRemaining = remaining.filter { !crossTrainingDays.contains($0) }
            let pool = nonCrossRemaining.count >= needed ? nonCrossRemaining : remaining

            // Even-spacing pick: take indices distributed across `pool` by
            // float stride so ranges like 4-of-6 land on day 0, 2, 4 rather
            // than 0, 1, 2, 3.
            let stride = Double(pool.count) / Double(needed)
            for i in 0..<needed {
                let idx = min(pool.count - 1, Int((Double(i) * stride).rounded(.down)))
                picked.insert(pool[idx])
            }
            // Rounding collisions can leave us short — fill from the front
            // of the *full* remaining set so we always hit the target.
            var fillIdx = 0
            while picked.count < target, fillIdx < remaining.count {
                picked.insert(remaining[fillIdx])
                fillIdx += 1
            }
        }

        let order: [Weekday] = [.mon, .tue, .wed, .thu, .fri, .sat, .sun]
        return order.filter { picked.contains($0) }
    }

    // MARK: - Type assignment

    /// Assigns a session type to each running day. Long run goes on the
    /// preferred day (or the last available day), quality sessions go midweek
    /// where possible, and the rest are easy runs.
    private static func assignTypes(
        runDays: [Weekday],
        longRunDay: Weekday?,
        goal: RunningGoalType,
        raceDistance: RaceDistance?,
        experience: RunningExperience
    ) -> [Weekday: RunningSessionType] {
        var result: [Weekday: RunningSessionType] = [:]
        guard !runDays.isEmpty else { return result }

        // 1. Long run slot
        let longSlot: Weekday? = {
            if runDays.count < 2 { return nil }   // single run — keep it easy
            if let day = longRunDay, runDays.contains(day) { return day }
            return runDays.last
        }()
        if let day = longSlot { result[day] = .long }

        // 2. Quality (tempo / intervals) count
        let qualityTypes = qualityPool(goal: goal, raceDistance: raceDistance)
        let qualityCount: Int = {
            if runDays.count <= 3 { return 0 }
            let cap: Int
            switch experience {
            case .never:        cap = 0
            case .beginner:     cap = 1
            case .intermediate: cap = runDays.count >= 5 ? 2 : 1
            case .advanced:     cap = runDays.count >= 5 ? 2 : 1
            }
            return min(cap, qualityTypes.count)
        }()

        // 3. Place quality sessions on midweek days, away from the long run.
        let nonLongDays = runDays.filter { result[$0] == nil }
        let midweekFirst = nonLongDays.sorted { lhs, rhs in
            // Prefer Tue/Wed/Thu, then everything else, but always avoid the day immediately
            // before the long run when possible.
            let lhsScore = midweekScore(lhs, longSlot: longSlot)
            let rhsScore = midweekScore(rhs, longSlot: longSlot)
            return lhsScore < rhsScore
        }
        for i in 0..<qualityCount {
            let day = midweekFirst[i]
            result[day] = qualityTypes[i]
        }

        // 4. Remaining days get easy runs (or recovery for 6+ day weeks).
        let remaining = runDays.filter { result[$0] == nil }
        let needsRecovery = runDays.count >= 6 && experience != .never
        for (idx, day) in remaining.enumerated() {
            if needsRecovery && idx == 0 {
                result[day] = .recovery
            } else {
                result[day] = .easy
            }
        }

        return result
    }

    /// Lower score = better candidate for a quality session.
    private static func midweekScore(_ day: Weekday, longSlot: Weekday?) -> Int {
        let base: Int
        switch day {
        case .tue: base = 0
        case .wed: base = 1
        case .thu: base = 2
        case .mon: base = 3
        case .fri: base = 4
        case .sat: base = 5
        case .sun: base = 6
        }
        // Penalty for being adjacent to the long run.
        if let long = longSlot, isAdjacent(day: day, to: long) {
            return base + 10
        }
        return base
    }

    private static func isAdjacent(day: Weekday, to other: Weekday) -> Bool {
        let order: [Weekday] = [.mon, .tue, .wed, .thu, .fri, .sat, .sun]
        guard let a = order.firstIndex(of: day), let b = order.firstIndex(of: other) else { return false }
        return abs(a - b) == 1
    }

    private static func qualityPool(goal: RunningGoalType, raceDistance: RaceDistance?) -> [RunningSessionType] {
        switch goal {
        case .trainForRace:
            switch raceDistance {
            case .k5, .k10:    return [.intervals, .tempo]
            case .half:        return [.tempo, .intervals]
            case .full, .none: return [.tempo, .easy]   // marathons stay aerobic in week 1
            }
        case .improvePace:    return [.intervals, .tempo]
        case .buildDistance:  return [.tempo]
        case .generalFitness, .loseWeight:
            // Keep it easy — maybe one tempo for 4+ day weeks.
            return [.tempo]
        }
    }

    // MARK: - Volume scaling

    /// Multiplier applied to baseline distances. Calibrated so intermediate ≈ 1.0.
    /// Week-1 volumes are intentionally conservative — most plans ramp from here.
    private static func volumeScale(for fm: RunningOnboardingFlowManager) -> Double {
        let experienceScale: Double
        switch fm.experience {
        case .never:        experienceScale = 0.4
        case .beginner:     experienceScale = 0.7
        case .intermediate: experienceScale = 1.0
        case .advanced:     experienceScale = 1.3
        }
        // If the user told us their current weekly volume, use it as a soft anchor.
        if let weekly = fm.currentWeeklyKm, weekly > 0 {
            let weeklyAnchor = min(1.6, weekly / 40.0)   // 40 km/wk ≈ intermediate baseline
            return (experienceScale + weeklyAnchor) / 2.0
        }
        return experienceScale
    }

    // MARK: - Session detail builders

    private static func session(
        for type: RunningSessionType,
        on day: Weekday,
        scale: Double,
        imperial: Bool,
        experience: RunningExperience
    ) -> PreviewSession {
        switch type {
        case .easy:
            return PreviewSession(
                weekday: day, type: .easy,
                title: "Easy run",
                detail: detailEasy(scale: scale, imperial: imperial, experience: experience)
            )
        case .long:
            return PreviewSession(
                weekday: day, type: .long,
                title: "Long run",
                detail: detailLong(scale: scale, imperial: imperial)
            )
        case .tempo:
            return PreviewSession(
                weekday: day, type: .tempo,
                title: "Tempo run",
                detail: detailTempo(scale: scale, imperial: imperial)
            )
        case .intervals:
            return PreviewSession(
                weekday: day, type: .intervals,
                title: "Intervals",
                detail: detailIntervals(scale: scale)
            )
        case .recovery:
            return PreviewSession(
                weekday: day, type: .recovery,
                title: "Recovery jog",
                detail: detailRecovery(scale: scale, imperial: imperial)
            )
        case .rest:
            return PreviewSession(weekday: day, type: .rest, title: "Rest", detail: "Recovery & gentle stretching")
        case .cross:
            return PreviewSession(weekday: day, type: .cross, title: "Cross-train", detail: "Strength, yoga, or low-impact cardio")
        case .race:
            return PreviewSession(weekday: day, type: .race, title: "Race", detail: "Race day!")
        }
    }

    private static func detailEasy(scale: Double, imperial: Bool, experience: RunningExperience) -> String {
        if experience == .never {
            // Couch-to-5K style framing keeps it approachable.
            return "20 min walk/run intervals"
        }
        let km = roundedKm(4.0 * scale)
        return "\(formatDistance(km, imperial: imperial)) at conversational pace"
    }

    private static func detailLong(scale: Double, imperial: Bool) -> String {
        let km = roundedKm(8.0 * scale)
        return "\(formatDistance(km, imperial: imperial)) — your long run of the week"
    }

    private static func detailTempo(scale: Double, imperial: Bool) -> String {
        let km = roundedKm(5.0 * scale)
        return "\(formatDistance(km, imperial: imperial)) with the middle at threshold pace"
    }

    private static func detailIntervals(scale: Double) -> String {
        // Number of reps scales with experience-derived volume.
        let reps = max(3, min(8, Int((4.0 * scale).rounded())))
        return "\(reps) × 800m fast, 90s jog recovery"
    }

    private static func detailRecovery(scale: Double, imperial: Bool) -> String {
        let km = roundedKm(3.0 * scale)
        return "\(formatDistance(km, imperial: imperial)) very easy — shake out the legs"
    }

    // MARK: - Number formatting

    /// Rounds to the nearest 0.5 km, with a 1 km floor to avoid trivial-looking
    /// distances on the preview.
    private static func roundedKm(_ km: Double) -> Double {
        let rounded = (km * 2).rounded() / 2
        return max(1.0, rounded)
    }

    private static func formatDistance(_ km: Double, imperial: Bool) -> String {
        if imperial {
            let mi = km * 0.621371
            let rounded = (mi * 2).rounded() / 2
            return rounded.truncatingRemainder(dividingBy: 1) == 0
                ? "\(Int(rounded)) mi"
                : String(format: "%.1f mi", rounded)
        }
        return km.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(km)) km"
            : String(format: "%.1f km", km)
    }
}

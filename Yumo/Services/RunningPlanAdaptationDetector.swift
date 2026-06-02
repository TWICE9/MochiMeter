//
//  RunningPlanAdaptationDetector.swift
//  Yumo
//
//  Phase 2 of plan adaptation: passive detection of "the runner needs a
//  course correction" signals on cold launch. When a signal fires, we call
//  `adapt-running-plan` automatically — the existing banner pipeline
//  surfaces the AI's summary so the user sees what changed.
//
//  Server enforces a 7-day cooldown for `auto_*` reasons. We mirror it on
//  the client so we don't burn round-trips when we know we'll be rejected.
//

import Foundation
import SwiftData

@MainActor
enum RunningPlanAdaptationDetector {

    // MARK: - Tunables

    /// Number of consecutive past run sessions left uncompleted before we
    /// fire `auto_misses`. 3 is intentionally conservative — one missed week
    /// for someone running 3×/week shouldn't trigger an ease-back.
    static let consecutiveMissesThreshold = 3

    /// Minimum number of recently-completed quality sessions required before
    /// the pace-fast check has anything to say.
    static let paceFastMinSessions = 4

    /// Average pace deviation across the recent quality window that counts
    /// as "consistently faster" — 5% means roughly 12-15 s/km off prescribed.
    static let paceFastDeltaPercent: Double = 0.05

    /// Mirrors the server-side `AUTO_RATE_LIMIT_MS` in adapt-running-plan.
    /// Bail before invoking the edge function when we know it'll 429.
    static let autoCooldownDays = 7

    /// Don't auto-adapt a brand-new plan. Users need real engagement data
    /// before adjustments make sense, and plans that backfill their
    /// `start_date` to a past Monday would otherwise count untouchable
    /// pre-creation days as "missed" the moment midnight ticks over.
    static let minPlanAgeDays = 14

    // MARK: - Detection result

    struct Result {
        let reason: AdaptationReason
        let signal: AdaptationSignal
    }

    // MARK: - Public

    /// Inspects the active plan + adaptation history and returns the
    /// highest-priority signal, or nil if nothing warrants an adjustment.
    /// Order of precedence: misses (most disruptive, ease back fast) →
    /// pace-fast (recalibrate up). Only one signal fires per call.
    static func detect(
        plan: RunningPlan,
        adaptations: [RunningPlanAdaptation],
        now: Date = Date()
    ) -> Result? {
        guard isOutOfCooldown(adaptations: adaptations, now: now) else { return nil }

        if let result = detectConsecutiveMisses(plan: plan, now: now) { return result }
        if let result = detectPaceConsistentlyFast(plan: plan) { return result }
        return nil
    }

    /// Convenience entry point used at app launch. Pulls the active plan +
    /// adaptation history from SwiftData, runs detection, and triggers an
    /// adaptation if a signal fires. Failures are non-fatal.
    static func runIfNeeded(context: ModelContext) async {
        // Premium-gated. Free users get the weekly check-in only — auto-detect
        // is the "magic" tier, plus it costs us an OpenAI call we don't want
        // to spend on non-converting users at launch.
        guard StoreKitManager.shared.isPremium else { return }

        let plansFetch = FetchDescriptor<RunningPlan>()
        guard let activePlan = (try? context.fetch(plansFetch))?
            .first(where: { $0.status == .active })
        else { return }

        // Need at least a few sessions to draw any conclusion. A brand-new
        // plan with no completions or misses isn't ready to be auto-tuned.
        guard !activePlan.sessions.isEmpty else { return }

        // Plan-age guard: don't react to "missed" sessions on a fresh plan.
        // The edge function backfills `start_date` to the most recent Monday,
        // so a Sunday-night-generated plan rolls into Monday already showing
        // 6 "missed" pre-creation days. Wait until the plan has had real
        // training time before adapting.
        let planAgeSeconds = Date().timeIntervalSince(activePlan.createdAt)
        guard planAgeSeconds >= TimeInterval(minPlanAgeDays) * 24 * 3600 else { return }

        let adaptationsFetch = FetchDescriptor<RunningPlanAdaptation>()
        let adaptations = (try? context.fetch(adaptationsFetch))?
            .filter { $0.planId == activePlan.id } ?? []

        guard let result = detect(plan: activePlan, adaptations: adaptations) else { return }

        print("🎯 Auto-adapting plan: reason=\(result.reason.rawValue) signal=\(result.signal)")
        do {
            _ = try await RunningPlanService.shared.adaptPlan(
                reason: result.reason,
                signal: result.signal,
                context: context
            )
            // Sessions may have changed — refresh the rolling reminder window
            // so notification bodies reflect the new prescription.
            await RunningWorkoutReminderScheduler.refresh(context: context)
        } catch {
            // Rate-limit + ai-failure responses are common (and benign) here.
            // Log and continue — the user shouldn't see anything.
            print("ℹ️ Auto-adapt skipped: \(error.localizedDescription)")
        }
    }

    // MARK: - Cooldown

    private static func isOutOfCooldown(
        adaptations: [RunningPlanAdaptation],
        now: Date
    ) -> Bool {
        let mostRecentAuto = adaptations
            .filter { $0.reasonRaw.hasPrefix("auto_") }
            .max(by: { $0.createdAt < $1.createdAt })
        guard let mostRecentAuto else { return true }

        let elapsed = now.timeIntervalSince(mostRecentAuto.createdAt)
        let cooldown = TimeInterval(autoCooldownDays) * 24 * 3600
        return elapsed >= cooldown
    }

    // MARK: - Detector: consecutive misses

    /// Walks past run sessions newest-first and counts the prefix of
    /// uncompleted-and-not-skipped sessions. Rest / cross days are stepped
    /// over, not counted as misses — those don't warrant an ease-back.
    private static func detectConsecutiveMisses(
        plan: RunningPlan,
        now: Date
    ) -> Result? {
        let startOfToday = Calendar.current.startOfDay(for: now)
        // Only consider sessions whose date is on or after the plan was
        // actually created. The edge function can anchor `start_date` to a
        // past Monday, so without this filter a freshly-generated Sunday-
        // night plan registers six instant "misses" at midnight rollover.
        let createdDay = Calendar.current.startOfDay(for: plan.createdAt)
        let pastRuns = plan.sessions
            .filter { $0.scheduledDate < startOfToday }
            .filter { $0.scheduledDate >= createdDay }
            .filter { $0.sessionType.isRun }
            .sorted { $0.scheduledDate > $1.scheduledDate }

        var streak = 0
        for session in pastRuns {
            if session.completedAt != nil { break }
            if session.skipped { break }
            streak += 1
        }

        guard streak >= consecutiveMissesThreshold else { return nil }

        return Result(
            reason: .autoMisses,
            signal: AdaptationSignal(missed_sessions_count: streak)
        )
    }

    // MARK: - Detector: pace consistently fast

    /// Looks at the most recent N completed quality sessions (tempo / intervals
    /// — not easy runs, where pace divergence is noise). If the average actual
    /// pace beats the prescribed pace by ≥ paceFastDeltaPercent, the runner is
    /// likely fitter than the plan thinks and we should tighten paces.
    private static func detectPaceConsistentlyFast(plan: RunningPlan) -> Result? {
        let candidates = plan.sessions
            .filter { $0.completedAt != nil }
            .filter { $0.sessionType == .tempo || $0.sessionType == .intervals }
            .filter { $0.targetPaceSecondsPerKm != nil && $0.targetPaceSecondsPerKm! > 0 }
            .filter { (s: PlannedSession) in
                guard let km = s.completedDistanceKm, km > 0,
                      let mins = s.completedDurationMinutes, mins > 0
                else { return false }
                return true
            }
            .sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
            .prefix(paceFastMinSessions)

        guard candidates.count >= paceFastMinSessions else { return nil }

        var deltas: [Double] = []
        var avgTargetSec: Double = 0
        for s in candidates {
            guard let target = s.targetPaceSecondsPerKm,
                  let km = s.completedDistanceKm, km > 0,
                  let mins = s.completedDurationMinutes
            else { continue }
            let actualPaceSec = (Double(mins) * 60) / km
            deltas.append(actualPaceSec - Double(target))
            avgTargetSec += Double(target)
        }
        guard deltas.count == paceFastMinSessions else { return nil }

        avgTargetSec /= Double(paceFastMinSessions)
        let avgDelta = deltas.reduce(0, +) / Double(deltas.count)

        // delta < 0 means actual was faster than target. Threshold is
        // -percent × target, e.g. for 5K target=300, threshold=-15.
        let threshold = -avgTargetSec * paceFastDeltaPercent
        guard avgDelta <= threshold else { return nil }

        return Result(
            reason: .autoPaceFast,
            signal: AdaptationSignal(pace_divergence_seconds: Int(avgDelta.rounded()))
        )
    }
}

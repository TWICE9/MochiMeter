import Foundation
import SwiftUI
import Combine
import Supabase
import HealthKit

class FitnessService: ObservableObject {
    static let shared = FitnessService()
    private let client = supabase

    @Published var runs: [LoggedRun] = []
    
    // Fetch runs on init or manually
    func fetchRuns() async {
        do {
            let response = try await client.database
                .from("logged_runs")
                .select()
                .order("run_date", ascending: false)
                .execute()

            // Decode explicitly (avoid generic task isolation issues)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let decodedRuns = try decoder.decode([LoggedRun].self, from: response.data)

            await MainActor.run {
                self.runs = decodedRuns
            }
        } catch {
            print("Error fetching runs: \(error)")
        }
    }

    func saveRunRecord(
        date: Date,
        distanceKm: Double,
        durationMinutes: Double,
        calories: Double?,
        avgPace: String?,
        avgHeartRate: Int?,
        elevationGain: Int?,
        feedback: String?,
        analyticsBlob: RunAnalyticsBlob? = nil
    ) async throws {
        let session = try await client.auth.session
        let user = session.user

        let insertData = InsertRun(
            user_id: user.id,
            run_date: date,
            distance_km: distanceKm,
            duration_minutes: durationMinutes,
            calories: calories,
            avg_pace: avgPace,
            avg_heart_rate: avgHeartRate,
            elevation_gain: elevationGain,
            feedback: feedback,
            analytics_blob: analyticsBlob
        )

        try await client.database
            .from("logged_runs")
            .insert(insertData)
            .execute()

        await fetchRuns()
    }

    func deleteRun(_ runId: UUID) async throws {
        // Optimistic update
        await MainActor.run {
            self.runs.removeAll { $0.id == runId }
        }

        try await client.database
            .from("logged_runs")
            .delete()
            .eq("id", value: runId)
            .execute()

        // Optional: Re-fetch to ensure sync
        // await fetchRuns()
    }

    // MARK: - HealthKit historical import

    struct ImportProgress: Sendable {
        enum Phase: Sendable { case scanning, importing, done }
        var phase: Phase
        var processed: Int
        var total: Int
    }

    struct ImportResult: Sendable {
        var imported: Int
        var skipped: Int
        var failed: Int
    }

    /// One-shot historical backfill from HealthKit. Builds an analytics blob
    /// (route polyline, pace, HR, elevation) for each running workout and
    /// inserts into `logged_runs`. Idempotent — workouts already represented
    /// in `logged_runs` (matched ±1 day + distance ±5%) are skipped, so the
    /// user can safely re-run with a longer window to extend their history.
    ///
    /// - Parameters:
    ///   - yearsBack: how many years of history to scan; nil = all time.
    ///   - progress: invoked on the main actor with current/total counts.
    func importHealthKitRunHistory(
        yearsBack: Int?,
        progress: @MainActor @escaping (ImportProgress) -> Void
    ) async throws -> ImportResult {
        await MainActor.run { progress(.init(phase: .scanning, processed: 0, total: 0)) }

        // 1) Make sure we have the current logged_runs set in memory for dedup.
        await fetchRuns()
        let existingRuns = self.runs

        // 2) Pull HK workouts in range.
        let workouts = await HealthKitManager.shared.fetchRunningWorkoutsForImport(yearsBack: yearsBack)

        // 3) Filter out workouts already represented in logged_runs.
        let toImport = workouts.filter { workout in
            !Self.isDuplicate(workout, in: existingRuns)
        }
        let skipped = workouts.count - toImport.count

        await MainActor.run {
            progress(.init(phase: .importing, processed: 0, total: toImport.count))
        }

        guard !toImport.isEmpty else {
            await MainActor.run { progress(.init(phase: .done, processed: 0, total: 0)) }
            return ImportResult(imported: 0, skipped: skipped, failed: 0)
        }

        // 4) Need the user id for the InsertRun rows.
        let session = try await client.auth.session
        let userId = session.user.id

        // 5) Process in chunks. Within a chunk we build blobs in parallel
        //    (HK round-trips dominate; the main actor isn't blocked) and
        //    insert as a single Supabase batch — N workouts → 1 round-trip.
        let chunkSize = 20
        var imported = 0
        var failed = 0
        var processed = 0

        for chunk in stride(from: 0, to: toImport.count, by: chunkSize) {
            let slice = Array(toImport[chunk..<min(chunk + chunkSize, toImport.count)])

            let inserts: [InsertRun] = await withTaskGroup(of: InsertRun?.self) { group in
                for workout in slice {
                    group.addTask {
                        await Self.buildInsertRun(for: workout, userId: userId)
                    }
                }
                var results: [InsertRun] = []
                for await item in group {
                    if let item = item { results.append(item) }
                }
                return results
            }

            failed += slice.count - inserts.count

            if !inserts.isEmpty {
                do {
                    try await client.database
                        .from("logged_runs")
                        .insert(inserts)
                        .execute()
                    imported += inserts.count
                } catch {
                    print("🏃 import batch failed: \(error)")
                    failed += inserts.count
                }
            }

            processed += slice.count
            let snapshot = processed
            await MainActor.run {
                progress(.init(phase: .importing, processed: snapshot, total: toImport.count))
            }
        }

        // 6) Refresh local cache so heatmap updates without a manual reopen.
        await fetchRuns()
        await MainActor.run {
            progress(.init(phase: .done, processed: toImport.count, total: toImport.count))
        }

        return ImportResult(imported: imported, skipped: skipped, failed: failed)
    }

    /// Lightweight catch-up sync run silently on heatmap open + app foreground.
    /// Pulls only HK runs newer than the most recent `logged_run` (with a
    /// short overlap for safety), capped at a 14-day window so this never
    /// silently backfills history without an explicit user import. Errors
    /// are logged but never surfaced — sync failures shouldn't block the UI.
    func syncNewHealthKitRuns() async {
        // Make sure we have current logged_runs to anchor the cutoff against.
        if runs.isEmpty {
            await fetchRuns()
        }

        let now = Date()
        let maxLookback = now.addingTimeInterval(-14 * 86_400)
        let cutoff: Date
        if let latest = runs.map(\.runDate).max() {
            // 1-day overlap so a run that crossed midnight or has slight
            // clock skew still gets caught by the dedup pass.
            cutoff = max(latest.addingTimeInterval(-86_400), maxLookback)
        } else {
            cutoff = maxLookback
        }

        let workouts = await HealthKitManager.shared.fetchRunningWorkouts(since: cutoff)
        let newWorkouts = workouts.filter { !Self.isDuplicate($0, in: runs) }
        guard !newWorkouts.isEmpty else { return }

        do {
            let session = try await client.auth.session
            let userId = session.user.id

            let inserts: [InsertRun] = await withTaskGroup(of: InsertRun?.self) { group in
                for workout in newWorkouts {
                    group.addTask { await Self.buildInsertRun(for: workout, userId: userId) }
                }
                var results: [InsertRun] = []
                for await item in group {
                    if let item = item { results.append(item) }
                }
                return results
            }

            guard !inserts.isEmpty else { return }
            try await client.database
                .from("logged_runs")
                .insert(inserts)
                .execute()
            await fetchRuns()
            print("🏃 Auto-synced \(inserts.count) new HK run(s)")
        } catch {
            print("🏃 Auto-sync failed: \(error)")
        }
    }

    /// Same fuzzy match the rest of the codebase uses (date ±1d + distance ±5%).
    private static func isDuplicate(_ workout: HKWorkout, in runs: [LoggedRun]) -> Bool {
        let workoutDistKm = (workout.totalDistance?.doubleValue(for: .meter()) ?? 0) / 1000
        guard workoutDistKm > 0 else { return true } // skip degenerate
        let cal = Calendar.current
        return runs.contains { run in
            cal.isDate(run.runDate, inSameDayAs: workout.startDate) &&
            abs(run.distanceKm - workoutDistKm) / max(0.1, run.distanceKm) < 0.05
        }
    }

    /// Builds an `InsertRun` from an `HKWorkout`, including the analytics blob
    /// (route + chart series). Returns nil only if the workout itself has no
    /// distance — those would be useless heatmap rows.
    private static func buildInsertRun(for workout: HKWorkout, userId: UUID) async -> InsertRun? {
        let distanceMeters = workout.totalDistance?.doubleValue(for: .meter()) ?? 0
        guard distanceMeters > 0 else { return nil }
        let distanceKm = distanceMeters / 1000
        let durationMinutes = workout.duration / 60
        let calories = workout.totalEnergyBurned?.doubleValue(for: .kilocalorie())

        let avgPaceStr: String? = {
            guard distanceKm > 0.01, durationMinutes > 0 else { return nil }
            let secsPerKm = (durationMinutes * 60) / distanceKm
            return String(format: "%d:%02d /km", Int(secsPerKm) / 60, Int(secsPerKm) % 60)
        }()

        let blob = await HealthKitManager.shared.buildAnalyticsBlob(for: workout)

        return InsertRun(
            user_id: userId,
            run_date: workout.startDate,
            distance_km: distanceKm,
            duration_minutes: durationMinutes,
            calories: (calories ?? 0) > 0 ? calories : nil,
            avg_pace: avgPaceStr,
            avg_heart_rate: blob?.avgHeartRate,
            elevation_gain: blob?.elevationGainMeters,
            feedback: "Imported from HealthKit · \(workout.sourceRevision.source.name)",
            analytics_blob: blob
        )
    }
}

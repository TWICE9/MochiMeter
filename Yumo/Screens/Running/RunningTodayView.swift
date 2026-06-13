//
//  RunningTodayView.swift
//  Yumo
//

import SwiftUI
import SwiftData
import HealthKit
import os.signpost

/// Signposter for Plan-tab perf measurement. Subsystem matches
/// `HealthRingsView`'s so all Plan-tab events show on one Instruments lane.
/// Counts and intervals are visible in Instruments → Points of Interest.
private let planTabSignposter = OSSignposter(subsystem: "com.yumo.perf", category: "PlanTab")

/// Pre-computed per-session metadata for the inline training calendar.
/// Cached so scroll-time row rendering doesn't repeatedly hit Calendar /
/// DateFormatter — both are surprisingly expensive in tight loops.
private struct CalendarRowMeta {
    let dayLabel: String
    let dayNumber: String
    let isToday: Bool
    let crossActivities: [CrossTrainingActivity]
    let isCrossOnly: Bool
}

/// One pre-rendered row inside a training-calendar week card. All fields
/// are display-ready strings/values so the row's body is a pure layout —
/// no live `PlannedSession` references, no formatter / calendar work per
/// render. Lets the parent cell conform to `Equatable` and skip body
/// re-evaluation when nothing changed.
private struct PlanWeekRowData: Equatable {
    let sessionID: UUID
    let dayLabel: String
    let dayNumber: String
    let isToday: Bool
    let isRun: Bool
    let isCrossOnly: Bool
    let isCompleted: Bool
    let skipped: Bool
    let label: String
    let crossIcon: String?
    let tint: Color
    let distanceLabel: String?
    let durationLabel: String?
    let paceLabel: String?
    /// Suffix shown under run rows when the same day has cross-training
    /// scheduled — e.g. "· also Strength + Yoga". Nil for cross-only or
    /// rest-only rows where the main label already conveys it.
    let crossSuffix: String?
}

/// Pre-aggregated week-card data. All fields are display-ready so the cell
/// body never has to filter sessions, format dates, or look up cross
/// training schedules itself. Equatable so the cell view can short-circuit
/// body re-evaluation when its input hasn't changed (the common case when
/// `HealthKitManager` or `fitnessService` republishes elsewhere).
private struct PlanWeekCardData: Equatable {
    let week: Int
    let dateRangeLabel: String
    let totalKm: Double
    let displayTotal: Double
    let displayDone: Double
    let runsCount: Int
    let doneRunsCount: Int
    let isCurrent: Bool
    let rows: [PlanWeekRowData]
}

/// Plan-wide summary used by `planSummaryCard`.
private struct PlanSummaryData {
    let runsCount: Int
    let doneRunsCount: Int
    let daysToRace: Int?
}

/// Plan-wide distance totals used by `planDistanceCard`.
private struct PlanDistanceData {
    let totalKm: Double
    let fraction: Double
    let loggedDisplay: Double
    let totalDisplay: Double
    let remainingDisplay: Double

    static let zero = PlanDistanceData(
        totalKm: 0, fraction: 0,
        loggedDisplay: 0, totalDisplay: 0, remainingDisplay: 0
    )
}

/// The entire inline training calendar (header + all week cards), rendered
/// as a single `Equatable` surface so the whole subtree is short-circuited
/// when nothing relevant has changed. Without this, every parent body
/// re-eval (HealthKit republish, fitnessService publish, etc.) would
/// rebuild the structural view tree of all 12–24 cards even though their
/// data is unchanged — and the cell-level `.equatable()` only short-
/// circuits per cell, not the surrounding container.
private struct TrainingCalendarView: View, Equatable {
    let cards: [PlanWeekCardData]
    let unitLabel: String
    var onSessionTap: (UUID) -> Void

    static func == (lhs: TrainingCalendarView, rhs: TrainingCalendarView) -> Bool {
        lhs.cards == rhs.cards && lhs.unitLabel == rhs.unitLabel
    }

    private var primaryText: Color { Color("AppTextPrimary") }

    var body: some View {
        // Emit a signpost every time this body actually evaluates. If
        // `.equatable()` is doing its job upstream, this should be silent
        // during scroll. If you see it firing repeatedly, something is
        // forcing re-eval (Equatable check failing, or the parent itself
        // isn't using `.equatable()` correctly).
        planTabSignposter.emitEvent("TrainingCalendarView.body", "weeks=\(cards.count)")
        return VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "calendar").foregroundStyle(Color.runAccent)
                Text("Training Calendar").font(.headline).foregroundStyle(primaryText)
            }
            .padding(.horizontal, 24)

            // Pre-mount all weeks via plain VStack rather than LazyVStack.
            // For a typical 12-week plan that's only 12 cards. Lazy mounting
            // was paying full structural construction cost (FrostedGlassContainer
            // + shadows + nested ForEach over ~7 rows) each time a cell
            // scrolled back into view — the dominant scroll-time lag on this
            // tab. Cells stay `Equatable` so HealthKit publishes still don't
            // force body re-evaluation when nothing changed.
            VStack(alignment: .leading, spacing: 16) {
                ForEach(cards, id: \.week) { card in
                    PlanWeekCardView(
                        card: card,
                        unitLabel: unitLabel,
                        onSessionTap: onSessionTap
                    )
                    .equatable()
                    .padding(.horizontal, 24)
                    .id("plan-week-\(card.week)")
                }
            }
        }
    }
}

// ──────────────────────────────────────────────────────────────────────
// PERF NOTE — "Plan tab calendar scroll lag" investigation
// ──────────────────────────────────────────────────────────────────────
//
// Symptom: Plan tab scrolled at <30fps as soon as the training calendar
// was in view. Other tabs were fine. Equatable views, cached aggregates,
// VStack-vs-LazyVStack swaps, and runaway-timer fixes all helped marginally
// but never made it smooth.
//
// Diagnosis came from Instruments → Hitches:
//   "Potentially expensive render, 420 offscreen passes" per frame.
//
// Cause: each calendar cell renders ~30 small sub-views (FrostedGlassContainer
// shadow + clipShape, header capsules, per-row colored bar, day labels,
// metric chips, completion checkmarks, dividers). With 12 visible cells
// during scroll, the GPU was compositing 360+ individual offscreen layers
// per frame. The Updates / View Body lanes were nearly empty — confirming
// the bottleneck was GPU-side compositing, not CPU/SwiftUI work.
//
// Failed fixes (kept anyway because they help marginally):
//   • Equatable views — addressed CPU re-eval; cost was elsewhere.
//   • `.compositingGroup()` — only flattens *ancestor* effects (opacity,
//     blend modes); does NOT flatten children into one layer. Common
//     misconception. Cut passes from 420 → ~200 only because
//     FrostedGlassContainer's own shadow + clip got grouped.
//
// Real fix: `.drawingGroup()` on `PlanWeekCardView.body` — rasterizes
// the entire cell into a single Metal-backed texture. The GPU then
// composites 12 textures per frame instead of ~360 layers. Smooth.
//
// When this pattern applies again:
//   • Symptom is "lag while a particular section is in view", not "lag
//     after data changes" or "lag on tab switch".
//   • Instruments → Hitches shows "expensive render, N offscreen passes"
//     where N is large.
//   • The slow section has many small sub-views per cell × many cells
//     visible at once (long lists of complex cards).
// Then: apply `.drawingGroup()` to the cell-level View, NOT
// `.compositingGroup()`. The two modifiers are NOT interchangeable.
//
// Caveats of `.drawingGroup()`:
//   • Animations of children inside the group are frozen (fine here —
//     calendar cells don't animate during scroll).
//   • Slight differences in text anti-aliasing inside the group.
//   • Higher memory cost per cell (one offscreen texture each).
// ──────────────────────────────────────────────────────────────────────

/// One week card in the inline training calendar, rendered as an
/// `Equatable` view so SwiftUI can short-circuit body re-evaluation when
/// the input data hasn't changed. With ~6 visible cells × ~30 view
/// expressions each, skipping unchanged cells during a `HealthKitManager`
/// republish is the difference between smooth and stuttery scroll.
///
/// See the PERF NOTE block above for the full investigation that led to
/// the `.drawingGroup()` modifier in `body`.
private struct PlanWeekCardView: View, Equatable {
    let card: PlanWeekCardData
    let unitLabel: String
    /// Callback ignored by the `Equatable` conformance — closures aren't
    /// equatable, and re-creating the closure on each parent body eval
    /// shouldn't force the cell to re-render.
    var onSessionTap: (UUID) -> Void

    static func == (lhs: PlanWeekCardView, rhs: PlanWeekCardView) -> Bool {
        lhs.card == rhs.card && lhs.unitLabel == rhs.unitLabel
    }

    private var primaryText: Color   { Color("AppTextPrimary") }
    private var secondaryText: Color { Color("AppTextPrimary").opacity(0.9) }
    private var tertiaryText: Color  { Color("AppTextPrimary").opacity(0.72) }

    var body: some View {
        // Per-cell body emit. Should fire only on first mount or when
        // `card`/`unitLabel` actually change. Persistent firing during scroll
        // means cell-level Equatable isn't catching equal inputs.
        planTabSignposter.emitEvent("PlanWeekCardView.body", "week=\(card.week)")
        return FrostedGlassContainer {
            VStack(alignment: .leading, spacing: 12) {
                header
                Divider().opacity(0.3)
                rowList
            }
        }
        // `.drawingGroup()` rasterizes the entire cell — header capsules,
        // 7 rows × (day labels, colored bar, title text, metric text,
        // checkmark icon), dividers, badges — into a single Metal-backed
        // offscreen layer. During scroll the GPU then composites just
        // that one layer per cell instead of compositing every child
        // shape/text/icon individually. Per-row content is static during
        // scroll so the usual `drawingGroup` caveats (broken in-cell
        // animations, slight text-rendering differences) don't apply.
        // This is the surgical fix for the calendar-only scroll lag —
        // other tabs don't have this density of sub-views per card so
        // they don't need it.
        .drawingGroup()
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(card.dateRangeLabel)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(primaryText)
                    Text("WEEK \(card.week)")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Capsule().fill(card.isCurrent ? Color.runAccent : Color.gray.opacity(0.5)))
                    if card.isCurrent {
                        Text("NOW")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 7).padding(.vertical, 3)
                            .background(Capsule().fill(Color.runDone))
                    }
                }
                if card.totalKm > 0 {
                    Text(String(format: "Total: %.1f / %.1f %@", card.displayDone, card.displayTotal, unitLabel))
                        .font(.caption)
                        .foregroundStyle(tertiaryText)
                }
            }
            Spacer()
            if card.runsCount > 0 {
                Text("\(card.doneRunsCount)/\(card.runsCount)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(card.doneRunsCount == card.runsCount ? Color.runDone : tertiaryText)
            }
        }
    }

    private var rowList: some View {
        VStack(spacing: 0) {
            ForEach(Array(card.rows.enumerated()), id: \.element.sessionID) { idx, row in
                if row.isRun {
                    Button {
                        onSessionTap(row.sessionID)
                    } label: {
                        rowContent(row)
                    }
                    .buttonStyle(.plain)
                } else {
                    rowContent(row)
                }
                if idx < card.rows.count - 1 {
                    Divider().opacity(0.15)
                }
            }
        }
    }

    private func rowContent(_ row: PlanWeekRowData) -> some View {
        HStack(spacing: 12) {
            VStack(spacing: 1) {
                Text(row.dayLabel)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(row.isToday ? row.tint : tertiaryText)
                Text(row.dayNumber)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(row.isToday ? row.tint : primaryText)
            }
            .frame(width: 30)

            RoundedRectangle(cornerRadius: 2)
                .fill(row.isRun || row.isCrossOnly ? row.tint : Color.gray.opacity(0.18))
                .frame(width: 4, height: 36)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    if row.isCrossOnly, let icon = row.crossIcon {
                        Image(systemName: icon)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(row.tint)
                    }
                    Text(row.label)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(row.isCrossOnly ? row.tint : primaryText)
                    if row.skipped {
                        Text("skipped")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(tertiaryText)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Capsule().fill(Color.gray.opacity(0.1)))
                    }
                }

                if row.isRun {
                    HStack(spacing: 4) {
                        if let dist = row.distanceLabel {
                            Text(dist).font(.caption).foregroundStyle(secondaryText)
                        }
                        if let dur = row.durationLabel {
                            Text("· \(dur)").font(.caption).foregroundStyle(secondaryText)
                        }
                        if let pace = row.paceLabel {
                            Text("· \(pace)").font(.caption).foregroundStyle(secondaryText)
                        }
                        if let suffix = row.crossSuffix, let icon = row.crossIcon {
                            HStack(spacing: 3) {
                                Image(systemName: icon)
                                Text(suffix)
                            }
                            .font(.caption2)
                            .foregroundStyle(Color.runAccent.opacity(0.8))
                        }
                    }
                }
            }

            Spacer(minLength: 0)

            if row.isRun {
                Image(systemName: row.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(row.isCompleted ? .runDone : Color.gray.opacity(0.3))
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}

/// Shared `DateFormatter` instances. These used to live as static stored
/// properties on `RunningTodayView` itself, but generic types can't have
/// static stored state — file-scope enum keeps the single-allocation
/// behavior without the constraint.
private enum RunningTodayFormatters {
    /// "M" / "T" — narrow day-of-week, anchored to UTC because sessions are
    /// stored at a UTC time (06:00 / 12:00). Without UTC, users in negative
    /// offsets see Monday's session render as "S".
    static let narrowDay: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEEE"
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()
    /// "Feb 10" — used by training-calendar rows.
    static let calendarMediumDay: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()
    /// "Mon" / "Tue" — day-of-week label inside the calendar.
    static let calendarDayLabel: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f
    }()
    /// "10" / "11" — day-of-month inside the calendar.
    static let calendarDayNumber: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d"
        return f
    }()
}

struct RunningTodayView<BelowContent: View>: View {
    let plan: RunningPlan?
    let isImperial: Bool
    var onMarkComplete: (PlannedSession) -> Void
    var onSwitchToTab: (RunningHubView.HubTab) -> Void
    var onRunSelected: ((LoggedRun) -> Void)? = nil
    var onSessionTapped: ((PlannedSession) -> Void)? = nil
    var onClearPlan: (() -> Void)? = nil
    /// Optional content rendered below today's session card. Passed as a
    /// `@ViewBuilder` closure so SwiftUI keeps structural diffing on the
    /// inner subtree — replacing the previous `AnyView` boxing.
    @ViewBuilder var belowSessionContent: () -> BelowContent
    var embedded: Bool = false
    var planEmbedded: Bool = false
    var isGenerating: Bool = false
    /// Running workouts synced to HealthKit today. Used to surface the
    /// pending-log card. Caller is expected to pre-filter to running-typed
    /// workouts; we don't refilter inside this view.
    var todayRunningWorkouts: [WorkoutSummary] = []
    /// Called when user wants to log a run on a rest/unplanned day. Passes the
    /// detected HealthKit workout, or nil if triggered manually.
    var onLogUnplannedRun: ((WorkoutSummary?) -> Void)? = nil
    /// Called when user taps "Log This Run" with a detected HealthKit workout on a
    /// planned session day — skips the sheet and links directly.
    var onAutoLogSession: ((PlannedSession, WorkoutSummary) -> Void)? = nil

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @State private var selectedDate: Date = Calendar.current.startOfDay(for: Date())
    @State private var showClearPlanConfirm = false
    @State private var showFineTuneOptions = false
    @State private var isAdapting = false
    @State private var adaptError: String? = nil
    @State private var showPaywall = false
    @State private var paywallTrigger: String = "running_fine_tune"

    /// Lightweight toast shown when an adaptation hits the server-side rate
    /// limit (1/hour for manual reasons). A full alert feels too heavy for
    /// a "wait a bit" situation — this fades in at the bottom and dismisses
    /// itself after a few seconds.
    @State private var rateLimitToast: String? = nil
    @State private var rateLimitDismissTask: Task<Void, Never>? = nil
    @State private var showPlanOverview = false
    @State private var generatingPulse: Bool = false
    @State private var generatingDot: Int = 0
    /// Cancellable handle for the loading-dots ticker. Without this the
    /// ticker leaked indefinitely after the generating card disappeared.
    @State private var dotsTask: Task<Void, Never>? = nil

    @StateObject private var fitnessService = FitnessService.shared

    /// Surfaces "Plan adjusted" banners. Filtered down to the active plan +
    /// unacknowledged + non-zero changes in `latestAdaptation` below.
    @Query(sort: \RunningPlanAdaptation.createdAt, order: .reverse)
    private var allAdaptations: [RunningPlanAdaptation]

    /// Pulled in so rest-day cards can reflect the user's actual schedule —
    /// if they've told us strength training is on Mon/Wed/Fri, today's
    /// rest day on a Mon should read "Strength Training", not "Rest Day".
    @Query private var runningProfiles: [RunningProfile]

    private var latestAdaptation: RunningPlanAdaptation? {
        guard let plan else { return nil }
        return allAdaptations.first {
            $0.planId == plan.id && $0.acknowledgedAt == nil && $0.sessionsChanged > 0
        }
    }

    // Cached heavy aggregates — recomputed only when their inputs change.
    // Previously these were computed properties read by ~7 downstream
    // properties per body eval, each one re-sorting plan.sessions. With
    // FitnessService publishing during scroll/animations, every re-eval
    // burned the main thread. Now sortedSessions / weekGroups / today's
    // runs are recomputed via .onChange below, and the body reads cached
    // copies in O(1).
    @State private var cachedSortedSessions: [PlannedSession] = []
    @State private var cachedSelectedDayRuns: [LoggedRun] = []
    @State private var cachedWeekGroups: [(week: Int, sessions: [PlannedSession])] = []
    /// Pre-aggregated week-card data so `calendarWeekCard` is a pure-read
    /// (no per-render filter / reduce / date-formatter calls).
    @State private var cachedPlanWeekCards: [PlanWeekCardData] = []
    /// Plan-tab summary card aggregates — cached so each scroll re-render
    /// reads precomputed values instead of filtering the full plan twice.
    @State private var cachedPlanSummary: PlanSummaryData = PlanSummaryData(runsCount: 0, doneRunsCount: 0, daysToRace: nil)
    /// Plan-distance card aggregates (logged / total / remaining + bar %).
    @State private var cachedPlanDistance: PlanDistanceData = .zero
    /// Cached "today" so `currentWeekNumber`, `daysToRace`, and other
    /// time-dependent reads don't re-allocate `Calendar.startOfDay(for:)`
    /// on every property access. Refreshed in `recomputeCaches`.
    @State private var cachedToday: Date = Calendar.current.startOfDay(for: Date())
    /// Cached current week index. Was previously a computed property doing
    /// `sortedSessions.first { ... }` + Calendar dateComponents work — and
    /// it was called from every week card during scroll, making the cost
    /// O(weeks × sessions).
    @State private var cachedCurrentWeekNumber: Int = 1
    /// Pre-computed `weekday → [activities]` map so the inline calendar can
    /// resolve cross-training overlap with a single dictionary lookup per row
    /// instead of filtering `CrossTrainingActivity.allCases` × dict-access on
    /// every body re-evaluation. Refreshed when the profile changes.
    @State private var cachedCrossByWeekday: [Weekday: [CrossTrainingActivity]] = [:]
    /// Per-session calendar-row metadata — lets each row's body just read
    /// from a dict instead of recomputing day labels, today checks, and
    /// cross-training resolution on every scroll re-render. The Plan tab is
    /// inside HealthRingsView's body which republishes constantly as HealthKit
    /// streams; without this cache, every publish forces ~80–160 rows worth
    /// of date-formatter + Calendar.component calls.
    @State private var cachedCalendarRowMeta: [UUID: CalendarRowMeta] = [:]


    // Mirror main app text colors exactly
    private var primaryText: Color { Color("AppTextPrimary") }
    private var secondaryText: Color { Color("AppTextPrimary").opacity(0.9) }
    private var tertiaryText: Color { Color("AppTextPrimary").opacity(0.72) }

    private var unitLabel: String { isImperial ? "mi" : "km" }
    /// Reads from the cached value rather than recomputing
    /// `Calendar.startOfDay` on each access. Refreshed in `recomputeCaches`.
    private var today: Date { cachedToday }

    private var selectedDayRuns: [LoggedRun] { cachedSelectedDayRuns }

    private var sortedSessions: [PlannedSession] { cachedSortedSessions }

    /// O(n log n) sort + O(n) grouping, run only when inputs change.
    /// Counter-rotates the prior pattern of 7+ accesses per body eval each
    /// re-sorting from scratch.
    private func recomputeCaches() {
        let state = planTabSignposter.beginInterval("recomputeCaches")
        defer { planTabSignposter.endInterval("recomputeCaches", state) }
        let sorted = (plan?.sessions ?? []).sorted { $0.scheduledDate < $1.scheduledDate }
        cachedSortedSessions = sorted
        cachedSelectedDayRuns = fitnessService.runs.filter {
            Calendar.current.isDate($0.runDate, inSameDayAs: selectedDate)
        }
        if let plan {
            let grouped = Dictionary(grouping: sorted) { $0.weekNumber }
            cachedWeekGroups = (1...plan.totalWeeks).compactMap { week in
                guard let s = grouped[week], !s.isEmpty else { return nil }
                return (week: week, sessions: s)
            }
        } else {
            cachedWeekGroups = []
        }

        // Cross-training: invert {activity: [day]} into {day: [activity]} so
        // the calendar's per-row lookup is one dict access (down from
        // CrossTrainingActivity.allCases × dict-access on every body eval).
        var crossMap: [Weekday: [CrossTrainingActivity]] = [:]
        let schedule = runningProfiles.first?.crossTrainingSchedule ?? [:]
        for activity in CrossTrainingActivity.allCases {
            guard let days = schedule[activity], !days.isEmpty else { continue }
            for day in days {
                crossMap[day, default: []].append(activity)
            }
        }
        cachedCrossByWeekday = crossMap

        // Pre-build the per-session metadata the calendar rows need so a
        // scroll re-render is a dict lookup instead of a fresh date-formatter
        // call + Calendar.component(.weekday). Computed once here whenever
        // sessions / cross-schedule / selected-day change.
        let cal = Calendar.current
        var meta: [UUID: CalendarRowMeta] = [:]
        meta.reserveCapacity(sorted.count)
        for session in sorted {
            let weekdayInt = cal.component(.weekday, from: session.scheduledDate)
            let weekday: Weekday?
            switch weekdayInt {
            case 1: weekday = .sun
            case 2: weekday = .mon
            case 3: weekday = .tue
            case 4: weekday = .wed
            case 5: weekday = .thu
            case 6: weekday = .fri
            case 7: weekday = .sat
            default: weekday = nil
            }
            let cross = weekday.flatMap { crossMap[$0] } ?? []
            meta[session.id] = CalendarRowMeta(
                dayLabel: RunningTodayFormatters.calendarDayLabel.string(from: session.scheduledDate).uppercased(),
                dayNumber: RunningTodayFormatters.calendarDayNumber.string(from: session.scheduledDate),
                isToday: cal.isDateInToday(session.scheduledDate),
                crossActivities: cross,
                isCrossOnly: !session.sessionType.isRun && session.sessionType == .rest && !cross.isEmpty
            )
        }
        cachedCalendarRowMeta = meta

        // Refresh the cached "today" snapshot first so anything below that
        // depends on day-rollover state reads a consistent value.
        let todaySnapshot = cal.startOfDay(for: Date())
        cachedToday = todaySnapshot

        // Compute the current week number once. Was a hot computed property
        // re-evaluated by every visible week card on every render.
        let currentWeek: Int
        if let plan {
            if let todaySession = sorted.first(where: { cal.isDateInToday($0.scheduledDate) }) {
                currentWeek = todaySession.weekNumber
            } else {
                let days = cal.dateComponents(
                    [.day], from: cal.startOfDay(for: plan.startDate), to: todaySnapshot
                ).day ?? 0
                currentWeek = max(1, min(plan.totalWeeks, (days / 7) + 1))
            }
        } else {
            currentWeek = 1
        }
        cachedCurrentWeekNumber = currentWeek

        // Per-week aggregates + per-row display payloads. One pass over each
        // group's sessions builds everything the calendar cell needs; the
        // cell body becomes a pure layout of precomputed strings.
        if let plan {
            let mileFactor = 0.621371
            var cards: [PlanWeekCardData] = []
            cards.reserveCapacity(cachedWeekGroups.count)
            for group in cachedWeekGroups {
                var runs = 0
                var doneRuns = 0
                var totalKm: Double = 0
                var doneKm: Double = 0
                var rows: [PlanWeekRowData] = []
                rows.reserveCapacity(group.sessions.count)
                for s in group.sessions {
                    let isRun = s.sessionType.isRun
                    if isRun {
                        runs += 1
                        if let km = s.targetDistanceKm { totalKm += km }
                        if s.isCompleted {
                            doneRuns += 1
                            doneKm += s.completedDistanceKm ?? s.targetDistanceKm ?? 0
                        }
                    }
                    let rowMeta = meta[s.id]
                    let cross = rowMeta?.crossActivities ?? []
                    let isCrossOnly = rowMeta?.isCrossOnly ?? false
                    let tint: Color = isCrossOnly ? RunningSessionType.cross.tint : Self.tintForType(s.sessionType)
                    let label: String = isCrossOnly
                        ? cross.map(\.rawValue).joined(separator: " + ")
                        : s.sessionType.displayLabel
                    // Used both as the leading icon on cross-only rows and
                    // as the trailing-suffix icon on run rows that share the
                    // same day. Either case wants the first activity's icon.
                    let crossIcon: String? = cross.first.map(Self.iconForCrossActivity)
                    let dist: String? = (s.targetDistanceKm ?? 0) > 0
                        ? Self.formatDistance(s.targetDistanceKm!, isImperial: isImperial)
                        : nil
                    let dur: String? = (s.targetDurationMinutes ?? 0) > 0
                        ? "\(s.targetDurationMinutes!) min"
                        : nil
                    let pace: String? = (s.targetPaceSecondsPerKm ?? 0) > 0
                        ? Self.formatPaceLabel(s.targetPaceSecondsPerKm!, isImperial: isImperial)
                        : nil
                    let crossSuffix: String? = (isRun && !cross.isEmpty)
                        ? "· also " + cross.map(\.rawValue).joined(separator: " + ")
                        : nil
                    rows.append(PlanWeekRowData(
                        sessionID: s.id,
                        dayLabel: rowMeta?.dayLabel ?? "",
                        dayNumber: rowMeta?.dayNumber ?? "",
                        isToday: rowMeta?.isToday ?? false,
                        isRun: isRun,
                        isCrossOnly: isCrossOnly,
                        isCompleted: s.isCompleted,
                        skipped: s.skipped,
                        label: label,
                        crossIcon: crossIcon,
                        tint: tint,
                        distanceLabel: dist,
                        durationLabel: dur,
                        paceLabel: pace,
                        crossSuffix: crossSuffix
                    ))
                }
                let dateRange: String = {
                    guard let first = group.sessions.first, let last = group.sessions.last else { return "" }
                    let f = RunningTodayFormatters.calendarMediumDay
                    return "\(f.string(from: first.scheduledDate)) – \(f.string(from: last.scheduledDate))"
                }()
                cards.append(PlanWeekCardData(
                    week: group.week,
                    dateRangeLabel: dateRange,
                    totalKm: totalKm,
                    displayTotal: isImperial ? totalKm * mileFactor : totalKm,
                    displayDone: isImperial ? doneKm * mileFactor : doneKm,
                    runsCount: runs,
                    doneRunsCount: doneRuns,
                    isCurrent: group.week == currentWeek,
                    rows: rows
                ))
            }
            cachedPlanWeekCards = cards

            // Plan-summary aggregates — one walk over sorted, no extra filter.
            var allRuns = 0
            var allDone = 0
            var allTotalKm: Double = 0
            var allDoneKm: Double = 0
            for s in sorted where s.sessionType.isRun {
                allRuns += 1
                if let km = s.targetDistanceKm { allTotalKm += km }
                if s.isCompleted {
                    allDone += 1
                    allDoneKm += s.completedDistanceKm ?? s.targetDistanceKm ?? 0
                }
            }
            let daysToRace: Int? = plan.targetRaceDate.map {
                cal.dateComponents([.day], from: todaySnapshot, to: $0).day ?? 0
            }
            cachedPlanSummary = PlanSummaryData(
                runsCount: allRuns,
                doneRunsCount: allDone,
                daysToRace: daysToRace
            )

            let fraction = allTotalKm > 0 ? min(1.0, allDoneKm / allTotalKm) : 0
            let remainingKm = max(0, allTotalKm - allDoneKm)
            cachedPlanDistance = PlanDistanceData(
                totalKm: allTotalKm,
                fraction: fraction,
                loggedDisplay: isImperial ? allDoneKm * mileFactor : allDoneKm,
                totalDisplay: isImperial ? allTotalKm * mileFactor : allTotalKm,
                remainingDisplay: isImperial ? remainingKm * mileFactor : remainingKm
            )
        } else {
            cachedPlanWeekCards = []
            cachedPlanSummary = PlanSummaryData(runsCount: 0, doneRunsCount: 0, daysToRace: nil)
            cachedPlanDistance = .zero
        }
    }

    /// Cheap signal for `.onChange` so we re-cache when sessions are added,
    /// removed, or marked completed/skipped — none of which change `plan?.id`.
    private var planFingerprint: String {
        guard let plan else { return "nil" }
        var completed = 0
        var skipped = 0
        for s in plan.sessions {
            if s.isCompleted { completed += 1 }
            if s.skipped { skipped += 1 }
        }
        return "\(plan.id.uuidString)-\(plan.sessions.count)-\(completed)-\(skipped)"
    }

    /// Cheap signal for the cross-training cache. The raw schedule strings
    /// already encode both the activity and day, so concatenating them gives
    /// a stable, lightweight fingerprint that flips whenever the user edits
    /// their gym week.
    private var crossTrainingFingerprint: String {
        runningProfiles.first?.crossTrainingScheduleRaw.joined(separator: ",") ?? ""
    }

    // isDateInToday skips the extra startOfDay allocation used by isDate(_:inSameDayAs:)
    private var todaySession: PlannedSession? {
        sortedSessions.first { Calendar.current.isDateInToday($0.scheduledDate) }
    }
    private var selectedSession: PlannedSession? {
        sortedSessions.first { Calendar.current.isDate($0.scheduledDate, inSameDayAs: selectedDate) }
    }
    private var isSelectedToday: Bool { Calendar.current.isDateInToday(selectedDate) }
    /// Reads from the cached value populated in `recomputeCaches`. The
    /// underlying calculation is unchanged.
    private var currentWeekNumber: Int { cachedCurrentWeekNumber }
    private var selectedWeekNumber: Int {
        sortedSessions.first { Calendar.current.isDate($0.scheduledDate, inSameDayAs: selectedDate) }?.weekNumber ?? currentWeekNumber
    }
    private var selectedWeekSessions: [PlannedSession] {
        sortedSessions.filter { $0.weekNumber == selectedWeekNumber }
    }
    private var weeklyCompletedKm: Double {
        selectedWeekSessions.filter(\.isCompleted).compactMap { $0.completedDistanceKm ?? $0.targetDistanceKm }.reduce(0, +)
    }
    private var weeklyTargetKm: Double {
        selectedWeekSessions.filter { $0.sessionType.isRun }.compactMap(\.targetDistanceKm).reduce(0, +)
    }
    private var completedThisWeek: Int { selectedWeekSessions.filter(\.isCompleted).count }
    private var totalRunsThisWeek: Int { selectedWeekSessions.filter { $0.sessionType.isRun }.count }

    /// Cross-training activities the user has scheduled for the currently
    /// selected calendar day. Non-empty turns the rest-day card into a
    /// "Strength Training" / "Yoga" / etc. card so the day reads as
    /// productive, not idle. Returned in `CrossTrainingActivity.allCases`
    /// order for stable joins like "Strength + Yoga".
    private var crossActivitiesOnSelectedDate: [CrossTrainingActivity] {
        crossActivities(for: selectedDate)
    }

    private func crossActivityTitle(_ activities: [CrossTrainingActivity]) -> String {
        activities.map(\.rawValue).joined(separator: " + ")
    }

    private func crossActivityIcon(_ activity: CrossTrainingActivity) -> String {
        Self.iconForCrossActivity(activity)
    }

    // MARK: - Pure helpers used while precomputing cell data
    //
    // These are static so `recomputeCaches` (which builds `[PlanWeekRowData]`)
    // can call them without depending on the live view instance. Logic is
    // identical to the instance methods below.

    static func iconForCrossActivity(_ activity: CrossTrainingActivity) -> String {
        switch activity {
        case .strength: return "figure.strengthtraining.traditional"
        case .yoga:     return "figure.yoga"
        case .pilates:  return "figure.pilates"
        case .cycling:  return "bicycle"
        case .swimming: return "figure.pool.swim"
        case .hiking:   return "figure.hiking"
        case .other:    return "figure.cooldown"
        }
    }

    static func tintForType(_ type: RunningSessionType) -> Color {
        type.tint
    }

    static func formatDistance(_ km: Double, isImperial: Bool) -> String {
        let v = isImperial ? km * 0.621371 : km
        let unit = isImperial ? "mi" : "km"
        return String(format: v < 10 ? "%.1f %@" : "%.0f %@", v, unit)
    }

    static func formatPaceLabel(_ secondsPerKm: Int, isImperial: Bool) -> String {
        let s = isImperial ? Int(Double(secondsPerKm) / 0.621371) : secondsPerKm
        let unit = isImperial ? "mi" : "km"
        return String(format: "%d:%02d /%@", s / 60, s % 60, unit)
    }

    private var weekGroups: [(week: Int, sessions: [PlannedSession])] { cachedWeekGroups }

    /// HealthKit running workouts from today that haven't been linked to a completed session yet.
    /// Non-empty only when viewing today and there's something actionable to show.
    /// Caller already filters to `.running` activityType, so we just gate on
    /// today + completion here.
    private var pendingTodayRuns: [WorkoutSummary] {
        guard isSelectedToday else { return [] }
        guard !todayRunningWorkouts.isEmpty else { return [] }
        // Hide once today's planned session is logged (any source)
        if let session = todaySession, session.isCompleted { return [] }
        return todayRunningWorkouts
    }

    var body: some View {
        // Top-level signpost. If `.equatable()` skips this view at the call
        // site (HealthRingsView), this should NOT fire on HK publishes.
        // Persistent firing means the Equatable conformance isn't being
        // honored or our `==` is returning false unexpectedly.
        planTabSignposter.emitEvent("RunningTodayView.body", "embedded=\(planEmbedded ? "plan" : embedded ? "today" : "standalone")")
        return Group {
            if planEmbedded {
                planContent
            } else if embedded {
                todayContent
            } else {
                ScrollView(showsIndicators: false) {
                    todayContent
                }
            }
        }
        .overlay(alignment: .bottom) {
            if let message = rateLimitToast {
                rateLimitToastView(message)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .opacity
                    ))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: rateLimitToast)
        .onAppear { recomputeCaches() }
        .onChange(of: selectedDate) { _, _ in recomputeCaches() }
        .onChange(of: fitnessService.runs.count) { _, _ in recomputeCaches() }
        .onChange(of: planFingerprint) { _, _ in recomputeCaches() }
        .onChange(of: crossTrainingFingerprint) { _, _ in recomputeCaches() }
        // Unit toggle invalidates the unit-converted display values
        // (`displayTotal`, `displayDone`, etc.) baked into the caches.
        .onChange(of: isImperial) { _, _ in recomputeCaches() }
    }

    @ViewBuilder
    private func rateLimitToastView(_ message: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "hourglass")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color.runAccent)
            Text(message)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(primaryText)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.runAccent.opacity(0.3), lineWidth: 1)
                )
                .shadow(color: .black.opacity(colorScheme == .dark ? 0.4 : 0.15), radius: 12, y: 4)
        )
        .onTapGesture { dismissRateLimitToast() }
    }

    private func showRateLimitToast(_ message: String) {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        rateLimitToast = message
        rateLimitDismissTask?.cancel()
        rateLimitDismissTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_500_000_000)  // 3.5s
            if !Task.isCancelled {
                rateLimitToast = nil
            }
        }
    }

    private func dismissRateLimitToast() {
        rateLimitDismissTask?.cancel()
        rateLimitToast = nil
    }

    private var todayContent: some View {
        VStack(alignment: .leading, spacing: 24) {
            if let adaptation = latestAdaptation, plan != nil {
                adaptationBanner(adaptation)
                    .slideIn(delay: 0.02)
            }

            if let plan {
                // Week strip is now embedded inside todayCard so the schedule
                // and today's session feel like one card rather than two.
                todayCard(plan)
                    .slideIn(delay: 0.06)
                belowSessionContent()
                    .slideIn(delay: 0.10)
            } else {
                noPlanCard
                    .slideIn(delay: 0.06)
            }

            if let plan {
                if !selectedDayRuns.isEmpty {
                    VStack(alignment: .leading, spacing: 14) {
                        let labelStr = Calendar.current.isDateInToday(selectedDate) ? "Today's Activity" : "Logged Activity"
                        Text(labelStr)
                            .font(.headline)
                            .foregroundStyle(primaryText)
                            .padding(.horizontal, 24)

                        ForEach(selectedDayRuns) { run in
                            completedRunCard(run)
                        }
                    }
                    .slideIn(delay: 0.14)
                }

                upcomingCard
                    .slideIn(delay: selectedDayRuns.isEmpty ? 0.14 : 0.18)
            }

            if !embedded {
                Spacer().frame(height: 100)
            }
        }
        .padding(.top, 8)
        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: latestAdaptation?.id)
    }

    // MARK: - Plan tab content

    private var planContent: some View {
        // Each branch carries its own transition. SwiftData's @Query republishes
        // can land outside a caller's withAnimation block, so we attach
        // .animation(value:) here to drive the transition off plan-existence
        // changes directly — guarantees the deletion / generation swap animates.
        Group {
            if let plan {
                VStack(alignment: .leading, spacing: 24) {
                    if isGenerating {
                        generatingBanner.slideIn(delay: 0)
                    }
                    if let adaptation = latestAdaptation {
                        adaptationBanner(adaptation)
                            .slideIn(delay: 0.02)
                    }
                    planSummaryCard(plan)
                        .slideIn(delay: 0.10)
                    fineTunePlanButton
                        .slideIn(delay: 0.14)
                    planDistanceCard(plan)
                        .slideIn(delay: 0.18)
                    // Plan-tab ad banner — sits between distance and calendar
                    // so it doesn't interrupt the eye-flow from "summary" to
                    // "this week's session" higher up. Hidden for premium
                    // users via ConditionalAdBanner's @EnvironmentObject
                    // gating; collapses to zero height when not loaded.
                    ConditionalAdBanner(adUnitID: AdManager.planBannerAdUnitID)
                        .padding(.horizontal, 24)
                    trainingCalendar(plan)
                        .slideIn(delay: 0.22)
                }
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.97)),
                    removal: .opacity.combined(with: .scale(scale: 0.95)).combined(with: .offset(y: 12))
                ))
            } else if isGenerating {
                generatingCard
                    .slideIn(delay: 0.04)
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
            } else {
                noPlanCard
                    .slideIn(delay: 0.04)
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.82), value: plan?.id)
        .animation(.easeInOut(duration: 0.25), value: isGenerating)
        // Drives the adaptation banner's slide/fade in. Without this the
        // @Query republish lands outside any animation block and the banner
        // pops into existence, instantly shoving the cards below it down.
        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: latestAdaptation?.id)
        .padding(.top, 8)
        .sheet(isPresented: $showClearPlanConfirm) {
            ClearPlanConfirmSheet(
                onConfirm: {
                    showClearPlanConfirm = false
                    onClearPlan?()
                },
                onCancel: { showClearPlanConfirm = false }
            )
            .presentationDetents([.height(360)])
            .presentationDragIndicator(.visible)
            .presentationBackground(.ultraThinMaterial)
        }
        .sheet(isPresented: $showFineTuneOptions) {
            FineTunePlanSheet(
                onChoose: { reason in
                    showFineTuneOptions = false
                    triggerAdapt(reason)
                },
                onCancel: { showFineTuneOptions = false }
            )
            .presentationDetents([.height(460)])
            .presentationDragIndicator(.visible)
            .presentationBackground(.ultraThinMaterial)
        }
        .sheet(isPresented: $showPlanOverview) {
            if let plan {
                PlanOverviewSheet(plan: plan, isImperial: isImperial)
                    .presentationDragIndicator(.visible)
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(trigger: paywallTrigger)
        }
        .alert("Couldn't adjust your plan", isPresented: Binding(
            get: { adaptError != nil },
            set: { if !$0 { adaptError = nil } }
        )) {
            Button("OK") { adaptError = nil }
        } message: {
            Text(adaptError ?? "")
        }
    }

    private func triggerAdapt(_ reason: AdaptationReason) {
        guard !isAdapting else { return }
        isAdapting = true
        Task { @MainActor in
            defer { isAdapting = false }
            do {
                _ = try await RunningPlanService.shared.adaptPlan(
                    reason: reason,
                    context: modelContext
                )
                // Banner auto-appears via the @Query → latestAdaptation pipeline
                // once syncRunningPlans pulls the new row down. Refresh reminders
                // so any session whose target distance/pace changed gets the new
                // body the next time the morning nudge fires.
                await RunningWorkoutReminderScheduler.refresh(context: modelContext)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            } catch let error as RunningPlanGenerationError {
                // Rate limits get a soft toast — full alert feels too heavy
                // for a "wait a bit" situation. Other errors use the alert.
                if case .rateLimited = error {
                    showRateLimitToast("Take a breather — try fine-tuning again in an hour.")
                } else {
                    adaptError = error.errorDescription ?? "Adjustment failed."
                }
            } catch {
                adaptError = error.localizedDescription
            }
        }
    }

    // MARK: - Adaptation banner

    /// Surfaces the most recent unacknowledged plan adjustment. Tapping the X
    /// flips `acknowledgedAt` locally + via cloud sync, so it stays dismissed
    /// across devices.
    @ViewBuilder
    private func adaptationBanner(_ adaptation: RunningPlanAdaptation) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.runAccent.opacity(0.18))
                    .frame(width: 36, height: 36)
                Image(systemName: "sparkles")
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(.runAccent)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Plan adjusted")
                    .font(.caption.weight(.bold))
                    .foregroundColor(.runAccent)
                Text(adaptation.summary)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(primaryText)
                    .fixedSize(horizontal: false, vertical: true)
                Text(adaptation.reason.bannerLabel)
                    .font(.caption2)
                    .foregroundColor(tertiaryText)
            }

            Spacer(minLength: 0)

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                Task { @MainActor in
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        adaptation.acknowledgedAt = Date()
                        adaptation.updatedAt = Date()
                        try? modelContext.save()
                    }
                    await CloudSyncManager.shared.acknowledgeAdaptation(adaptation)
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundColor(secondaryText)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(Color.white.opacity(0.08)))
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.runAccent.opacity(0.10))
        )
        .padding(.horizontal, 24)
        .transition(.asymmetric(
            insertion: .opacity.combined(with: .scale(scale: 0.95)).combined(with: .offset(y: -8)),
            removal: .opacity.combined(with: .scale(scale: 0.95))
        ))
    }

    /// Manual entry point for triggering an adaptation. Lets the user fine-tune
    /// the plan on demand — also serves as the test affordance for phase 1
    /// before auto-detect signals are wired up.
    /// Premium-gated: free users get the auto-generated weekly check-in instead.
    private var fineTunePlanButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            // Gate at tap-time so non-premium users see the paywall, not a
            // half-loaded sheet they can't act on.
            if !StoreKitManager.shared.isPremium {
                paywallTrigger = "running_fine_tune"
                showPaywall = true
                return
            }
            showFineTuneOptions = true
        } label: {
            HStack(spacing: 10) {
                if isAdapting {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: "sparkles")
                }
                Text(isAdapting ? "Adjusting your plan…" : "Fine-tune Plan")
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.runAccent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color.runAccent.opacity(0.10)))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.runAccent.opacity(0.30), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(isAdapting)
        .padding(.horizontal, 24)
    }


    // MARK: - Inline training calendar
    // Shared static formatters live on `RunningTodayFormatters` (top of file)
    // because static stored properties aren't allowed inside generic types.

    /// Multi-week calendar embedded directly in the Plan tab. One card per
    /// week, every day shown — runs, cross-training, and rest. Lazy so a
    /// long plan (24 weeks) doesn't pay the full layout cost up front.
    /// Uses `cachedWeekGroups` so the body re-eval is just an array iteration
    /// (the grouping work happens once in `recomputeCaches`).
    @ViewBuilder
    private func trainingCalendar(_ plan: RunningPlan) -> some View {
        // Whole-calendar Equatable wrapper — header + every week card. When
        // the parent body re-evaluates (HK publish, fitnessService publish,
        // theme change…) and `cachedPlanWeekCards` hasn't changed, the
        // entire subtree is skipped.
        TrainingCalendarView(
            cards: cachedPlanWeekCards,
            unitLabel: unitLabel,
            onSessionTap: { sessionID in
                // Resolve UUID → live session at tap time so the cell view
                // doesn't have to hold a reference.
                if let session = cachedSortedSessions.first(where: { $0.id == sessionID }) {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    onSessionTapped?(session)
                }
            }
        )
        .equatable()
    }

    /// Parameterized companion to `crossActivitiesOnSelectedDate` — used by
    /// the inline calendar. O(1) lookup against the pre-built day map so a
    /// 168-row calendar doesn't scan `CrossTrainingActivity.allCases` per row.
    private func crossActivities(for date: Date) -> [CrossTrainingActivity] {
        let weekday: Weekday?
        switch Calendar.current.component(.weekday, from: date) {
        case 1: weekday = .sun
        case 2: weekday = .mon
        case 3: weekday = .tue
        case 4: weekday = .wed
        case 5: weekday = .thu
        case 6: weekday = .fri
        case 7: weekday = .sat
        default: weekday = nil
        }
        return weekday.flatMap { cachedCrossByWeekday[$0] } ?? []
    }

    // MARK: - Today run blocks
    
    @ViewBuilder
    private func completedRunCard(_ run: LoggedRun) -> some View {
        Button {
            let haptic = UIImpactFeedbackGenerator(style: .light)
            haptic.impactOccurred()
            onRunSelected?(run)
        } label: {
            FrostedGlassContainer {
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color.runDone.opacity(0.15))
                            .frame(width: 48, height: 48)
                        Image(systemName: "figure.run")
                            .foregroundStyle(Color.runDone)
                            .font(.title3)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Outdoor Run")
                            .font(.headline)
                            .foregroundStyle(primaryText)
                        
                        HStack(spacing: 8) {
                            Text(String(format: "%.2f km", run.distanceKm))
                            Text("·")
                            Text("\(Int(run.durationMinutes)) min")
                        }
                        .font(.subheadline)
                        .foregroundStyle(secondaryText)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundStyle(tertiaryText)
                }
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 24)
    }

    // MARK: - Today plan card

    private func todayCard(_ plan: RunningPlan) -> some View {
        let headerTitle: String = isSelectedToday
            ? "Today's Session"
            : selectedDate.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
        let tint: Color = selectedSession.map { tintFor($0) } ?? .runAccent

        return ZStack {
            // Standard app card background — flat, no border, matches the other cards.
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color("AppCardBackground"))

            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack(spacing: 8) {
                    Image(systemName: "figure.run.circle.fill")
                        .foregroundStyle(tint)
                        .font(.title3)
                    Text(headerTitle)
                        .font(.headline)
                        .foregroundStyle(primaryText)
                    Spacer()
                    Text("Week \(selectedWeekNumber) of \(plan.totalWeeks)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(tint)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(tint.opacity(0.12)))
                }

                Divider().overlay(tint.opacity(0.25))

                if let session = selectedSession {
                    // Flatten the session-detail block (icon + metrics +
                    // logged status + tap-to-update button) into a single
                    // Metal-backed texture. Many small sub-views per
                    // render were thrashing the GPU compositor on this
                    // tab. Buttons inside drawingGroup keep working in
                    // iOS 17+ (proven on the Plan tab calendar cells).
                    // Limited to this block — the week-strip below has a
                    // horizontal ScrollView that drawingGroup would break.
                    // See PERF NOTE at top of this file for the full
                    // investigation.
                    sessionDetailBlock(session)
                        .drawingGroup()
                } else {
                    restDayBlock
                        .drawingGroup()
                }

                Divider().overlay(tint.opacity(0.25))

                weekStripBlock(tint: tint)
            }
            .padding(20)
        }
        // .drawingGroup() removed — it rasterizes the view, which breaks the
        // ScrollView and tap targets in the embedded week strip below.
        .shadow(color: tint.opacity(0.15), radius: 10, x: 0, y: 5)
        .padding(.horizontal, 24)
    }

    // MARK: - Week strip (embedded in todayCard)

    /// Inline week strip — same multi-week scrollable affordance the standalone
    /// `weekStripCard` previously provided, just without its FrostedGlass
    /// wrapper so it lives inside the gradient `todayCard` as one unified block.
    @ViewBuilder
    private func weekStripBlock(tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("SCHEDULE")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(tertiaryText)
                Spacer()
                Button { onSwitchToTab(.plan) } label: {
                    Text("Full Plan")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(tint)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(tint.opacity(0.14)))
                }
                .buttonStyle(.plain)
            }

            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: 16) {
                        ForEach(weekGroups, id: \.week) { group in
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Wk \(group.week)")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(group.week == selectedWeekNumber ? tint : tertiaryText)
                                    .padding(.leading, 2)
                                HStack(spacing: 4) {
                                    ForEach(group.sessions, id: \.id) { session in
                                        weekDot(session)
                                            .id(session.id)
                                    }
                                }
                            }
                            .id("week-\(group.week)")
                        }
                    }
                    // Small horizontal padding so the leftmost (Mon) and
                    // rightmost (Sun) dots aren't flush against the parent
                    // card's edge — their selection stroke + today-marker
                    // dot otherwise get visually clipped.
                    .padding(.horizontal, 4)
                    .padding(.bottom, 2)
                }
                .onAppear {
                    DispatchQueue.main.async {
                        proxy.scrollTo("week-\(currentWeekNumber)", anchor: .leading)
                    }
                }
                .onChange(of: selectedDate) { _, _ in
                    if let id = selectedSession?.id {
                        withAnimation { proxy.scrollTo(id, anchor: .center) }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func sessionDetailBlock(_ session: PlannedSession) -> some View {
        let tint = tintFor(session)
        let pendingWorkout = pendingTodayRuns.first

        VStack(alignment: .leading, spacing: 14) {
            // Session type + status — tappable to open detail view
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onSessionTapped?(session)
            } label: {
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(tint.opacity(0.18))
                            .frame(width: 62, height: 62)
                        Image(systemName: iconFor(session))
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(tint)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Text(session.sessionType.displayLabel)
                                .font(.title2.weight(.bold))
                                .foregroundStyle(primaryText)
                            if session.isCompleted {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(.runDone).font(.headline)
                            } else if session.skipped {
                                Image(systemName: "forward.fill").foregroundStyle(tertiaryText).font(.subheadline)
                            }
                        }
                        HStack(spacing: 6) {
                            if let km = session.targetDistanceKm, km > 0 { metricChip(formatDist(km), tint: tint) }
                            if let m = session.targetDurationMinutes, m > 0 { metricChip("\(m) min", tint: tint) }
                            if let p = session.targetPaceSecondsPerKm, p > 0 { metricChip(formatPace(p), tint: tint) }
                        }
                        // Cross-training overlap — when a run lands on a day
                        // the user already trains on, surface it inline so
                        // they can plan around the heavier total load.
                        if !crossActivitiesOnSelectedDate.isEmpty {
                            crossTrainingChip(crossActivitiesOnSelectedDate)
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(tertiaryText)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(onSessionTapped == nil)

            Text(session.sessionDescription)
                .font(.subheadline)
                .foregroundStyle(secondaryText)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            if let notes = session.notes, !notes.isEmpty {
                Text(notes)
                    .font(.caption)
                    .foregroundStyle(secondaryText)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 10).fill(tint.opacity(0.07)))
            }

            // Detected HealthKit run — shown inline before the log button
            if let workout = pendingWorkout {
                detectedRunInline(workout)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.95, anchor: .top)),
                        removal:   .opacity.combined(with: .scale(scale: 0.95, anchor: .top))
                    ))
            }

            // Actual results after completion
            if session.isCompleted {
                Button {
                    let haptic = UIImpactFeedbackGenerator(style: .light)
                    haptic.impactOccurred()
                    
                    if let run = fitnessService.runs.first(where: { Calendar.current.isDate($0.runDate, inSameDayAs: selectedDate) }) {
                        onRunSelected?(run)
                    } else {
                        let distKm = session.completedDistanceKm ?? session.targetDistanceKm ?? 0.0
                        let durMinVal = session.completedDurationMinutes ?? session.targetDurationMinutes ?? 0
                        let durMin = Double(durMinVal)
                        
                        var calculatedPace: String? = nil
                        if distKm > 0 && durMin > 0 {
                            let paceSeconds = (durMin * 60) / distKm
                            let mins = Int(paceSeconds) / 60
                            let secs = Int(paceSeconds) % 60
                            calculatedPace = String(format: "%d:%02d", mins, secs)
                        }
                        
                        // Probe HealthKit locally for the granular metadata not stored in the AI planner
                        let healthRecord = HealthKitManager.shared.weeklyWorkouts.first { 
                            Calendar.current.isDate($0.date, inSameDayAs: selectedDate) && 
                            $0.typeName.localizedCaseInsensitiveContains("run")
                        }
                        
                        let syntheticRun = LoggedRun(
                            id: UUID(),
                            runDate: healthRecord?.date ?? session.scheduledDate,
                            distanceKm: distKm,
                            durationMinutes: durMin,
                            calories: healthRecord?.caloriesBurned,
                            avgPace: calculatedPace,
                            avgHeartRate: healthRecord?.avgHeartRate,
                            elevationGain: healthRecord?.elevationAscendedMeters != nil ? Int(healthRecord!.elevationAscendedMeters!) : nil,
                            feedback: "This is a completed AI Coach Training Plan objective.\n\n\(session.sessionDescription)\n\n\(session.notes ?? "")"
                        )
                        onRunSelected?(syntheticRun)
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(Color.runDone.opacity(0.08))
                                    .frame(width: 52, height: 52)
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundStyle(Color.runDone.opacity(0.75))
                            }
                            VStack(alignment: .leading, spacing: 5) {
                                HStack(spacing: 8) {
                                    Text("Session Logged")
                                        .font(.headline)
                                        .foregroundStyle(primaryText)
                                    Text("LOGGED")
                                        .font(.caption2.weight(.bold))
                                        .foregroundStyle(Color.runDone)
                                        .padding(.horizontal, 6).padding(.vertical, 2)
                                        .background(Capsule().fill(Color.runDone.opacity(0.12)))
                                }
                                if let source = session.completedSource {
                                    HStack(spacing: 4) {
                                        Image(systemName: source == "healthkit" ? "heart.fill" : "hand.tap.fill")
                                            .font(.caption2)
                                            .foregroundStyle(source == "healthkit" ? Color.runPink.opacity(0.8) : secondaryText)
                                        Text(source == "healthkit" ? "Apple Health" : "Manual entry")
                                            .font(.caption)
                                            .foregroundStyle(secondaryText)
                                    }
                                }
                            }
                            Spacer()
                            if onRunSelected != nil {
                                Image(systemName: "chevron.right")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(tertiaryText)
                            }
                        }

                        HStack(spacing: 0) {
                            if let distKm = session.completedDistanceKm ?? session.targetDistanceKm {
                                pendingStat(label: "ACTUAL", value: formatDist(distKm), color: primaryText)
                                Divider().frame(height: 28).padding(.horizontal, 12)
                            }
                            if let mins = session.completedDurationMinutes ?? session.targetDurationMinutes {
                                pendingStat(label: "TIME", value: "\(mins) min", color: primaryText)
                            }
                            Spacer()
                        }
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.primary.opacity(0.04))
                    )
                    .contentShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.95, anchor: .top)),
                    removal:   .opacity.combined(with: .scale(scale: 0.95, anchor: .top))
                ))
            }

            if session.sessionType.isRun {
                if let workout = pendingWorkout, !session.isCompleted {
                    // Detected run — primary logs it directly, secondary opens picker
                    VStack(spacing: 8) {
                        Button {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                                onAutoLogSession?(session, workout)
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Log This Run")
                            }
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.runOrange.opacity(0.14))
                            .foregroundStyle(Color.runOrange)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(.plain)

                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            onMarkComplete(session)
                        } label: {
                            Text("Log a different one")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(tertiaryText)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(RoundedRectangle(cornerRadius: 12).fill(Color.gray.opacity(0.08)))
                        }
                        .buttonStyle(.plain)
                    }
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.95, anchor: .bottom)),
                        removal:   .opacity.combined(with: .scale(scale: 0.95, anchor: .bottom))
                    ))
                } else {
                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        onMarkComplete(session)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: session.isCompleted ? "arrow.uturn.backward.circle" : "checkmark.circle.fill")
                            Text(session.isCompleted ? "Logged · tap to update" : "Log This Session")
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(session.isCompleted ? Color.runDone.opacity(0.18) : tint.opacity(0.14))
                        .foregroundStyle(session.isCompleted ? Color.runDone : tint)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.95, anchor: .bottom)),
                        removal:   .opacity.combined(with: .scale(scale: 0.95, anchor: .bottom))
                    ))
                }
            } else if session.sessionType == .rest {
                // Planned rest day — user can still log a run as an extra session.
                if let workout = pendingWorkout, let logRun = onLogUnplannedRun {
                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        logRun(workout)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Log This Run")
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.runOrange.opacity(0.14))
                        .foregroundStyle(Color.runOrange)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                } else if let logRun = onLogUnplannedRun {
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        logRun(nil)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle")
                            Text("Log a run anyway")
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(tertiaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.gray.opacity(0.08)))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var restDayBlock: some View {
        let pendingWorkout = pendingTodayRuns.first
        let crossActivities = crossActivitiesOnSelectedDate
        let hasCross = !crossActivities.isEmpty
        let crossIconName = crossActivities.first.map(crossActivityIcon) ?? "moon.zzz.fill"

        return VStack(spacing: 12) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(hasCross ? Color.runAccent.opacity(0.14) : Color.gray.opacity(0.12))
                        .frame(width: 48, height: 48)
                    Image(systemName: crossIconName)
                        .font(.title3)
                        .foregroundStyle(hasCross ? Color.runAccent : tertiaryText)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(hasCross ? crossActivityTitle(crossActivities) : "Rest Day")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(primaryText)
                    Text(hasCross
                         ? "Your scheduled cross-training day — no run today."
                         : "Recovery is part of the plan — see you next session.")
                        .font(.subheadline)
                        .foregroundStyle(secondaryText)
                }
                Spacer()
            }

            if let workout = pendingWorkout {
                // A run was detected — show it inline and offer to log it
                detectedRunInline(workout)

                if let logRun = onLogUnplannedRun {
                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        logRun(workout)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Log This Run")
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.runOrange.opacity(0.14))
                        .foregroundStyle(Color.runOrange)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            } else if let logRun = onLogUnplannedRun {
                // No detected run — subtle manual option
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    logRun(nil)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle")
                        Text("Log a run anyway")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(tertiaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.gray.opacity(0.08)))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Detected run inline (embedded inside today's session card)

    /// Full-size orange card shown inside the session/rest-day card when
    /// HealthKit has synced a run that hasn't been logged against the plan yet.
    @ViewBuilder
    private func detectedRunInline(_ workout: WorkoutSummary) -> some View {
        let distKm = (workout.distanceMeters ?? 0) / 1000
        let durMin = workout.durationMinutes
        let paceSpk: Int? = distKm > 0.01 && durMin > 0 ? Int((durMin * 60) / distKm) : nil

        // Header — tappable to view run detail
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            let synthetic = LoggedRun(
                id: UUID(),
                runDate: workout.date,
                distanceKm: distKm,
                durationMinutes: durMin,
                calories: workout.caloriesBurned > 0 ? workout.caloriesBurned : nil,
                avgPace: paceSpk.map { formatPace($0) },
                avgHeartRate: workout.avgHeartRate,
                elevationGain: workout.elevationAscendedMeters.map { Int($0) },
                feedback: "Synced from \(workout.sourceName)"
            )
            onRunSelected?(synthetic)
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Color.runOrange.opacity(0.08))
                            .frame(width: 52, height: 52)
                        Image(systemName: "figure.run")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(Color.runOrange.opacity(0.75))
                    }
                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 8) {
                            Text("Run Detected")
                                .font(.headline)
                                .foregroundStyle(primaryText)
                            Text("UNLOGGED")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(Color.runOrange)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Capsule().fill(Color.runOrange.opacity(0.12)))
                        }
                        Text("from \(workout.sourceName) · \(workout.date.formatted(.dateTime.hour().minute()))")
                            .font(.caption)
                            .foregroundStyle(secondaryText)
                    }
                    Spacer()
                    if onRunSelected != nil {
                        Image(systemName: "chevron.right")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(tertiaryText)
                    }
                }

                HStack(spacing: 0) {
                    if distKm > 0.01 {
                        pendingStat(label: "DISTANCE", value: formatDist(distKm), color: primaryText)
                        Divider().frame(height: 28).padding(.horizontal, 12)
                    }
                    pendingStat(label: "TIME", value: "\(Int(durMin)) min", color: primaryText)
                    if let spk = paceSpk {
                        Divider().frame(height: 28).padding(.horizontal, 12)
                        pendingStat(label: "PACE", value: formatPace(spk), color: primaryText)
                    }
                    Spacer()
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.primary.opacity(0.04))
            )
            .contentShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .disabled(onRunSelected == nil)
    }

    private func pendingStat(label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption2.weight(.bold)).foregroundStyle(tertiaryText)
            Text(value).font(.subheadline.weight(.semibold)).foregroundStyle(color)
        }
    }

    // MARK: - Week strip card

    private var weekStripCard: some View {
        FrostedGlassContainer {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    Image(systemName: "calendar").foregroundStyle(Color.runAccent)
                    Text("Schedule").font(.headline).foregroundStyle(primaryText)
                    Spacer()
                    Button { onSwitchToTab(.plan) } label: {
                        Text("Full Plan")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.runAccent)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(Color.runAccent.opacity(0.1)))
                    }
                    .buttonStyle(.plain)
                }

                Divider().opacity(0.3)

                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        // LazyHStack so only weeks scrolled into view materialize.
                        // Plain HStack mounts every week-dot for every week on
                        // first appear (84+ shape views for a 12-week plan),
                        // which dominated the Today sub-tab's mount lag.
                        LazyHStack(alignment: .top, spacing: 16) {
                            ForEach(weekGroups, id: \.week) { group in
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Wk \(group.week)")
                                        .font(.caption2.weight(.bold))
                                        .foregroundStyle(group.week == selectedWeekNumber ? Color.runAccent : tertiaryText)
                                        .padding(.leading, 2)
                                    HStack(spacing: 4) {
                                        ForEach(group.sessions, id: \.id) { session in
                                            weekDot(session)
                                                .id(session.id)
                                        }
                                    }
                                }
                                .id("week-\(group.week)")
                            }
                        }
                        .padding(.horizontal, 2)
                        .padding(.bottom, 2)
                    }
                    .onAppear {
                        DispatchQueue.main.async {
                            proxy.scrollTo("week-\(currentWeekNumber)", anchor: .leading)
                        }
                    }
                    .onChange(of: selectedDate) { _, _ in
                        if let id = selectedSession?.id {
                            withAnimation { proxy.scrollTo(id, anchor: .center) }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 24)
    }

    private func weekDot(_ session: PlannedSession) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.spring(response: 0.25)) {
                selectedDate = Calendar.current.startOfDay(for: session.scheduledDate)
            }
        } label: {
            weekDotInner(session)
        }
        .buttonStyle(.plain)
    }

    private func weekDotInner(_ session: PlannedSession) -> some View {
        let isTodayDot = Calendar.current.isDateInToday(session.scheduledDate)
        let isSelected = Calendar.current.isDate(session.scheduledDate, inSameDayAs: selectedDate)
        let tint = tintFor(session)

        return VStack(spacing: 5) {
            Text(RunningTodayFormatters.narrowDay.string(from: session.scheduledDate))
                .font(.caption2.weight(.bold))
                .foregroundStyle(isSelected ? tint : tertiaryText)
            ZStack {
                Circle()
                    .fill(session.sessionType == .rest
                          ? Color.gray.opacity(isSelected ? 0.2 : 0.12)
                          : tint.opacity(session.isCompleted ? 1.0 : (isSelected ? 0.25 : 0.15)))
                    .frame(width: 34, height: 34)
                if session.isCompleted {
                    Image(systemName: "checkmark").font(.caption.weight(.bold)).foregroundStyle(.white)
                } else if session.skipped {
                    Image(systemName: "forward.fill").font(.caption2).foregroundStyle(tint.opacity(0.5))
                } else if session.sessionType == .rest {
                    Image(systemName: "moon.zzz.fill").font(.caption2).foregroundStyle(tertiaryText)
                } else {
                    Text(String(session.sessionType.displayLabel.prefix(1)))
                        .font(.caption.weight(.bold)).foregroundStyle(tint)
                }
            }
            .overlay(Circle().stroke(isSelected ? tint : .clear, lineWidth: 2))
            // Small dot below to mark actual today
            Circle()
                .fill(isTodayDot ? tint : .clear)
                .frame(width: 4, height: 4)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Race countdown card

    @ViewBuilder
    private func raceCountdownCard(_ plan: RunningPlan) -> some View {
        if let raceDate = plan.targetRaceDate {
            let cal = Calendar.current
            let startOfRace = cal.startOfDay(for: raceDate)
            let startOfToday = cal.startOfDay(for: Date())
            let daysLeft = cal.dateComponents([.day], from: startOfToday, to: startOfRace).day ?? 0
            let title: String = {
                if let name = plan.targetRaceName?.trimmingCharacters(in: .whitespaces), !name.isEmpty {
                    return name
                }
                return plan.targetRaceDistance?.rawValue ?? "Race Day"
            }()
            let subtitle: String = {
                let dateStr = raceDate.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
                if let dist = plan.targetRaceDistance?.rawValue,
                   plan.targetRaceName?.isEmpty == false {
                    return "\(dist) · \(dateStr)"
                }
                return dateStr
            }()

            FrostedGlassContainer {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .center, spacing: 14) {
                        ZStack {
                            Circle().fill(Color.runAccent.opacity(0.15)).frame(width: 48, height: 48)
                            Image(systemName: "flag.checkered")
                                .font(.title3.weight(.bold))
                                .foregroundStyle(Color.runAccent)
                        }

                        Text(title)
                            .font(.headline)
                            .foregroundStyle(primaryText)
                            .lineLimit(2)
                            .minimumScaleFactor(0.85)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        countdownPill(daysLeft: daysLeft)
                    }

                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(16)
            }
            .padding(.horizontal, 24)
        }
    }

    @ViewBuilder
    private func countdownPill(daysLeft: Int) -> some View {
        let (value, unit): (String, String) = {
            if daysLeft < 0 { return ("Done", "") }
            if daysLeft == 0 { return ("Today", "") }
            if daysLeft == 1 { return ("1", "day") }
            if daysLeft < 14 { return ("\(daysLeft)", "days") }
            let weeks = daysLeft / 7
            let extra = daysLeft % 7
            if extra == 0 { return ("\(weeks)", weeks == 1 ? "week" : "weeks") }
            return ("\(weeks)w \(extra)d", "to go")
        }()

        VStack(alignment: .trailing, spacing: 2) {
            Text(value)
                .font(.title3.weight(.bold).monospacedDigit())
                .foregroundStyle(Color.runAccent)
            if !unit.isEmpty {
                Text(unit)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(tertiaryText)
                    .textCase(.uppercase)
                    .tracking(0.5)
            }
        }
    }

    // MARK: - Weekly stats card

    /// Whole-plan stats card — name, total weeks, runs done, race countdown.
    /// Tap opens the full plan overview sheet. Replaces the previous weekly-
    /// scope card so the Plan tab leads with plan-level summary information.
    private func planSummaryCard(_ plan: RunningPlan) -> some View {
        let summary = cachedPlanSummary
        let runsCount = summary.runsCount
        let done = summary.doneRunsCount

        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            showPlanOverview = true
        } label: {
            FrostedGlassContainer {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 10) {
                        ZStack {
                            Circle().fill(Color.runAccent.opacity(0.12)).frame(width: 38, height: 38)
                            Image(systemName: "figure.run")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(Color.runAccent)
                        }
                        // Lead with the runner's race / event name when set —
                        // it's the most personal, motivating string we have.
                        // Fall back to the plan name otherwise.
                        VStack(alignment: .leading, spacing: 2) {
                            if let raceName = plan.targetRaceName, !raceName.isEmpty {
                                Text(raceName)
                                    .font(.headline)
                                    .foregroundStyle(primaryText)
                                    .lineLimit(1)
                                Text(plan.name)
                                    .font(.caption)
                                    .foregroundStyle(secondaryText)
                                    .lineLimit(1)
                            } else {
                                Text(plan.name)
                                    .font(.headline)
                                    .foregroundStyle(primaryText)
                                    .lineLimit(1)
                                if let dist = plan.targetRaceDistance {
                                    Text(dist.rawValue)
                                        .font(.caption)
                                        .foregroundStyle(secondaryText)
                                }
                            }
                        }
                        Spacer()
                        // Plan-level actions live behind a menu so the card
                        // stays tap-to-overview but destructive actions like
                        // "Clear Plan" are still discoverable from the same
                        // place — no separate destructive button at the bottom
                        // of the screen.
                        Menu {
                            Button {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                showPlanOverview = true
                            } label: {
                                Label("Plan Overview", systemImage: "doc.text")
                            }
                            Button(role: .destructive) {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                showClearPlanConfirm = true
                            } label: {
                                Label("Clear Plan", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(tertiaryText)
                                .frame(width: 32, height: 32)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }

                    Divider().opacity(0.3)

                    HStack(spacing: 12) {
                        overviewStat(value: "\(plan.totalWeeks)", unit: "wks", label: "Total", color: .runAccent)
                        overviewStat(value: "\(done)", unit: "/\(runsCount)", label: "Done", color: .runDone)
                        if let daysLeft = summary.daysToRace {
                            overviewStat(value: "\(max(0, daysLeft))", unit: "days", label: "To race", color: .runOrange)
                        } else if let goalSecs = plan.targetRaceGoalTimeSeconds {
                            overviewStat(value: formatSeconds(goalSecs), unit: "", label: "Goal time", color: .runAccent)
                        }
                    }

                    if runsCount > 0 {
                        VStack(alignment: .leading, spacing: 4) {
                            ProgressView(value: Double(done), total: Double(runsCount)).tint(.runAccent)
                            Text("\(done) of \(runsCount) sessions complete")
                                .font(.caption).foregroundStyle(tertiaryText)
                        }
                    }
                }
            }
        }
        .buttonStyle(.plain)
        // Outer `.compositingGroup()` removed — `FrostedGlassContainer`
        // now flattens internally.
        .padding(.horizontal, 24)
    }

    /// Distance-progress card — logged / total / remaining + a horizontal
    /// gradient progress bar across the whole plan. Sits underneath the
    /// week-strip on the Plan tab so the eye flows from "what's this week"
    /// to "how does the whole plan look" naturally.
    private func planDistanceCard(_ plan: RunningPlan) -> some View {
        let dist = cachedPlanDistance
        let fraction = dist.fraction
        let loggedDisplay = dist.loggedDisplay
        let totalDisplay = dist.totalDisplay
        let remainingDisplay = dist.remainingDisplay

        return FrostedGlassContainer {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    Image(systemName: "map.fill").foregroundStyle(Color.runBlue)
                    Text("Plan Distance").font(.headline).foregroundStyle(primaryText)
                    Spacer()
                    Text(String(format: "%.0f%%", fraction * 100))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(fraction >= 1.0 ? Color.runDone : Color.runBlue)
                }

                Divider().opacity(0.3)

                HStack(spacing: 12) {
                    overviewStat(value: String(format: "%.1f", loggedDisplay), unit: unitLabel,
                                 label: "Logged", color: .runDone)
                    overviewStat(value: String(format: "%.1f", totalDisplay), unit: unitLabel,
                                 label: "Total", color: .runAccent)
                    overviewStat(value: String(format: "%.1f", remainingDisplay), unit: unitLabel,
                                 label: "Remaining", color: .runOrange)
                }

                VStack(alignment: .leading, spacing: 6) {
                    // Progress bar without GeometryReader. The track fills
                    // the full width; the fill is `scaleEffect`-anchored
                    // from the leading edge. Avoids the layout-invalidation
                    // costs of a GeometryReader inside a scrolling parent.
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.gray.opacity(0.12))
                            .frame(height: 10)
                        RoundedRectangle(cornerRadius: 6)
                            .fill(
                                LinearGradient(colors: [.runDone, .runBlue],
                                               startPoint: .leading, endPoint: .trailing)
                            )
                            .frame(height: 10)
                            .scaleEffect(x: max(0, fraction), y: 1, anchor: .leading)
                            .animation(.spring(duration: 0.6), value: fraction)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 10)

                    Text(String(format: "%.1f of %.1f %@ across \(plan.totalWeeks) weeks",
                                loggedDisplay, totalDisplay, unitLabel))
                        .font(.caption).foregroundStyle(tertiaryText)
                }
            }
        }
        // Outer `.compositingGroup()` removed — `FrostedGlassContainer`
        // now flattens internally.
        .padding(.horizontal, 24)
    }

    private func overviewStat(value: String, unit: String, label: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value).font(.title2.weight(.bold)).foregroundStyle(color)
                Text(unit).font(.caption.weight(.semibold)).foregroundStyle(color.opacity(0.7))
            }
            Text(label).font(.caption).foregroundStyle(tertiaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(color.opacity(0.08)))
    }

    private func formatSeconds(_ t: Int) -> String {
        let h = t / 3600
        let m = (t % 3600) / 60
        return h > 0 ? String(format: "%d:%02d", h, m) : "\(m)m"
    }

    // MARK: - Upcoming card

    @ViewBuilder
    private var upcomingCard: some View {
        let cal = Calendar.current
        let weekday = cal.component(.weekday, from: today) // 1=Sun, 2=Mon … 7=Sat
        let daysToSunday = (8 - weekday) % 7             // 0 if today is Sunday
        // End-of-week = start of NEXT Monday so sessions stored at 06:00 UTC
        // (≈ 2 AM EDT) on Sunday aren't clipped by a midnight-Sunday boundary.
        let startOfSunday = cal.date(byAdding: .day, value: daysToSunday, to: today) ?? today
        let endOfWeek = cal.date(byAdding: .day, value: 1, to: startOfSunday) ?? startOfSunday
        let upcoming = sortedSessions.filter {
            cal.startOfDay(for: $0.scheduledDate) > today && $0.scheduledDate < endOfWeek && !$0.isCompleted && $0.sessionType.isRun
        }

        if !upcoming.isEmpty {
            FrostedGlassContainer {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.right.circle.fill").foregroundStyle(Color.runAccent)
                        Text("Coming Up").font(.headline).foregroundStyle(primaryText)
                    }

                    Divider().opacity(0.3)

                    VStack(spacing: 10) {
                        ForEach(upcoming, id: \.id) { session in upcomingRow(session) }
                    }
                }
            }
            .padding(.horizontal, 24)
        }
    }

    private func upcomingRow(_ session: PlannedSession) -> some View {
        let tint = tintFor(session)
        return HStack(spacing: 12) {
            ZStack {
                Circle().fill(tint.opacity(0.12)).frame(width: 34, height: 34)
                Image(systemName: iconFor(session)).font(.subheadline.weight(.bold)).foregroundStyle(tint)
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(session.sessionType.displayLabel)
                        .font(.subheadline.weight(.semibold)).foregroundStyle(primaryText)
                    Spacer()
                    Text(session.scheduledDate.formatted(.dateTime.weekday(.wide)))
                        .font(.caption).foregroundStyle(tertiaryText)
                }
                HStack(spacing: 4) {
                    if let km = session.targetDistanceKm, km > 0 {
                        Text(formatDist(km)).font(.caption).foregroundStyle(secondaryText)
                    }
                    if let m = session.targetDurationMinutes, m > 0 {
                        Text("· \(m) min").font(.caption).foregroundStyle(secondaryText)
                    }
                }
            }
        }
    }

    // MARK: - Generation in progress

    // Full card — shown when no plan exists yet and generation is running.
    private var generatingCard: some View {
        FrostedGlassContainer {
            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(Color.runAccent.opacity(0.12))
                        .frame(width: 72, height: 72)
                    Circle()
                        .stroke(Color.runAccent.opacity(0.25), lineWidth: 1.5)
                        .frame(width: 88, height: 88)
                        .scaleEffect(generatingPulse ? 1.18 : 1.0)
                        .opacity(generatingPulse ? 0.0 : 1.0)
                    Image(systemName: "figure.run")
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundStyle(Color.runAccent)
                        .scaleEffect(generatingPulse ? 1.05 : 1.0)
                }
                .animation(.easeInOut(duration: 1.3).repeatForever(autoreverses: true), value: generatingPulse)
                .onAppear { generatingPulse = true }

                VStack(spacing: 6) {
                    Text("Building your plan…")
                        .font(.headline)
                        .foregroundStyle(primaryText)
                    Text("Your personalised AI plan is being created in the background. It'll appear here automatically when ready.")
                        .font(.subheadline)
                        .foregroundStyle(secondaryText)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                }

                HStack(spacing: 6) {
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .fill(Color.runAccent.opacity(generatingDot == i ? 1.0 : 0.25))
                            .frame(width: 6, height: 6)
                            .animation(.easeInOut(duration: 0.4), value: generatingDot)
                    }
                }
                .onAppear { startCycleDots() }
                .onDisappear { stopCycleDots() }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)
        }
        .padding(.horizontal, 24)
    }

    // Small banner — shown at the top of the plan when re-generation is in progress.
    private var generatingBanner: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color.runAccent.opacity(0.12))
                    .frame(width: 32, height: 32)
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.runAccent)
                    .rotationEffect(.degrees(generatingPulse ? 360 : 0))
                    .animation(.linear(duration: 1.8).repeatForever(autoreverses: false), value: generatingPulse)
            }
            .onAppear { generatingPulse = true }

            VStack(alignment: .leading, spacing: 1) {
                Text("Updating your plan…")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(primaryText)
                Text("Your new plan will replace this one when it's ready.")
                    .font(.caption)
                    .foregroundStyle(secondaryText)
            }
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.runAccent.opacity(0.08))
        )
        .padding(.horizontal, 24)
    }

    /// Drives the three-dot loading animation on the generating card.
    /// Critically: cancellable via `dotsTask` so it stops when the card
    /// disappears. The previous recursive `DispatchQueue.asyncAfter`
    /// version had no way to stop, so once a plan was ever generated in
    /// this app session the timer kept firing every 500ms forever — each
    /// tick mutating `@State` and forcing a full `RunningTodayView` body
    /// re-evaluation. This was the dominant Plan-tab lag source.
    private func startCycleDots() {
        stopCycleDots()
        dotsTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 500_000_000)
                if Task.isCancelled { return }
                generatingDot = (generatingDot + 1) % 3
            }
        }
    }

    private func stopCycleDots() {
        dotsTask?.cancel()
        dotsTask = nil
    }

    // MARK: - No plan

    private var noPlanCard: some View {
        FrostedGlassContainer {
            VStack(spacing: 14) {
                Image(systemName: "figure.run.circle")
                    .font(.system(size: 52)).foregroundStyle(Color.runAccent.opacity(0.45))
                Text("No active plan").font(.headline).foregroundStyle(primaryText)
                Text("Head back and generate a personalised AI running plan to get started.")
                    .font(.subheadline).foregroundStyle(secondaryText).multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Helpers

    private func completionStat(label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption2.weight(.bold)).foregroundStyle(tertiaryText)
            Text(value).font(.subheadline.weight(.semibold)).foregroundStyle(color)
        }
    }

    private func metricChip(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(Capsule().fill(tint.opacity(0.15)))
    }

    /// "Also: Strength Training" pill rendered under the run metrics when
    /// the selected day has cross-training scheduled. Purple to differentiate
    /// from the run's tint and signal "this is a different workout, not part
    /// of the running session itself."
    @ViewBuilder
    private func crossTrainingChip(_ activities: [CrossTrainingActivity]) -> some View {
        let icon = activities.first.map(crossActivityIcon) ?? "figure.strengthtraining.traditional"
        let label = "Also: \(crossActivityTitle(activities))"
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption2.weight(.semibold))
            Text(label)
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(Color.runAccent)
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(Capsule().fill(Color.runAccent.opacity(0.14)))
    }

    private func formatDist(_ km: Double) -> String {
        let v = isImperial ? km * 0.621371 : km
        return String(format: v < 10 ? "%.1f %@" : "%.0f %@", v, unitLabel)
    }

    private func formatPace(_ spk: Int) -> String {
        let s = isImperial ? Int(Double(spk) / 0.621371) : spk
        return String(format: "%d:%02d /%@", s / 60, s % 60, unitLabel)
    }

    private func tintFor(_ session: PlannedSession) -> Color {
        session.sessionType.tint
    }

    private func iconFor(_ session: PlannedSession) -> String {
        switch session.sessionType {
        case .easy, .recovery: return "figure.run"
        case .long:            return "arrow.up.right"
        case .tempo:           return "flame.fill"
        case .intervals:       return "bolt.fill"
        case .race:            return "flag.checkered"
        case .cross:           return "figure.mixed.cardio"
        case .rest:            return "moon.zzz.fill"
        }
    }
}

// MARK: - Convenience init

/// `Equatable` conformance so call sites can use `.equatable()` to short-
/// circuit body re-evaluation when meaningful inputs haven't changed. The
/// parent (`HealthRingsView`) re-evals on every `HealthKitManager` snapshot
/// publish — without this, the entire `RunningTodayView` body (planContent
/// VStack, all upper cards, the calendar wrapper, all sheets, all
/// `.animation` modifiers) gets walked on every publish even though
/// nothing relevant has changed.
///
/// Closures are deliberately excluded: each parent re-eval recreates them,
/// but they capture stable `Binding`s / function references so calling an
/// "old" closure still hits the right state. `todayRunningWorkouts` is
/// compared by `count` only — `WorkoutSummary` has a per-instance random
/// `id` so full-array equality would always be false.
extension RunningTodayView: Equatable {
    public static func == (lhs: RunningTodayView, rhs: RunningTodayView) -> Bool {
        lhs.plan?.id == rhs.plan?.id
            && lhs.isImperial == rhs.isImperial
            && lhs.embedded == rhs.embedded
            && lhs.planEmbedded == rhs.planEmbedded
            && lhs.isGenerating == rhs.isGenerating
            && lhs.todayRunningWorkouts.count == rhs.todayRunningWorkouts.count
    }
}

/// Default initializer for callers that don't supply `belowSessionContent`.
/// Matches the previous non-generic call shape so existing sites compile
/// unchanged.
extension RunningTodayView where BelowContent == EmptyView {
    init(
        plan: RunningPlan?,
        isImperial: Bool,
        onMarkComplete: @escaping (PlannedSession) -> Void,
        onSwitchToTab: @escaping (RunningHubView.HubTab) -> Void,
        onRunSelected: ((LoggedRun) -> Void)? = nil,
        onSessionTapped: ((PlannedSession) -> Void)? = nil,
        onClearPlan: (() -> Void)? = nil,
        embedded: Bool = false,
        planEmbedded: Bool = false,
        isGenerating: Bool = false,
        todayRunningWorkouts: [WorkoutSummary] = [],
        onLogUnplannedRun: ((WorkoutSummary?) -> Void)? = nil,
        onAutoLogSession: ((PlannedSession, WorkoutSummary) -> Void)? = nil
    ) {
        self.init(
            plan: plan,
            isImperial: isImperial,
            onMarkComplete: onMarkComplete,
            onSwitchToTab: onSwitchToTab,
            onRunSelected: onRunSelected,
            onSessionTapped: onSessionTapped,
            onClearPlan: onClearPlan,
            belowSessionContent: { EmptyView() },
            embedded: embedded,
            planEmbedded: planEmbedded,
            isGenerating: isGenerating,
            todayRunningWorkouts: todayRunningWorkouts,
            onLogUnplannedRun: onLogUnplannedRun,
            onAutoLogSession: onAutoLogSession
        )
    }
}

// MARK: - Fine-tune sheet

/// Custom sheet replacing the system confirmationDialog for the "Fine-tune
/// Plan" action. Matches the app's purple-accent / rounded-card design
/// language so it doesn't feel like a stock iOS prompt.
private struct FineTunePlanSheet: View {
    var onChoose: (AdaptationReason) -> Void
    var onCancel: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    private var primaryText: Color { Color("AppTextPrimary") }
    private var secondaryText: Color { Color("AppTextPrimary").opacity(0.9) }
    private var tertiaryText: Color { Color("AppTextPrimary").opacity(0.72) }

    var body: some View {
        VStack(spacing: 18) {
            header

            VStack(spacing: 10) {
                optionCard(
                    reason: .manualHarder,
                    icon: "bolt.fill",
                    accent: .runOrange,
                    title: "Push me harder",
                    subtitle: "Add intensity or volume to upcoming sessions"
                )
                optionCard(
                    reason: .manualEasier,
                    icon: "leaf.fill",
                    accent: .runDone,
                    title: "Make it easier",
                    subtitle: "Cut volume and ease back the next 1–2 weeks"
                )
                optionCard(
                    reason: .manual,
                    icon: "sparkles",
                    accent: .runAccent,
                    title: "Just refine it",
                    subtitle: "Smart tweaks based on your recent runs"
                )
            }
            .padding(.horizontal, 20)

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onCancel()
            } label: {
                Text("Cancel")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(tertiaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)

            Spacer(minLength: 0)
        }
        .padding(.top, 44)
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(Color.runAccent.opacity(0.15))
                    .frame(width: 56, height: 56)
                Image(systemName: "sparkles")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Color.runAccent)
            }
            Text("Fine-tune your plan")
                .font(.title3.weight(.bold))
                .foregroundStyle(primaryText)
            Text("We'll adjust upcoming sessions based on your recent runs. Past sessions stay the same.")
                .font(.subheadline)
                .foregroundStyle(secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Option card

    @ViewBuilder
    private func optionCard(
        reason: AdaptationReason,
        icon: String,
        accent: Color,
        title: String,
        subtitle: String
    ) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            onChoose(reason)
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(accent.opacity(0.18))
                        .frame(width: 40, height: 40)
                    Image(systemName: icon)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(accent)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(primaryText)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(secondaryText)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(tertiaryText)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(colorScheme == .dark
                          ? Color("AppCardBackground")
                          : Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(accent.opacity(0.25), lineWidth: 1)
                    )
                    .shadow(
                        color: .black.opacity(colorScheme == .dark ? 0 : 0.04),
                        radius: 4, y: 2
                    )
            )
        }
        .buttonStyle(PressableScaleStyle())
    }
}

/// Subtle press-down scale animation, matching how the app's primary CTAs feel.
private struct PressableScaleStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Clear plan confirmation sheet

/// Destructive-action confirmation sheet matching the app's design language.
/// Replaces the system confirmationDialog so the visual style stays consistent
/// with the Fine-tune sheet (rounded card, themed text, sparkle/trash hero).
private struct ClearPlanConfirmSheet: View {
    var onConfirm: () -> Void
    var onCancel: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    private var primaryText: Color { Color("AppTextPrimary") }
    private var secondaryText: Color { Color("AppTextPrimary").opacity(0.9) }
    private var tertiaryText: Color { Color("AppTextPrimary").opacity(0.72) }

    var body: some View {
        VStack(spacing: 18) {
            header

            VStack(spacing: 10) {
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    onConfirm()
                } label: {
                    Text("Clear Plan")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.runRed)
                        )
                }
                .buttonStyle(PressableScaleStyle())

                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onCancel()
                } label: {
                    Text("Cancel")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(tertiaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)

            Spacer(minLength: 0)
        }
        .padding(.top, 44)
    }

    private var header: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(Color.runRed.opacity(0.15))
                    .frame(width: 56, height: 56)
                Image(systemName: "trash.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Color.runRed)
            }
            Text("Clear running plan?")
                .font(.title3.weight(.bold))
                .foregroundStyle(primaryText)
            Text("This permanently deletes your current plan and all scheduled sessions. Your logged runs won't be affected.")
                .font(.subheadline)
                .foregroundStyle(secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Staggered slide-in animation

/// File-private duplicate of HealthRingsView's SlideIn modifier so the
/// today + plan tab cards stagger in with the same visual language as the
/// activity tabs. We can't share HealthRingsView's version (it's private to
/// that file), and lifting it module-wide collides with ReportsView's own
/// `slideIn` extension. Per-file copies keep each screen self-contained.
///
/// Observes `\.slideInGeneration` from the environment so the cards
/// re-animate when HealthRingsView increments the generation (e.g. on
/// tab activation). Without this, cards inside `belowSessionContent`
/// stayed static when the user re-entered the Activity tab — and the
/// first-mount animation could be suppressed when the parent view is
/// wrapped in `.equatable()` because internal `@State` changes weren't
/// being driven by an external trigger.
private struct RunningTodaySlideIn: ViewModifier {
    let delay: Double
    @Environment(\.slideInGeneration) private var generation
    @State private var visible = false

    func body(content: Content) -> some View {
        content
            .opacity(visible ? 1 : 0)
            .offset(y: visible ? 0 : 18)
            .onAppear {
                visible = false
                withAnimation(.spring(response: 0.5, dampingFraction: 0.82).delay(delay)) {
                    visible = true
                }
            }
            .onDisappear { visible = false }
            .onChange(of: generation) { _, _ in
                visible = false
                withAnimation(.spring(response: 0.5, dampingFraction: 0.82).delay(delay)) {
                    visible = true
                }
            }
    }
}

private extension View {
    func slideIn(delay: Double = 0) -> some View {
        modifier(RunningTodaySlideIn(delay: delay))
    }
}
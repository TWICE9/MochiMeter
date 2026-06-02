import SwiftUI
import SwiftData

/// Unified history of every run the user has logged in Yumo — both standalone
/// `LoggedRun` records and completed `PlannedSession`s from any training plan
/// (active or cleared). Sorted newest-first.
struct RunHistoryView: View {
    @StateObject private var service = FitnessService.shared
    @Query(sort: \RunningPlan.createdAt, order: .reverse) private var allPlans: [RunningPlan]

    @State private var isLoading = false
    @State private var selectedRunForDetail: LoggedRun? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    private var primaryTextColor: Color {
        colorScheme == .dark ? .white : Color(red: 32/255, green: 32/255, blue: 38/255)
    }

    private var secondaryTextColor: Color {
        colorScheme == .dark ? .white.opacity(0.7) : Color(red: 120/255, green: 120/255, blue: 130/255)
    }

    private var historyItems: [HistoryItem] {
        var items: [HistoryItem] = service.runs.map { .loggedRun($0) }

        // Index plans so each plan-session row can show "Week 4 of Marathon Plan".
        let planById: [UUID: RunningPlan] = Dictionary(uniqueKeysWithValues: allPlans.map { ($0.id, $0) })

        for plan in allPlans {
            for session in plan.sessions where session.isCompleted && session.sessionType.isRun {
                items.append(.planSession(session, planName: plan.name, planId: plan.id))
            }
        }
        // De-dupe: a logged-run row and a plan-session row may both refer to the same workout
        // (e.g. completing today's session also writes to logged_runs in some legacy flows).
        // Prefer the plan-session row when same-day + same-distance match within 5%.
        let runs = items.compactMap { item -> LoggedRun? in
            if case .loggedRun(let run) = item { return run } else { return nil }
        }
        items = items.filter { item in
            guard case .planSession(let session, _, _) = item else { return true }
            return !runs.contains { run in
                Calendar.current.isDate(run.runDate, inSameDayAs: session.completedAt ?? session.scheduledDate)
                    && abs(run.distanceKm - (session.completedDistanceKm ?? 0)) / max(0.1, run.distanceKm) < 0.05
            } || true // keep plan-session; logged-run will be filtered below
        }
        // Filter out logged-runs that have a matching plan-session entry to avoid showing both.
        let planSessionPairs: [(date: Date, distance: Double)] = items.compactMap {
            if case .planSession(let s, _, _) = $0 {
                return (s.completedAt ?? s.scheduledDate, s.completedDistanceKm ?? 0)
            }
            return nil
        }
        items = items.filter {
            if case .loggedRun(let run) = $0 {
                return !planSessionPairs.contains { pair in
                    Calendar.current.isDate(pair.date, inSameDayAs: run.runDate)
                        && pair.distance > 0 && abs(pair.distance - run.distanceKm) / max(0.1, run.distanceKm) < 0.05
                }
            }
            return true
        }
        _ = planById // silence unused if above changes
        return items.sorted { $0.date > $1.date }
    }

    var body: some View {
        ZStack {
            _buildDynamicBackground()

            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Run History")
                            .font(.largeTitle.bold())
                            .foregroundStyle(primaryTextColor)
                        Text(headerSubtitle)
                            .font(.caption)
                            .foregroundStyle(secondaryTextColor)
                    }
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(secondaryTextColor)
                            .padding(8)
                            .background(Circle().fill(secondaryTextColor.opacity(0.1)))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 16)

                if historyItems.isEmpty && !isLoading {
                    ContentUnavailableView(
                        "No Runs Yet",
                        systemImage: "figure.run",
                        description: Text("Logged runs and completed plan sessions will appear here.")
                    )
                    Spacer()
                } else {
                    List {
                        if isLoading {
                            ForEach(0..<6, id: \.self) { _ in
                                RunHistorySkeletonRow()
                                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                                    .listRowSeparator(.hidden)
                                    .listRowBackground(Color.clear)
                            }
                        } else {
                            ForEach(historyItems) { item in
                                Button {
                                    selectedRunForDetail = item.asLoggedRun()
                                } label: {
                                    HistoryRow(item: item)
                                }
                                .buttonStyle(.plain)
                                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                            }
                            .onDelete(perform: deleteItems)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $selectedRunForDetail) { run in
            RunDetailView(run: run)
                .presentationDragIndicator(.visible)
        }
        .task {
            if service.runs.isEmpty { isLoading = true }
            await service.fetchRuns()
            withAnimation { isLoading = false }
        }
    }

    private var headerSubtitle: String {
        let count = historyItems.count
        if count == 0 { return "No runs yet" }
        let totalKm = historyItems.reduce(0.0) { $0 + $1.distanceKm }
        return "\(count) run\(count == 1 ? "" : "s") · \(String(format: "%.1f", totalKm)) km total"
    }

    private func deleteItems(at offsets: IndexSet) {
        for index in offsets {
            guard index < historyItems.count else { continue }
            // Only LoggedRun rows are deletable from history (plan sessions are tied
            // to a plan and should be edited from the plan UI).
            if case .loggedRun(let run) = historyItems[index], let id = run.id {
                Task { try? await service.deleteRun(id) }
            }
        }
    }

    @ViewBuilder
    private func _buildDynamicBackground() -> some View {
        ZStack {
            Color("AppPrimaryDark").ignoresSafeArea()
            GeometryReader { proxy in
                ZStack {
                    Circle()
                        .fill(Color("AppSecondaryAccent").opacity(0.1))
                        .frame(width: proxy.size.width * 0.8)
                        .blur(radius: 80)
                        .offset(x: -proxy.size.width * 0.2, y: -proxy.size.height * 0.2)
                    Circle()
                        .fill(Color("AppPrimaryAccent").opacity(0.08))
                        .frame(width: proxy.size.width * 0.8)
                        .blur(radius: 80)
                        .offset(x: proxy.size.width * 0.2, y: proxy.size.height * 0.2)
                }
            }
            .ignoresSafeArea()
        }
    }
}

// MARK: - History item

enum HistoryItem: Identifiable {
    case loggedRun(LoggedRun)
    case planSession(PlannedSession, planName: String, planId: UUID)

    var id: AnyHashable {
        switch self {
        case .loggedRun(let run): return run.id ?? UUID()
        case .planSession(let s, _, _): return s.id
        }
    }

    var date: Date {
        switch self {
        case .loggedRun(let run): return run.runDate
        case .planSession(let s, _, _): return s.completedAt ?? s.scheduledDate
        }
    }

    var distanceKm: Double {
        switch self {
        case .loggedRun(let run): return run.distanceKm
        case .planSession(let s, _, _):
            return s.completedDistanceKm ?? s.targetDistanceKm ?? 0
        }
    }

    /// Convert to a `LoggedRun` so `RunDetailView` can render either case uniformly.
    func asLoggedRun() -> LoggedRun {
        switch self {
        case .loggedRun(let run):
            return run
        case .planSession(let s, let planName, _):
            let dist = s.completedDistanceKm ?? s.targetDistanceKm ?? 0
            let dur = Double(s.completedDurationMinutes ?? s.targetDurationMinutes ?? 0)
            var pace: String? = nil
            if dist > 0, dur > 0 {
                let secs = (dur * 60) / dist
                pace = String(format: "%d:%02d", Int(secs) / 60, Int(secs) % 60)
            }
            return LoggedRun(
                id: s.id,
                runDate: s.completedAt ?? s.scheduledDate,
                distanceKm: dist,
                durationMinutes: dur,
                calories: nil,
                avgPace: pace,
                avgHeartRate: nil,
                elevationGain: nil,
                feedback: "\(s.sessionType.displayLabel) · Week \(s.weekNumber) of \(planName)\n\n\(s.sessionDescription)"
            )
        }
    }
}

// MARK: - Row

struct HistoryRow: View {
    let item: HistoryItem

    private var iconName: String {
        switch item {
        case .loggedRun: return "figure.run"
        case .planSession(let s, _, _):
            switch s.sessionType {
            case .easy, .recovery: return "figure.run"
            case .long:            return "arrow.up.right"
            case .tempo:           return "flame.fill"
            case .intervals:       return "bolt.fill"
            case .race:            return "flag.checkered"
            default:               return "figure.run"
            }
        }
    }

    private var iconTint: Color {
        switch item {
        case .loggedRun: return .blue
        case .planSession(let s, _, _):
            switch s.sessionType {
            case .easy, .recovery: return .green
            case .long:            return .blue
            case .tempo:           return .orange
            case .intervals:       return .red
            case .race:            return .purple
            default:               return .blue
            }
        }
    }

    private var typeLabel: String {
        switch item {
        case .loggedRun: return "Logged Run"
        case .planSession(let s, _, _): return s.sessionType.displayLabel
        }
    }

    private var planLabel: String? {
        if case .planSession(let s, let planName, _) = item {
            return "Week \(s.weekNumber) · \(planName)"
        }
        return nil
    }

    private var pace: String? {
        switch item {
        case .loggedRun(let run): return run.avgPace
        case .planSession(let s, _, _):
            let dist = s.completedDistanceKm ?? 0
            let dur = Double(s.completedDurationMinutes ?? 0)
            guard dist > 0, dur > 0 else { return nil }
            let secs = (dur * 60) / dist
            return String(format: "%d:%02d", Int(secs) / 60, Int(secs) % 60)
        }
    }

    private var durationMin: Double {
        switch item {
        case .loggedRun(let run): return run.durationMinutes
        case .planSession(let s, _, _):
            return Double(s.completedDurationMinutes ?? s.targetDurationMinutes ?? 0)
        }
    }

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [iconTint.opacity(0.25), iconTint.opacity(0.10)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 54, height: 54)
                Image(systemName: iconName)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(iconTint)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(typeLabel)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    if let plan = planLabel {
                        Text("·")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(plan)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Text(item.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 14) {
                    HStack(spacing: 4) {
                        Image(systemName: "map.fill").font(.caption2).foregroundStyle(.blue)
                        Text(String(format: "%.2f km", item.distanceKm))
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(.primary)
                    }
                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill").font(.caption2).foregroundStyle(.orange)
                        Text(String(format: "%.0f min", durationMin))
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(.primary)
                    }
                }
            }

            Spacer()

            if let pace {
                VStack(spacing: 2) {
                    Text(pace)
                        .font(.callout.weight(.bold))
                        .foregroundStyle(.primary)
                    Text("/km")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial)
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(.secondary.opacity(0.15), lineWidth: 1)
                )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    LinearGradient(
                        colors: [.primary.opacity(0.1), .primary.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }
}

// MARK: - Skeleton

struct RunHistorySkeletonRow: View {
    @State private var isAnimating = false

    var body: some View {
        HStack(spacing: 16) {
            Circle()
                .fill(Color.primary.opacity(0.05))
                .frame(width: 54, height: 54)

            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.primary.opacity(0.05))
                    .frame(width: 100, height: 12)
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.primary.opacity(0.05))
                        .frame(width: 60, height: 16)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.primary.opacity(0.05))
                        .frame(width: 60, height: 16)
                }
            }
            Spacer()
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.primary.opacity(0.05))
                .frame(width: 60, height: 32)
        }
        .padding(16)
        .background(Color.primary.opacity(0.02))
        .cornerRadius(20)
        .opacity(isAnimating ? 0.6 : 1.0)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }
}

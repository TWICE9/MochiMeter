// Components/WeeklyMileageHistoryChart.swift

import SwiftUI
import Charts

/// Inline card that loads up to 52 weeks of mileage and renders the interactive
/// chart with a range picker. Used inside ReportsView.
struct WeeklyMileageHistoryCard: View {
    let isImperial: Bool

    @Environment(\.colorScheme) private var colorScheme
    @State private var allBuckets: [HealthKitManager.WeeklyMileageBucket] = []
    @State private var hasLoaded = false
    @State private var range: MileageRange = .sixMonths

    private var visibleBuckets: [HealthKitManager.WeeklyMileageBucket] {
        let count = min(range.weeksBack, allBuckets.count)
        return Array(allBuckets.suffix(count))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(LinearGradient(colors: [Color("AppSecondaryAccent"), Color("AppPrimaryAccent")], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 36, height: 36)
                    Image(systemName: "figure.run")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Weekly Mileage")
                        .font(.headline)
                        .foregroundStyle(colorScheme == .dark ? .white : .black)
                    Text("Tap a bar for that week")
                        .font(.caption2)
                        .foregroundStyle(colorScheme == .dark ? .white.opacity(0.6) : Color(white: 0.4))
                }
                Spacer()
            }

            rangePicker

            if !hasLoaded {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 60)
            } else if visibleBuckets.allSatisfy({ $0.km <= 0 }) {
                Text("No runs in this range")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
            } else {
                WeeklyMileageHistoryChart(buckets: visibleBuckets, isImperial: isImperial)
                    .id(range)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color("AppCardBackground"))
        )
        .task {
            allBuckets = await HealthKitManager.shared.fetchWeeklyMileageHistory(weeksBack: 52)
            hasLoaded = true
        }
    }

    private var rangePicker: some View {
        HStack(spacing: 6) {
            ForEach(MileageRange.allCases) { option in
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.easeInOut(duration: 0.2)) {
                        range = option
                    }
                } label: {
                    Text(option.rawValue)
                        .font(.system(size: 11, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(range == option
                                      ? Color("AppSecondaryAccent")
                                      : (colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.05)))
                        )
                        .foregroundStyle(
                            range == option
                            ? .white
                            : (colorScheme == .dark ? .white.opacity(0.7) : .black)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// Time range that the chart can display.
enum MileageRange: String, CaseIterable, Identifiable {
    case oneMonth = "1M"
    case threeMonths = "3M"
    case sixMonths = "6M"
    case ytd = "YTD"
    case oneYear = "1Y"

    var id: String { rawValue }

    /// Number of weeks to render. YTD is computed dynamically from `Date()`.
    var weeksBack: Int {
        switch self {
        case .oneMonth: return 5
        case .threeMonths: return 13
        case .sixMonths: return 26
        case .oneYear: return 52
        case .ytd:
            var cal = Calendar(identifier: .iso8601)
            cal.firstWeekday = 2
            let now = Date()
            let comps = cal.dateComponents([.year], from: now)
            guard let yearStart = cal.date(from: comps),
                  let yearStartWeek = cal.dateInterval(of: .weekOfYear, for: yearStart)?.start,
                  let currentWeek = cal.dateInterval(of: .weekOfYear, for: now)?.start else { return 26 }
            let weeks = cal.dateComponents([.weekOfYear], from: yearStartWeek, to: currentWeek).weekOfYear ?? 26
            return max(weeks + 1, 1)
        }
    }
}

/// Strava-style interactive weekly mileage chart. Tap or drag across the bars
/// to inspect a specific week — the selected bar highlights and the summary
/// above swaps to that week's stats.
struct WeeklyMileageHistoryChart: View {
    let buckets: [HealthKitManager.WeeklyMileageBucket]
    let isImperial: Bool
    /// Optional explicit chart height. Defaults to 180.
    var chartHeight: CGFloat = 180

    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedWeekStart: Date? = nil

    private var unitLabel: String { isImperial ? "mi" : "km" }
    private func display(_ km: Double) -> Double { isImperial ? km * 0.621371 : km }

    private var totalKm: Double { buckets.reduce(0) { $0 + $1.km } }
    private var avgKm: Double {
        let active = buckets.filter { $0.km > 0 }
        guard !active.isEmpty else { return 0 }
        return active.reduce(0) { $0 + $1.km } / Double(active.count)
    }
    private var maxKm: Double { buckets.map(\.km).max() ?? 0 }

    private var selectedBucket: HealthKitManager.WeeklyMileageBucket? {
        guard let start = selectedWeekStart else { return nil }
        return buckets.first { $0.weekStart == start }
    }

    private var primary: Color { colorScheme == .dark ? .white : .black }
    private var muted: Color { colorScheme == .dark ? .white.opacity(0.6) : Color(white: 0.4) }
    private var trackColor: Color { colorScheme == .dark ? .white.opacity(0.08) : .black.opacity(0.06) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            summaryHeader
            chart
            footerStats
        }
    }

    // MARK: - Header

    private var summaryHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let b = selectedBucket {
                Text(weekRangeLabel(for: b.weekStart))
                    .font(.caption)
                    .foregroundStyle(muted)
                Text(String(format: "%.1f \(unitLabel)", display(b.km)))
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundStyle(primary)
                    .contentTransition(.numericText())
            } else {
                Text("Last \(buckets.count) weeks")
                    .font(.caption)
                    .foregroundStyle(muted)
                Text(String(format: "%.0f \(unitLabel) total", display(totalKm)))
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundStyle(primary)
            }
        }
        .animation(.easeOut(duration: 0.2), value: selectedWeekStart)
    }

    // MARK: - Chart

    private var chart: some View {
        Chart {
            ForEach(buckets) { bucket in
                BarMark(
                    x: .value("Week", bucket.weekStart, unit: .weekOfYear),
                    y: .value("Distance", display(bucket.km))
                )
                .foregroundStyle(barColor(for: bucket))
                .cornerRadius(4)
            }
            if let b = selectedBucket {
                RuleMark(x: .value("Week", b.weekStart, unit: .weekOfYear))
                    .foregroundStyle(Color("AppSecondaryAccent").opacity(0.4))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
                AxisGridLine().foregroundStyle(trackColor)
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text("\(Int(v))")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(muted)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .month)) { value in
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(date, format: .dateTime.month(.abbreviated))
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(muted)
                    }
                }
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geo in
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                handleSelection(at: value.location, proxy: proxy, geo: geo)
                            }
                            .onEnded { _ in
                                // Keep selection on lift so user can read the
                                // value comfortably; tap elsewhere to clear.
                            }
                    )
                    .onTapGesture(count: 2) {
                        selectedWeekStart = nil
                    }
            }
        }
        .frame(height: chartHeight)
    }

    private func barColor(for bucket: HealthKitManager.WeeklyMileageBucket) -> Color {
        let isSelected = selectedWeekStart == bucket.weekStart
        if isSelected {
            return Color("AppSecondaryAccent")
        }
        if bucket.km <= 0 {
            return trackColor
        }
        // Heat-map style: more saturated for higher mileage weeks.
        let intensity = maxKm > 0 ? (bucket.km / maxKm) : 0
        return Color("AppSecondaryAccent").opacity(0.35 + intensity * 0.55)
    }

    private func handleSelection(at point: CGPoint, proxy: ChartProxy, geo: GeometryProxy) {
        guard let plotFrame = proxy.plotFrame else { return }
        let frame = geo[plotFrame]
        let x = point.x - frame.origin.x
        guard x >= 0, x <= frame.width else { return }
        guard let date: Date = proxy.value(atX: x) else { return }
        // Snap to the bucket whose weekStart is closest.
        let nearest = buckets.min(by: {
            abs($0.weekStart.timeIntervalSince(date)) < abs($1.weekStart.timeIntervalSince(date))
        })
        if let n = nearest, selectedWeekStart != n.weekStart {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        selectedWeekStart = nearest?.weekStart
    }

    // MARK: - Footer

    private var footerStats: some View {
        HStack(spacing: 24) {
            stat("Avg / week", String(format: "%.1f \(unitLabel)", display(avgKm)))
            stat("Best week", String(format: "%.1f \(unitLabel)", display(maxKm)))
            stat("Total", String(format: "%.0f \(unitLabel)", display(totalKm)))
        }
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.system(size: 10, weight: .medium)).foregroundStyle(muted)
            Text(value).font(.system(size: 13, weight: .semibold)).foregroundStyle(primary)
        }
    }

    // MARK: - Helpers

    private func weekRangeLabel(for start: Date) -> String {
        let cal = Calendar.current
        let end = cal.date(byAdding: .day, value: 6, to: start) ?? start
        let f = DateFormatter()
        f.dateFormat = "d MMM"
        return "\(f.string(from: start)) – \(f.string(from: end))"
    }
}

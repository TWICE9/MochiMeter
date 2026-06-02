// Yumo/Screens/Running/SessionDetailView.swift

import SwiftUI

struct SessionDetailView: View {
    let session: PlannedSession
    let isImperial: Bool
    var onMarkComplete: (PlannedSession) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    /// Cached `TypeInfo` for this session. The original computed `info`
    /// returned a fresh `TypeInfo` (with arrays of strings) on every access,
    /// and was read 5+ times per body re-evaluation. Now built once when the
    /// session changes, then read for free from state.
    @State private var cachedInfo: TypeInfo = .placeholder

    private var tint: Color {
        switch session.sessionType {
        case .easy, .recovery: return .green
        case .long:            return .blue
        case .tempo:           return .orange
        case .intervals:       return .red
        case .race:            return .purple
        case .cross:           return .cyan
        case .rest:            return Color.gray
        }
    }

    private var icon: String {
        switch session.sessionType {
        case .easy, .recovery: return "figure.run"
        case .long:            return "figure.run.circle.fill"
        case .tempo:           return "flame.fill"
        case .intervals:       return "bolt.fill"
        case .race:            return "flag.checkered"
        case .cross:           return "bicycle"
        case .rest:            return "moon.zzz.fill"
        }
    }

    private var primaryText: Color   { Color("AppTextPrimary") }
    private var secondaryText: Color { Color("AppTextPrimary").opacity(0.7) }
    private var tertiaryText: Color  { Color("AppTextPrimary").opacity(0.45) }

    private var unitLabel: String { isImperial ? "mi" : "km" }

    private func formatDist(_ km: Double) -> String {
        let val = isImperial ? km * 0.621371 : km
        return String(format: "%.1f \(unitLabel)", val)
    }

    private func formatPace(_ secPerKm: Int) -> String {
        if isImperial {
            let secPerMi = Int(Double(secPerKm) * 1.60934)
            return String(format: "%d:%02d /mi", secPerMi / 60, secPerMi % 60)
        }
        return String(format: "%d:%02d /km", secPerKm / 60, secPerKm % 60)
    }

    var body: some View {
        ZStack {
            Color("AppBackground").ignoresSafeArea()

            ScrollView(.vertical) {
                VStack(spacing: 20) {
                    heroHeader

                    // Log-this-session moved up so the primary action sits
                    // immediately under the hero — users no longer have to
                    // scroll past the educational content to log a run.
                    if session.sessionType.isRun {
                        logButton
                    }

                    if session.sessionType == .rest {
                        restCard
                    } else {
                        whatIsThisCard
                        effortCard
                        heartRateZoneCard
                        warmupCard
                        cooldownCard
                    }

                    if !session.sessionDescription.isEmpty {
                        planDescriptionCard
                    }

                    if let notes = session.notes, !notes.isEmpty {
                        notesCard(notes)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
                // Force the content width to exactly match the
                // ScrollView's container width. This is the hard clamp:
                // no matter what intrinsic width any child reports
                // (text with unbreakable content, drawingGroup texture
                // overshoot, anything), the content is sized to the
                // container and can't trigger horizontal bounce.
                .containerRelativeFrame(.horizontal)
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
        }
        .navigationTitle(session.sessionType.displayLabel)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }
                    .fontWeight(.semibold)
                    .foregroundStyle(tint)
            }
        }
        .onAppear {
            // Build the `TypeInfo` once. `task(id:)` would also work but the
            // session value is fixed for the lifetime of this view.
            if cachedInfo.description.isEmpty {
                cachedInfo = Self.makeInfo(for: session.sessionType)
            }
        }
    }

    /// Bridge so existing card views can read `info` unchanged. Reads from
    /// the populated state in O(1).
    private var info: TypeInfo { cachedInfo }

    // MARK: - Hero Header

    private var heroHeader: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(LinearGradient(
                    colors: [tint.opacity(0.18), tint.opacity(0.06)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))

            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(tint.opacity(0.3), lineWidth: 1.5)

            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(tint.opacity(0.2))
                        .frame(width: 80, height: 80)
                    Image(systemName: icon)
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(tint)
                }

                VStack(spacing: 6) {
                    Text(session.sessionType.displayLabel)
                        .font(.title.weight(.bold))
                        .foregroundStyle(primaryText)

                    HStack(spacing: 8) {
                        Text(session.scheduledDate, format: .dateTime.weekday(.wide).month(.abbreviated).day())
                            .font(.subheadline)
                            .foregroundStyle(tertiaryText)
                        Text("·")
                            .foregroundStyle(tertiaryText)
                        Text("Week \(session.weekNumber)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(tint)
                    }
                }

                let hasMetrics = (session.targetDistanceKm ?? 0) > 0
                    || (session.targetDurationMinutes ?? 0) > 0
                    || (session.targetPaceSecondsPerKm ?? 0) > 0
                if hasMetrics {
                    HStack(spacing: 10) {
                        if let km = session.targetDistanceKm, km > 0 {
                            metricPill(label: "Distance", value: formatDist(km))
                        }
                        if let mins = session.targetDurationMinutes, mins > 0 {
                            metricPill(label: "Duration", value: "\(mins) min")
                        }
                        if let pace = session.targetPaceSecondsPerKm, pace > 0 {
                            metricPill(label: "Target Pace", value: formatPace(pace))
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity)
        .shadow(color: tint.opacity(0.18), radius: 16, x: 0, y: 6)
    }

    private func metricPill(label: String, value: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.caption2)
                .foregroundStyle(tertiaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 12).fill(tint.opacity(0.1)))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(tint.opacity(0.2), lineWidth: 1))
    }

    // MARK: - What Is This

    private var whatIsThisCard: some View {
        sectionCard(icon: "info.circle.fill", title: "What is a \(session.sessionType.displayLabel)?", tint: tint) {
            Text(info.description)
                .font(.subheadline)
                .foregroundStyle(secondaryText)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Effort

    private var effortCard: some View {
        sectionCard(icon: "gauge.medium", title: "Effort Level (RPE)", tint: tint) {
            VStack(alignment: .leading, spacing: 12) {
                // 10 RPE indicators sized proportionally to available width
                // (capped at 24pt so they don't get oversized on iPad). The
                // previous fixed `.frame(width: 24, height: 24)` × 10
                // circles needed 276pt total — wider than the inner card
                // width on small phones (iPhone SE), which leaked into the
                // parent ScrollView's content size and let the screen pan
                // sideways.
                HStack(spacing: 4) {
                    ForEach(1...10, id: \.self) { i in
                        let active = i >= info.rpeRange.lowerBound && i <= info.rpeRange.upperBound
                        Circle()
                            .fill(active ? tint : tint.opacity(0.13))
                            .frame(maxWidth: 24)
                            .aspectRatio(1, contentMode: .fit)
                            .overlay(
                                Text("\(i)")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(active ? .white : tertiaryText)
                            )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "quote.bubble.fill")
                        .font(.caption)
                        .foregroundStyle(tint)
                        .padding(.top, 1)
                    Text(info.rpeLabel)
                        .font(.subheadline)
                        .foregroundStyle(secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    // MARK: - Heart Rate Zones

    private var heartRateZoneCard: some View {
        let zones: [(name: String, color: Color, range: String)] = [
            ("Z1", .blue,   "50–60%"),
            ("Z2", .green,  "61–70%"),
            ("Z3", .yellow, "71–80%"),
            ("Z4", .orange, "81–90%"),
            ("Z5", .red,    "91–100%"),
        ]
        return sectionCard(icon: "heart.fill", title: "Heart Rate Zones", tint: tint) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 4) {
                    ForEach(0..<5, id: \.self) { i in
                        let isTarget = info.targetHRZones.contains(i + 1)
                        RoundedRectangle(cornerRadius: 7)
                            .fill(isTarget ? zones[i].color : zones[i].color.opacity(0.18))
                            .frame(height: 30)
                            .scaleEffect(y: isTarget ? 1.12 : 1.0, anchor: .bottom)
                            .overlay(
                                Text(zones[i].name)
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(isTarget ? .white : tertiaryText)
                            )
                    }
                }

                Text(info.hrZoneLabel)
                    .font(.subheadline)
                    .foregroundStyle(secondaryText)

                HStack(spacing: 0) {
                    ForEach(0..<5, id: \.self) { i in
                        VStack(spacing: 3) {
                            Circle()
                                .fill(zones[i].color.opacity(0.7))
                                .frame(width: 7, height: 7)
                            Text(zones[i].range)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(tertiaryText)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }

    // MARK: - Warm-Up

    private var warmupCard: some View {
        sectionCard(icon: "sun.horizon.fill", title: "Warm-Up", tint: .orange) {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(info.warmupSteps.enumerated()), id: \.offset) { i, step in
                    HStack(alignment: .top, spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.orange.opacity(0.15))
                                .frame(width: 26, height: 26)
                            Text("\(i + 1)")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.orange)
                        }
                        Text(step)
                            .font(.subheadline)
                            .foregroundStyle(secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer()
                    }
                }
            }
        }
    }

    // MARK: - Cool-Down

    private var cooldownCard: some View {
        sectionCard(icon: "snowflake", title: "Cool-Down", tint: .blue) {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(info.cooldownSteps.enumerated()), id: \.offset) { i, step in
                    HStack(alignment: .top, spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.blue.opacity(0.12))
                                .frame(width: 26, height: 26)
                            Text("\(i + 1)")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.blue)
                        }
                        Text(step)
                            .font(.subheadline)
                            .foregroundStyle(secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer()
                    }
                }
            }
        }
    }

    // MARK: - Plan Description

    private var planDescriptionCard: some View {
        sectionCard(icon: "sparkles", title: "Coach's Notes", tint: .purple) {
            Text(session.sessionDescription)
                .font(.subheadline)
                .foregroundStyle(secondaryText)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func notesCard(_ notes: String) -> some View {
        sectionCard(icon: "note.text", title: "Session Notes", tint: Color.gray) {
            Text(notes)
                .font(.subheadline)
                .foregroundStyle(secondaryText)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Rest Card

    private var restCard: some View {
        sectionCard(icon: "moon.zzz.fill", title: "Rest Day", tint: Color.gray) {
            Text("Rest days are where adaptation happens. Your body uses rest to rebuild muscle fibres, replenish glycogen stores, and absorb the training load from the week. Skipping rest often leads to injury — protect this day.")
                .font(.subheadline)
                .foregroundStyle(secondaryText)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Log Button

    private var logButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            dismiss()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                onMarkComplete(session)
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: session.isCompleted ? "arrow.uturn.backward.circle" : "checkmark.circle.fill")
                Text(session.isCompleted ? "Logged · Tap to Update" : "Log This Session")
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(session.isCompleted ? Color.green.opacity(0.2) : tint)
            .foregroundStyle(session.isCompleted ? Color.green : .white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Section Card Builder

    private func sectionCard<Content: View>(
        icon: String,
        title: String,
        tint: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(tint)
                    .font(.subheadline.weight(.semibold))
                Text(title)
                    .font(.headline)
                    .foregroundStyle(primaryText)
            }
            content()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(colorScheme == .dark
                      ? Color(UIColor.secondarySystemGroupedBackground)
                      : .white)
        )
        // `.drawingGroup()` BEFORE shadow so the rasterized texture is
        // confined to the card's layout-reported size. Putting shadow
        // inside the drawingGroup let the rasterized texture include
        // the shadow extension, which could leak past the card's
        // reported frame and into the parent ScrollView's content
        // width — letting it pan horizontally. Shadow applied AFTER is
        // its own cheap single offscreen pass on the flat texture.
        // See PERF NOTE at top of `RunningTodayView.swift` for the
        // full investigation that landed `.drawingGroup()` here.
        .drawingGroup()
        .shadow(color: .black.opacity(colorScheme == .dark ? 0 : 0.05), radius: 8, y: 3)
    }

    // MARK: - Static Content

    private struct TypeInfo {
        let description: String
        let rpeRange: ClosedRange<Int>
        let rpeLabel: String
        let targetHRZones: [Int]
        let hrZoneLabel: String
        let warmupSteps: [String]
        let cooldownSteps: [String]

        static let placeholder = TypeInfo(
            description: "",
            rpeRange: 1...1,
            rpeLabel: "",
            targetHRZones: [],
            hrZoneLabel: "",
            warmupSteps: [],
            cooldownSteps: []
        )
    }

    private static func makeInfo(for type: RunningSessionType) -> TypeInfo {
        switch type {

        case .easy:
            return TypeInfo(
                description: "An easy run is a comfortable, aerobic-paced workout where you can hold a full conversation throughout. It builds your aerobic base and helps your body recover between harder sessions. Most of your weekly mileage should feel exactly like this.",
                rpeRange: 4...5,
                rpeLabel: "Fully conversational — you should be able to speak in complete sentences the whole way.",
                targetHRZones: [2],
                hrZoneLabel: "Zone 2 (61–70% max HR) — fat-burning, aerobic base building zone.",
                warmupSteps: [
                    "3 min brisk walk",
                    "5 min very easy jog (slower than target pace)",
                    "10× leg swings per leg — front-back then side-to-side",
                    "5× hip circles each direction",
                ],
                cooldownSteps: [
                    "3 min easy jog, then 2 min walk",
                    "30 sec quad stretch each leg",
                    "30 sec hamstring stretch each leg",
                    "30 sec calf stretch each leg",
                ]
            )

        case .long:
            return TypeInfo(
                description: "The long run is the cornerstone of any endurance training plan. It builds aerobic endurance, trains your body to burn fat efficiently, and develops the mental toughness needed for race day. Run at a fully conversational easy pace — this is not a race.",
                rpeRange: 5...6,
                rpeLabel: "Comfortable and conversational the entire way. If you can't speak in sentences, you're going too fast.",
                targetHRZones: [2],
                hrZoneLabel: "Zone 2 (61–70% max HR) — aim to stay here for the full duration.",
                warmupSteps: [
                    "5 min brisk walk",
                    "10 min very easy jog",
                    "8× leg swings per leg",
                    "30 sec hip flexor stretch each side",
                    "10× ankle rolls each direction",
                ],
                cooldownSteps: [
                    "5 min easy jog, then 3 min walk",
                    "60 sec quad stretch each leg",
                    "60 sec hamstring stretch each leg",
                    "30 sec calf stretch each leg",
                    "30 sec hip flexor stretch each side",
                    "Foam roll quads and IT bands if available",
                ]
            )

        case .tempo:
            return TypeInfo(
                description: "A tempo run is run at your lactate threshold — the pace you could sustain for roughly an hour all-out. It feels 'comfortably hard': you can say a few words but not hold a full conversation. It's one of the most effective sessions for improving race pace.",
                rpeRange: 7...8,
                rpeLabel: "Comfortably hard — a few words at a time, not full sentences.",
                targetHRZones: [3, 4],
                hrZoneLabel: "Zone 3–4 (71–90% max HR) — lactate threshold territory.",
                warmupSteps: [
                    "10 min easy jog",
                    "4× 20-second strides building toward tempo pace",
                    "8× leg swings per leg",
                    "30 sec dynamic hip circles each side",
                ],
                cooldownSteps: [
                    "10 min easy jog",
                    "3 min walk",
                    "Full lower body static stretching (60 sec per muscle group)",
                ]
            )

        case .intervals:
            return TypeInfo(
                description: "Interval sessions alternate between short, hard efforts and intentional recovery periods. They push your VO₂ max (your body's oxygen ceiling), build speed, and improve running economy. The hard portions should feel very difficult — the recovery between efforts is not optional.",
                rpeRange: 9...10,
                rpeLabel: "9–10/10 during efforts. Drop to 4/10 during recovery — genuinely easy.",
                targetHRZones: [4, 5],
                hrZoneLabel: "Zone 4–5 (81–100% max HR) during work efforts.",
                warmupSteps: [
                    "15 min easy jog",
                    "4× 20-second strides building toward interval pace",
                    "30 sec high knees",
                    "30 sec butt kicks",
                    "Dynamic leg swings and hip openers",
                ],
                cooldownSteps: [
                    "10–15 min easy jog",
                    "3 min walk",
                    "Full lower body static stretching",
                ]
            )

        case .recovery:
            return TypeInfo(
                description: "A recovery run is genuinely easy — easier than it feels like it should be. It promotes blood flow to tired muscles, speeds up recovery, and keeps your legs active without adding training stress. If it feels too easy, that means you're doing it right.",
                rpeRange: 3...4,
                rpeLabel: "Truly conversational — almost embarrassingly slow. That's the point.",
                targetHRZones: [1, 2],
                hrZoneLabel: "Zone 1–2 (50–70% max HR) — blood flow, not training stress.",
                warmupSteps: [
                    "2 min walk",
                    "Ease into a very gentle jog — no rush, no target pace",
                ],
                cooldownSteps: [
                    "2 min walk",
                    "Light quad and hamstring stretches (30 sec each)",
                ]
            )

        case .race:
            return TypeInfo(
                description: "Today is race day. All your training has prepared you for this. Start conservatively — resist the crowd energy in the first kilometre — run the first half at goal pace, and build your effort in the second half. Trust your training and your plan.",
                rpeRange: 8...10,
                rpeLabel: "7/10 first half → 8–9/10 second half → 10/10 final push.",
                targetHRZones: [4, 5],
                hrZoneLabel: "Zone 4 (first half) → Zone 5 (second half).",
                warmupSteps: [
                    "10–15 min easy jog (for 10K or shorter distances)",
                    "4× strides at goal race pace",
                    "Dynamic drills: leg swings, high knees, butt kicks",
                    "Arrive at the start line at least 10 min before gun",
                ],
                cooldownSteps: [
                    "10 min easy walk or jog",
                    "Thorough lower body stretching",
                    "Hydrate and refuel within 30 minutes of finishing",
                ]
            )

        case .cross:
            return TypeInfo(
                description: "Cross training maintains your cardiovascular fitness while giving your running muscles a break. Cycling, swimming, the elliptical, or strength work all count. It keeps your aerobic engine running without the impact stress of another run day.",
                rpeRange: 5...6,
                rpeLabel: "Moderate effort — conversational but not effortless.",
                targetHRZones: [2, 3],
                hrZoneLabel: "Zone 2–3 (61–80% max HR) — aerobic maintenance.",
                warmupSteps: [
                    "5 min easy effort at your chosen activity",
                    "Gradually build to working pace over 3–5 min",
                ],
                cooldownSteps: [
                    "5 min easy effort",
                    "Light stretching relevant to your chosen activity",
                ]
            )

        case .rest:
            return TypeInfo(
                description: "Rest days are where adaptation happens.",
                rpeRange: 0...0,
                rpeLabel: "",
                targetHRZones: [],
                hrZoneLabel: "",
                warmupSteps: [],
                cooldownSteps: []
            )
        }
    }
}

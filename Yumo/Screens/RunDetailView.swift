import SwiftUI
import MapKit
import Charts

struct RunDetailView: View {
    let run: LoggedRun
    let hkWorkoutUUID: UUID?

    init(run: LoggedRun, hkWorkoutUUID: UUID? = nil) {
        self.run = run
        self.hkWorkoutUUID = hkWorkoutUUID
        self._avgHR = State(initialValue: run.avgHeartRate)
        self._elevGain = State(initialValue: run.elevationGain)
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var routeCoordinates: [CLLocationCoordinate2D] = []
    @State private var avgHR: Int?
    @State private var elevGain: Int?
    @State private var analytics: RunAnalytics?

    // MARK: - Chart selection state
    // Each chart has its own X-axis "scrub" state so dragging on one chart
    // doesn't move the indicator on another. X is distance in km for pace
    // and elevation, elapsed minutes for heart-rate and cadence.
    @State private var selectedPaceX: Double?
    @State private var selectedHRX: Double?
    @State private var selectedCadenceX: Double?
    @State private var selectedElevationX: Double?

    // MARK: - Share state
    @State private var isPreparingShare = false
    @State private var showCopiedToast = false
    @State private var cameraPosition: MapCameraPosition = .region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: -27.4698, longitude: 153.0251),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    ))

    // MARK: - Adaptive colours
    // The whole view used to be hard-coded dark; these helpers swap in light
    // equivalents so the screen reads correctly in either scheme. Keep the
    // dark values identical to the previous palette so the dark-mode look
    // doesn't change.
    private var pageBackground: Color {
        colorScheme == .dark
            ? Color(red: 18/255, green: 18/255, blue: 20/255)
            : Color(red: 248/255, green: 248/255, blue: 250/255)
    }
    private var cardBackground: Color {
        colorScheme == .dark
            ? Color(red: 0.12, green: 0.14, blue: 0.16)
            : Color.white
    }
    private var primaryText: Color {
        colorScheme == .dark ? .white : Color(red: 0.10, green: 0.10, blue: 0.12)
    }
    private var secondaryText: Color {
        colorScheme == .dark ? .white.opacity(0.85) : Color.black.opacity(0.75)
    }
    private var tertiaryText: Color {
        colorScheme == .dark ? .white.opacity(0.6) : Color.black.opacity(0.6)
    }
    private var mutedText: Color {
        colorScheme == .dark ? .white.opacity(0.5) : Color.black.opacity(0.5)
    }
    private var faintGrid: Color {
        colorScheme == .dark ? .white.opacity(0.1) : Color.black.opacity(0.08)
    }
    private var dividerLine: Color {
        colorScheme == .dark ? .white.opacity(0.2) : Color.black.opacity(0.12)
    }
    private var subtleDivider: Color {
        colorScheme == .dark ? .white.opacity(0.08) : Color.black.opacity(0.08)
    }
    private var iconBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.15) : Color.black.opacity(0.08)
    }
    private var trackBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.06)
    }
    private var splitHighlight: Color {
        colorScheme == .dark ? Color.yellow.opacity(0.06) : Color.yellow.opacity(0.18)
    }

    var body: some View {
        ZStack(alignment: .top) {
            pageBackground
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {

                    // MARK: - Map Header
                    ZStack(alignment: .bottom) {
                        Map(position: $cameraPosition, interactionModes: []) {
                            if !routeCoordinates.isEmpty {
                                MapPolyline(coordinates: routeCoordinates)
                                    .stroke(Color(red: 1.0, green: 0.4, blue: 0.3), lineWidth: 4)
                            }
                        }
                        .mapStyle(.standard)
                        // Map honours the system colorScheme rather than being
                        // locked to dark — keeps the route visible on a light
                        // background without forcing a black map underneath.
                        .frame(height: 350)
                        .opacity(0.85)

                        LinearGradient(
                            colors: [
                                pageBackground.opacity(0),
                                pageBackground
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 150)
                    }
                    .ignoresSafeArea(edges: .top)
                    // Stretchy header. When the user flick-scrolls to the
                    // top and the ScrollView bounces (negative scroll
                    // offset), `visualEffect` grows the map upward via
                    // bottom-anchored scale instead of letting the bounce
                    // reveal the empty grey background behind the map.
                    // Standard pattern in Strava / Runna / Apple Photos.
                    // `visualEffect` (iOS 17+) reads scroll geometry
                    // per-frame WITHOUT causing layout invalidation.
                    .visualEffect { content, proxy in
                        let minY = proxy.frame(in: .scrollView(axis: .vertical)).minY
                        // Only stretch when overscrolled past the top
                        // (minY > 0). Negative minY means the user has
                        // scrolled the content up — leave the map alone
                        // and let it scroll out naturally.
                        let stretch = max(0, minY)
                        let scale = 1 + (stretch / 350)
                        return content.scaleEffect(
                            x: scale,
                            y: scale,
                            anchor: .bottom
                        )
                    }

                    VStack(alignment: .leading, spacing: 24) {

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Outdoor run")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundStyle(primaryText)

                            HStack(spacing: 8) {
                                Image(systemName: "figure.run")
                                Text("Free Run")
                                Image(systemName: "arrowtriangle.down.fill")
                                    .font(.system(size: 8))
                                Text(" · ")
                                Text(String(format: "%.2fkm", run.distanceKm))
                            }
                            .font(.subheadline)
                            .foregroundStyle(secondaryText)
                        }

                        VStack(alignment: .leading, spacing: 16) {
                            HStack(spacing: 12) {
                                Image(systemName: "calendar")
                                    .foregroundStyle(tertiaryText)
                                    .font(.system(size: 20))

                                let endTime = run.runDate.addingTimeInterval(run.durationMinutes * 60)
                                Text("\(run.runDate.formatted(.dateTime.day().month().year())) at \(run.runDate.formatted(.dateTime.hour().minute())) - \(endTime.formatted(.dateTime.hour().minute()))")
                                    .font(.subheadline)
                                    .foregroundStyle(secondaryText)
                            }

                            HStack(spacing: 12) {
                                Image(systemName: "location.north.circle")
                                    .foregroundStyle(tertiaryText)
                                    .font(.system(size: 20))

                                Text("Local Route")
                                    .font(.subheadline)
                                    .foregroundStyle(secondaryText)
                            }
                        }
                        .padding(.top, 8)

                        VStack(spacing: 24) {
                            HStack {
                                StatItem(title: "DISTANCE", value: String(format: "%.2f", run.distanceKm), unit: "KM")
                                Spacer()
                                StatItem(title: "TIME", value: formatTime(minutes: run.durationMinutes), unit: "")
                                Spacer()
                                StatItem(title: "AVG PACE", value: normalizedAvgPaceValue, unit: "/KM")
                            }

                            HStack {
                                StatItem(title: "ELEVATION GAIN", value: elevGain != nil ? "▲ \(elevGain!)" : "--", unit: "m")
                                Spacer()
                                StatItem(title: "AVG HR", value: avgHR != nil ? "\(avgHR!)" : "--", unit: "")
                                Spacer()
                                StatItem(title: "CALORIES", value: run.calories != nil ? String(format: "%.0f", run.calories!) : "--", unit: "")
                            }
                        }
                        .padding(.top, 16)
                        .padding(.bottom, 24)

                        Button {
                            copyOverlayToClipboard()
                        } label: {
                            HStack {
                                if isPreparingShare {
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                        .tint(pageBackground)
                                } else {
                                    Image(systemName: "square.and.arrow.up")
                                }
                                Text(isPreparingShare ? "Preparing…" : "Share")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            // Auto-inverting: white on dark, near-black on light.
                            .background(Color.primary)
                            .foregroundStyle(pageBackground)
                            .cornerRadius(30)
                        }
                        .disabled(isPreparingShare)

                        if let pacePoints = analytics?.pacePoints, !pacePoints.isEmpty {
                            buildPaceChart(points: pacePoints)
                        }
                        if let hrPoints = analytics?.hrPoints, !hrPoints.isEmpty {
                            buildHeartRateChart(points: hrPoints)
                        }
                        if let zones = analytics?.hrZoneDistribution {
                            buildHRZonesCard(zones: zones)
                        }
                        if let cadencePoints = analytics?.cadencePoints, !cadencePoints.isEmpty {
                            buildCadenceChart(points: cadencePoints)
                        }
                        if let elevationPoints = analytics?.elevationPoints, !elevationPoints.isEmpty {
                            buildElevationChart(points: elevationPoints)
                        }
                        if let splits = analytics?.splits, !splits.isEmpty {
                            buildSplitsCard(splits: splits)
                        }

                        if let feedback = run.feedback, !feedback.isEmpty {
                            VStack(alignment: .leading, spacing: 16) {
                                HStack {
                                    Text("AI Coach Notes")
                                        .font(.headline)
                                        .foregroundStyle(primaryText)
                                    Spacer()
                                    Image(systemName: "bolt.fill")
                                        .foregroundStyle(.purple)
                                }

                                Text(feedback)
                                    .font(.subheadline)
                                    .foregroundStyle(secondaryText)
                                    .lineSpacing(4)
                            }
                            .padding(.top, 24)
                        }

                        Spacer().frame(height: 40)
                    }
                    .padding(.horizontal, 24)
                    .offset(y: -50)
                }
            }

            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 20, weight: .semibold))
                        // The back button sits on top of the map, which is
                        // light/dark depending on system scheme. Force-white
                        // glyph keeps it readable against either map colour
                        // since map imagery is always relatively light.
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.black.opacity(0.35))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
        }
        .navigationBarHidden(true)
        .overlay(alignment: .top) {
            if showCopiedToast {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Sticker Copied")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text("Paste it onto a photo in Stories, Photos, or iMessage.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(.primary.opacity(0.08), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
                .padding(.horizontal, 16)
                .padding(.top, 60)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .task {
            // 1. Prefer the persisted analytics blob — it follows the user's
            //    account so the route + charts work on any device they sign
            //    into, not just the one that recorded the workout.
            if let blob = run.analyticsBlob {
                analytics = blob.toAnalytics()
                let coords = blob.routeCoordinates
                if !coords.isEmpty {
                    routeCoordinates = coords
                    cameraPosition = routeBounds(for: coords)
                }
                if avgHR == nil, let hr = blob.avgHeartRate { avgHR = hr }
                if elevGain == nil, let elev = blob.elevationGainMeters { elevGain = elev }
                return
            }

            // 2. Fallback: pull from HealthKit on the device that recorded it.
            //    This is the legacy path for runs logged before the blob
            //    column existed, plus any run logged on a device where the
            //    upload happened but the blob couldn't be built.
            let coords: [CLLocationCoordinate2D]
            if let uuid = hkWorkoutUUID {
                coords = await HealthKitManager.shared.fetchRoute(byHKWorkoutUUID: uuid)
            } else {
                coords = await HealthKitManager.shared.fetchRoute(matching: run)
            }
            if !coords.isEmpty {
                routeCoordinates = coords
                cameraPosition = routeBounds(for: coords)
            }

            let resolved = await HealthKitManager.shared.fetchRunAnalytics(matching: run)
            analytics = resolved
            if avgHR == nil, let hr = resolved?.avgHeartRate { avgHR = hr }
            if elevGain == nil, let elev = resolved?.elevationGainMeters { elevGain = elev }

            // Fallback for runs that have HK metadata even when route/HR samples are absent
            if avgHR == nil || elevGain == nil {
                let metrics = await HealthKitManager.shared.fetchMetrics(matching: run)
                if avgHR == nil, let hr = metrics.avgHeartRate { avgHR = hr }
                if elevGain == nil, let elev = metrics.elevationMeters { elevGain = elev }
            }
        }
    }

    private func routeBounds(for coords: [CLLocationCoordinate2D]) -> MapCameraPosition {
        let lats = coords.map(\.latitude)
        let lons = coords.map(\.longitude)
        let minLat = lats.min()!, maxLat = lats.max()!
        let minLon = lons.min()!, maxLon = lons.max()!
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: max(0.005, (maxLat - minLat) * 1.4),
            longitudeDelta: max(0.005, (maxLon - minLon) * 1.4)
        )
        return .region(MKCoordinateRegion(center: center, span: span))
    }

    /// Strips any trailing pace-unit suffix from `run.avgPace` so the StatItem's
    /// "/KM" unit label doesn't double up with a "/km" the upstream formatter
    /// already baked into the value. Apple Watch / HealthKit paths emit
    /// "6:02 /km"; older paths emit just "6:02". Either is now safe to show.
    private var normalizedAvgPaceValue: String {
        guard let raw = run.avgPace, !raw.isEmpty else { return "--" }
        var trimmed = raw.trimmingCharacters(in: .whitespaces)
        // Strip trailing /km, /mi, /KM, /MI etc. — case-insensitive.
        let suffixes = ["/km", "/mi", "/KM", "/MI"]
        for suffix in suffixes {
            if trimmed.lowercased().hasSuffix(suffix.lowercased()) {
                trimmed = String(trimmed.dropLast(suffix.count))
                break
            }
        }
        return trimmed.trimmingCharacters(in: .whitespaces)
    }

    private func formatTime(minutes: Double) -> String {
        let totalSeconds = Int(minutes * 60)
        let h = totalSeconds / 3600
        let m = (totalSeconds % 3600) / 60
        let s = totalSeconds % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        } else {
            return String(format: "%02d:%02d", m, s)
        }
    }

    // MARK: - Share

    /// Renders `RunShareOverlay` (transparent variant) and writes the PNG
    /// (with alpha preserved) to the system pasteboard. Strava-style sticker
    /// flow: user copies, then pastes on top of their own photo in Stories /
    /// Photos / iMessage. Toast confirms the copy so the user isn't left
    /// guessing whether the tap did anything.
    private func copyOverlayToClipboard() {
        guard !isPreparingShare else { return }
        isPreparingShare = true

        let overlay = RunShareOverlay(
            distanceKm: run.distanceKm,
            durationMinutes: run.durationMinutes,
            paceLabel: normalizedAvgPaceValue,
            dateLabel: run.runDate.formatted(.dateTime.day().month().year()),
            routeCoordinates: routeCoordinates,
            elevationGain: elevGain,
            avgHR: avgHR,
            calories: run.calories
        )
        // Dark colour scheme so any semantic colour resolves to its dark
        // variant — matches the white-on-glow design of the overlay.
        let toRender = overlay.environment(\.colorScheme, .dark)

        DispatchQueue.main.async {
            let renderer = ImageRenderer(content: toRender)
            renderer.scale = 3
            // Go via cgImage so we control the resulting UIImage's
            // backing store — ImageRenderer.uiImage occasionally drops
            // alpha on iOS 17.x when the SwiftUI root is `Color.clear`.
            // Round-tripping through pngData() guarantees the pasteboard
            // gets a true RGBA PNG that pastes transparently in Photos /
            // Stories / iMessage.
            if let cg = renderer.cgImage {
                let ui = UIImage(cgImage: cg, scale: 3, orientation: .up)
                if let png = ui.pngData() {
                    UIPasteboard.general.setData(png, forPasteboardType: "public.png")
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    withAnimation(.spring(duration: 0.35)) { showCopiedToast = true }
                    // Auto-dismiss the toast after a moment.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        withAnimation(.easeOut(duration: 0.3)) { showCopiedToast = false }
                    }
                }
            }
            isPreparingShare = false
        }
    }
}

struct StatItem: View {
    let title: String
    let value: String
    let unit: String

    var body: some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                // Semantic colours auto-adapt to dark/light without needing
                // a colorScheme env in this sibling struct.
                .foregroundStyle(.secondary)
                .kerning(0.5)

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(.primary)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.primary)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Charts

extension RunDetailView {

    private func formatPaceString(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d/km", mins, secs)
    }

    private func formatPaceShort(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    @ViewBuilder
    private func buildPaceChart(points: [RunAnalytics.PacePoint]) -> some View {
        let avgSec = points.map(\.paceSecPerKm).reduce(0, +) / Double(points.count)
        let bestSec = points.map(\.paceSecPerKm).min() ?? avgSec
        // Slowest pace in the run defines the floor of the filled area. With
        // a reversed Y-axis (faster paces visually higher), a vanilla AreaMark
        // fills *upward* from each point to the axis baseline — which lands
        // the gradient above the line. Anchoring to maxSec floors the fill to
        // the visual bottom of the chart so the area sits underneath the
        // line, matching the cadence/HR chart convention.
        let maxSec = points.map(\.paceSecPerKm).max() ?? avgSec
        let coral = Color(red: 0.98, green: 0.45, blue: 0.38)

        VStack(alignment: .leading, spacing: 12) {
            Text("Pace")
                .font(.title2.weight(.bold))
                .foregroundStyle(primaryText)

            VStack(spacing: 0) {
                Chart {
                    ForEach(Array(points.enumerated()), id: \.offset) { _, pt in
                        LineMark(
                            x: .value("Distance", pt.distanceKm),
                            y: .value("Pace", pt.paceSecPerKm)
                        )
                        .foregroundStyle(coral)
                        .interpolationMethod(.monotone)

                        AreaMark(
                            x: .value("Distance", pt.distanceKm),
                            yStart: .value("Pace", pt.paceSecPerKm),
                            yEnd: .value("PaceFloor", maxSec)
                        )
                        .foregroundStyle(LinearGradient(colors: [coral.opacity(0.3), .clear], startPoint: .top, endPoint: .bottom))
                        .interpolationMethod(.monotone)
                    }

                    // Drag-to-scrub indicator. Snaps to the closest point
                    // and shows distance + pace in a callout.
                    if let x = selectedPaceX,
                       let pt = nearestPacePoint(points: points, atX: x) {
                        RuleMark(x: .value("Selected", pt.distanceKm))
                            .foregroundStyle(coral.opacity(0.4))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        PointMark(
                            x: .value("Distance", pt.distanceKm),
                            y: .value("Pace", pt.paceSecPerKm)
                        )
                        .foregroundStyle(coral)
                        .symbolSize(110)
                        // Callout above the data point, with `.fit`
                        // overflow handling on both axes so it can
                        // shift inward when crowded against any edge
                        // (including the top, which fixes the cut-off
                        // when scrubbing to the fastest split).
                        .annotation(position: .top, spacing: 6, overflowResolution: .init(x: .fit, y: .fit)) {
                            chartCallout(
                                primary: formatPaceShort(pt.paceSecPerKm) + "/km",
                                secondary: String(format: "%.2f km", pt.distanceKm),
                                accent: coral
                            )
                        }
                    }
                }
                .chartXSelection(value: $selectedPaceX)
                // Subtle scrub haptic. Trigger discretized to ~200m
                // intervals so dragging across a 5km chart fires ~25
                // ticks total — enough to feel the scrub without
                // continuous buzzing.
                .sensoryFeedback(.selection, trigger: selectedPaceX.map { Int($0 * 5) })
                .chartYScale(domain: .automatic(reversed: true))
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 1)).foregroundStyle(faintGrid)
                        if let sec = value.as(Double.self) {
                            AxisValueLabel {
                                Text(formatPaceShort(sec))
                                    .foregroundStyle(mutedText)
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(position: .bottom, values: .automatic(desiredCount: max(2, Int(run.distanceKm)))) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 1)).foregroundStyle(faintGrid)
                        if let v = value.as(Double.self) {
                            AxisValueLabel {
                                Text(String(format: "%.0f", v))
                                    .foregroundStyle(mutedText)
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .frame(height: 200)
                .padding(16)

                VStack(spacing: 16) {
                    statRow(label: "Avg pace", value: formatPaceString(avgSec))
                    Divider().overlay(dividerLine)
                    statRow(label: "Best pace", value: formatPaceString(bestSec))
                }
                .padding(20)
            }
            .background(cardBackground)
            .cornerRadius(16)
            .padding(.bottom, 24)
        }
    }

    @ViewBuilder
    private func buildHeartRateChart(points: [RunAnalytics.HRPoint]) -> some View {
        let avg = points.map(\.bpm).reduce(0, +) / Double(points.count)
        let peak = points.map(\.bpm).max() ?? avg
        let pink = Color(red: 1.0, green: 0.32, blue: 0.40)

        VStack(alignment: .leading, spacing: 12) {
            Text("Heart Rate")
                .font(.title2.weight(.bold))
                .foregroundStyle(primaryText)

            VStack(spacing: 0) {
                Chart {
                    ForEach(Array(points.enumerated()), id: \.offset) { _, pt in
                        LineMark(
                            x: .value("Time", pt.elapsed / 60),
                            y: .value("BPM", pt.bpm)
                        )
                        .foregroundStyle(pink)
                        .interpolationMethod(.monotone)

                        AreaMark(
                            x: .value("Time", pt.elapsed / 60),
                            y: .value("BPM", pt.bpm)
                        )
                        .foregroundStyle(LinearGradient(colors: [pink.opacity(0.3), .clear], startPoint: .top, endPoint: .bottom))
                        .interpolationMethod(.monotone)
                    }

                    if let x = selectedHRX,
                       let pt = nearestHRPoint(points: points, atX: x) {
                        RuleMark(x: .value("Selected", pt.elapsed / 60))
                            .foregroundStyle(pink.opacity(0.4))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        PointMark(
                            x: .value("Time", pt.elapsed / 60),
                            y: .value("BPM", pt.bpm)
                        )
                        .foregroundStyle(pink)
                        .symbolSize(110)
                        .annotation(position: .top, spacing: 6, overflowResolution: .init(x: .fit, y: .fit)) {
                            chartCallout(
                                primary: "\(Int(pt.bpm)) bpm",
                                secondary: formatElapsedShort(pt.elapsed),
                                accent: pink
                            )
                        }
                    }
                }
                .chartXSelection(value: $selectedHRX)
                // HR chart X is elapsed minutes — × 5 gives ~12 sec
                // granularity per haptic tick.
                .sensoryFeedback(.selection, trigger: selectedHRX.map { Int($0 * 5) })
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 1)).foregroundStyle(faintGrid)
                        if let v = value.as(Double.self) {
                            AxisValueLabel {
                                Text("\(Int(v))")
                                    .foregroundStyle(mutedText)
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(position: .bottom, values: .automatic(desiredCount: 5)) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 1)).foregroundStyle(faintGrid)
                        if let v = value.as(Double.self) {
                            AxisValueLabel {
                                Text("\(Int(v))m")
                                    .foregroundStyle(mutedText)
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .frame(height: 200)
                .padding(16)

                VStack(spacing: 16) {
                    statRow(label: "Avg HR", value: "\(Int(avg)) bpm")
                    Divider().overlay(dividerLine)
                    statRow(label: "Peak HR", value: "\(Int(peak)) bpm")
                }
                .padding(20)
            }
            .background(cardBackground)
            .cornerRadius(16)
            .padding(.bottom, 24)
        }
    }

    @ViewBuilder
    private func buildCadenceChart(points: [RunAnalytics.CadencePoint]) -> some View {
        let avg = points.map(\.spm).reduce(0, +) / Double(points.count)
        let peak = points.map(\.spm).max() ?? avg
        let mint = Color(red: 0.30, green: 0.85, blue: 0.65)

        VStack(alignment: .leading, spacing: 12) {
            Text("Cadence")
                .font(.title2.weight(.bold))
                .foregroundStyle(primaryText)

            VStack(spacing: 0) {
                Chart {
                    ForEach(Array(points.enumerated()), id: \.offset) { _, pt in
                        LineMark(
                            x: .value("Time", pt.elapsed / 60),
                            y: .value("SPM", pt.spm)
                        )
                        .foregroundStyle(mint)
                        .interpolationMethod(.monotone)

                        AreaMark(
                            x: .value("Time", pt.elapsed / 60),
                            y: .value("SPM", pt.spm)
                        )
                        .foregroundStyle(LinearGradient(colors: [mint.opacity(0.3), .clear], startPoint: .top, endPoint: .bottom))
                        .interpolationMethod(.monotone)
                    }

                    if let x = selectedCadenceX,
                       let pt = nearestCadencePoint(points: points, atX: x) {
                        RuleMark(x: .value("Selected", pt.elapsed / 60))
                            .foregroundStyle(mint.opacity(0.4))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        PointMark(
                            x: .value("Time", pt.elapsed / 60),
                            y: .value("SPM", pt.spm)
                        )
                        .foregroundStyle(mint)
                        .symbolSize(110)
                        .annotation(position: .top, spacing: 6, overflowResolution: .init(x: .fit, y: .fit)) {
                            chartCallout(
                                primary: "\(Int(pt.spm)) spm",
                                secondary: formatElapsedShort(pt.elapsed),
                                accent: mint
                            )
                        }
                    }
                }
                .chartXSelection(value: $selectedCadenceX)
                // Cadence chart X is elapsed minutes — same granularity
                // as HR for consistency (~12 sec per haptic tick).
                .sensoryFeedback(.selection, trigger: selectedCadenceX.map { Int($0 * 5) })
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 1)).foregroundStyle(faintGrid)
                        if let v = value.as(Double.self) {
                            AxisValueLabel {
                                Text("\(Int(v))")
                                    .foregroundStyle(mutedText)
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(position: .bottom, values: .automatic(desiredCount: 5)) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 1)).foregroundStyle(faintGrid)
                        if let v = value.as(Double.self) {
                            AxisValueLabel {
                                Text("\(Int(v))m")
                                    .foregroundStyle(mutedText)
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .frame(height: 200)
                .padding(16)

                VStack(spacing: 16) {
                    statRow(label: "Avg cadence", value: "\(Int(avg)) spm")
                    Divider().overlay(dividerLine)
                    statRow(label: "Peak cadence", value: "\(Int(peak)) spm")
                }
                .padding(20)
            }
            .background(cardBackground)
            .cornerRadius(16)
            .padding(.bottom, 24)
        }
    }

    @ViewBuilder
    private func buildHRZonesCard(zones: RunAnalytics.HRZoneDistribution) -> some View {
        let zoneColors: [Color] = [
            Color(red: 0.36, green: 0.55, blue: 1.0),
            Color(red: 0.30, green: 0.85, blue: 0.55),
            Color(red: 1.0, green: 0.85, blue: 0.20),
            Color(red: 1.0, green: 0.55, blue: 0.20),
            Color(red: 1.0, green: 0.32, blue: 0.40)
        ]
        let labels = ["Z1 Easy", "Z2 Aerobic", "Z3 Tempo", "Z4 Threshold", "Z5 VO₂"]

        VStack(alignment: .leading, spacing: 12) {
            Text("Heart Rate Zones")
                .font(.title2.weight(.bold))
                .foregroundStyle(primaryText)

            VStack(spacing: 14) {
                ForEach(0..<5, id: \.self) { i in
                    let pct = zones.percent(forZone: i)
                    let secs = Int(zones.secondsPerZone[i])
                    HStack(spacing: 10) {
                        Text(labels[i])
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(secondaryText)
                            .frame(width: 96, alignment: .leading)

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(trackBackground)
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(zoneColors[i])
                                    .frame(width: geo.size.width * CGFloat(pct))
                            }
                        }
                        .frame(height: 10)

                        Text(formatZoneDuration(secs))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(tertiaryText)
                            .frame(width: 50, alignment: .trailing)
                    }
                }

                Divider().overlay(dividerLine)

                HStack {
                    Text("Estimated max HR")
                        .font(.caption)
                        .foregroundStyle(tertiaryText)
                    Spacer()
                    Text("\(zones.maxHR) bpm")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(secondaryText)
                }
            }
            .padding(20)
            .background(cardBackground)
            .cornerRadius(16)
            .padding(.bottom, 24)
        }
    }

    private func formatZoneDuration(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }

    @ViewBuilder
    private func buildElevationChart(points: [RunAnalytics.ElevationPoint]) -> some View {
        let altitudes = points.map(\.altitudeMeters)
        let maxElev = Int(altitudes.max() ?? 0)
        let minElev = Int(altitudes.min() ?? 0)
        let totalGain = elevGain ?? analytics?.elevationGainMeters ?? 0

        VStack(alignment: .leading, spacing: 12) {
            Text("Elevation")
                .font(.title2.weight(.bold))
                .foregroundStyle(primaryText)

            VStack(spacing: 0) {
                Chart {
                    ForEach(Array(points.enumerated()), id: \.offset) { _, pt in
                        LineMark(
                            x: .value("Distance", pt.distanceKm),
                            y: .value("Elevation", pt.altitudeMeters)
                        )
                        .foregroundStyle(Color.blue.opacity(0.85))
                        .interpolationMethod(.monotone)

                        AreaMark(
                            x: .value("Distance", pt.distanceKm),
                            y: .value("Elevation", pt.altitudeMeters)
                        )
                        .foregroundStyle(LinearGradient(colors: [Color.blue.opacity(0.3), .clear], startPoint: .top, endPoint: .bottom))
                        .interpolationMethod(.monotone)
                    }

                    if let x = selectedElevationX,
                       let pt = nearestElevationPoint(points: points, atX: x) {
                        RuleMark(x: .value("Selected", pt.distanceKm))
                            .foregroundStyle(Color.blue.opacity(0.4))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        PointMark(
                            x: .value("Distance", pt.distanceKm),
                            y: .value("Elevation", pt.altitudeMeters)
                        )
                        .foregroundStyle(Color.blue)
                        .symbolSize(110)
                        .annotation(position: .top, spacing: 6, overflowResolution: .init(x: .fit, y: .fit)) {
                            chartCallout(
                                primary: "\(Int(pt.altitudeMeters)) m",
                                secondary: String(format: "%.2f km", pt.distanceKm),
                                accent: Color.blue
                            )
                        }
                    }
                }
                .chartXSelection(value: $selectedElevationX)
                // Elevation chart X is km — same granularity as pace
                // (~200m per haptic tick).
                .sensoryFeedback(.selection, trigger: selectedElevationX.map { Int($0 * 5) })
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 1)).foregroundStyle(faintGrid)
                        if let m = value.as(Double.self) {
                            AxisValueLabel {
                                Text("\(Int(m))")
                                    .foregroundStyle(mutedText)
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(position: .bottom, values: .automatic(desiredCount: max(2, Int(run.distanceKm)))) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 1)).foregroundStyle(faintGrid)
                        if let v = value.as(Double.self) {
                            AxisValueLabel {
                                Text(String(format: "%.0f", v))
                                    .foregroundStyle(mutedText)
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .frame(height: 200)
                .padding(16)

                VStack(spacing: 16) {
                    statRow(label: "Elevation gain", value: "\(totalGain) m")
                    Divider().overlay(dividerLine)
                    statRow(label: "Max elevation", value: "\(maxElev) m")
                    Divider().overlay(dividerLine)
                    statRow(label: "Min elevation", value: "\(minElev) m")
                }
                .padding(20)
            }
            .background(cardBackground)
            .cornerRadius(16)
            .padding(.bottom, 24)
        }
    }

    @ViewBuilder
    private func buildSplitsCard(splits: [RunAnalytics.Split]) -> some View {
        let bestSplitIdx: Int? = splits.indices.min { splits[$0].paceSecPerKm < splits[$1].paceSecPerKm }

        VStack(alignment: .leading, spacing: 12) {
            Text("Splits")
                .font(.title2.weight(.bold))
                .foregroundStyle(primaryText)

            VStack(spacing: 0) {
                HStack {
                    Text("KM").font(.caption2.weight(.bold)).foregroundStyle(mutedText)
                        .frame(width: 32, alignment: .leading)
                    Text("PACE").font(.caption2.weight(.bold)).foregroundStyle(mutedText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("HR").font(.caption2.weight(.bold)).foregroundStyle(mutedText)
                        .frame(width: 56, alignment: .trailing)
                    Text("TIME").font(.caption2.weight(.bold)).foregroundStyle(mutedText)
                        .frame(width: 56, alignment: .trailing)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)

                ForEach(Array(splits.enumerated()), id: \.element.id) { i, split in
                    let isBest = i == bestSplitIdx
                    HStack {
                        Text("\(split.index)")
                            .font(.subheadline.weight(.semibold).monospacedDigit())
                            .foregroundStyle(primaryText)
                            .frame(width: 32, alignment: .leading)

                        Text(formatPaceShort(split.paceSecPerKm))
                            .font(.subheadline.weight(isBest ? .bold : .regular).monospacedDigit())
                            .foregroundStyle(isBest ? Color(red: 1.0, green: 0.62, blue: 0.0) : primaryText)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Text(split.avgHRBpm.map { "\($0)" } ?? "—")
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(tertiaryText)
                            .frame(width: 56, alignment: .trailing)

                        Text(formatSplitTime(split.durationSeconds))
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(secondaryText)
                            .frame(width: 56, alignment: .trailing)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(isBest ? splitHighlight : Color.clear)

                    if i < splits.count - 1 {
                        Divider().overlay(subtleDivider).padding(.leading, 16)
                    }
                }
                Spacer().frame(height: 8)
            }
            .background(cardBackground)
            .cornerRadius(16)
            .padding(.bottom, 24)
        }
    }

    private func formatSplitTime(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%d:%02d", m, s)
    }

    private func statRow(label: String, value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(secondaryText)
            Spacer()
            Text(value).fontWeight(.semibold).foregroundStyle(primaryText)
        }
        .font(.subheadline)
    }

    // MARK: - Chart selection helpers

    /// Reusable callout pill for the chart-scrub selection. Two-line pill with
    /// a coloured top edge so it visually ties back to the chart's series.
    @ViewBuilder
    fileprivate func chartCallout(primary: String, secondary: String, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(primary)
                .font(.caption.weight(.bold))
                .foregroundStyle(primaryText)
            Text(secondary)
                .font(.caption2)
                .foregroundStyle(tertiaryText)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(cardBackground)
                .shadow(color: .black.opacity(colorScheme == .dark ? 0.4 : 0.12), radius: 6, y: 2)
        )
        .overlay(alignment: .top) {
            // Coloured edge pinned to the top of the pill so multiple charts
            // are visually distinguishable when stacked on the same screen.
            Rectangle()
                .fill(accent)
                .frame(height: 2)
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: 8, topTrailingRadius: 8))
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .fixedSize()
    }

    /// Linear-search for the data point closest to `x`. Plenty fast for the
    /// few-hundred-point arrays a run produces; binary-search would only
    /// matter for thousand-point datasets.
    fileprivate func nearestPacePoint(points: [RunAnalytics.PacePoint], atX x: Double) -> RunAnalytics.PacePoint? {
        guard !points.isEmpty else { return nil }
        return points.min { abs($0.distanceKm - x) < abs($1.distanceKm - x) }
    }

    fileprivate func nearestHRPoint(points: [RunAnalytics.HRPoint], atX x: Double) -> RunAnalytics.HRPoint? {
        guard !points.isEmpty else { return nil }
        // X is in minutes (elapsed / 60).
        return points.min { abs($0.elapsed / 60 - x) < abs($1.elapsed / 60 - x) }
    }

    fileprivate func nearestCadencePoint(points: [RunAnalytics.CadencePoint], atX x: Double) -> RunAnalytics.CadencePoint? {
        guard !points.isEmpty else { return nil }
        return points.min { abs($0.elapsed / 60 - x) < abs($1.elapsed / 60 - x) }
    }

    fileprivate func nearestElevationPoint(points: [RunAnalytics.ElevationPoint], atX x: Double) -> RunAnalytics.ElevationPoint? {
        guard !points.isEmpty else { return nil }
        return points.min { abs($0.distanceKm - x) < abs($1.distanceKm - x) }
    }

    /// "12:34" or "1:23:45" mm:ss / h:mm:ss for elapsed-seconds chart points.
    fileprivate func formatElapsedShort(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%d:%02d", m, s)
    }
}

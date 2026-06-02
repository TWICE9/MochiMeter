import SwiftUI
import MapKit
import CoreLocation

/// Personal route heatmap. Stacks every logged run's GPS polyline at low
/// opacity so streets the user runs frequently glow brighter — same idea as
/// Strava's personal heatmap, just driven by `LoggedRun.analyticsBlob.route`
/// data we already persist.
struct RouteHeatmapView: View {
    @StateObject private var service = FitnessService.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase

    enum DateFilter: String, CaseIterable, Identifiable {
        case days30 = "30 Days"
        case year = "1 Year"
        case all = "All Time"
        var id: String { rawValue }
        func includes(_ date: Date) -> Bool {
            let now = Date()
            switch self {
            case .days30: return date >= now.addingTimeInterval(-30 * 86_400)
            case .year:   return date >= now.addingTimeInterval(-365 * 86_400)
            case .all:    return true
            }
        }
    }

    enum ColorMode: String, CaseIterable, Identifiable {
        case frequency = "Frequency"
        case recency   = "Recency"
        var id: String { rawValue }
    }

    @State private var dateFilter: DateFilter = .days30
    @State private var colorMode: ColorMode = .frequency
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var matchedRuns: [LoggedRun] = []
    @State private var showMatchedSheet = false
    @State private var selectedRunForDetail: LoggedRun? = nil
    @State private var isLoading = false
    @State private var showImportSheet = false

    private var primaryTextColor: Color {
        colorScheme == .dark ? .white : Color(red: 32/255, green: 32/255, blue: 38/255)
    }
    private var secondaryTextColor: Color {
        colorScheme == .dark ? .white.opacity(0.7) : Color(red: 120/255, green: 120/255, blue: 130/255)
    }

    private var visibleRuns: [LoggedRun] {
        service.runs.filter { run in
            guard let coords = run.analyticsBlob?.routeCoordinates, !coords.isEmpty else { return false }
            return dateFilter.includes(run.runDate)
        }
    }

    /// Used to normalize each run's age into [0, 1] for recency coloring.
    private var ageRange: (newest: Date, oldest: Date)? {
        let dates = visibleRuns.map(\.runDate)
        guard let newest = dates.max(), let oldest = dates.min() else { return nil }
        return (newest, oldest)
    }

    var body: some View {
        ZStack(alignment: .top) {
            mapLayer
                .ignoresSafeArea()

            if !isLoading && visibleRuns.isEmpty {
                emptyOverlay
            }

            VStack(spacing: 0) {
                header
                Spacer()
                if !visibleRuns.isEmpty {
                    legendBar
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
                controlsBar
            }
        }
        .task {
            if service.runs.isEmpty {
                isLoading = true
                await service.fetchRuns()
                isLoading = false
            }
            recenterCamera(animated: false)
            // Silent catch-up: pull any HK runs newer than the latest
            // logged run so a run completed between sessions appears here
            // automatically, without requiring the explicit Import flow.
            await service.syncNewHealthKitRuns()
            recenterCamera(animated: false)
        }
        .onChange(of: dateFilter) { _, _ in
            recenterCamera(animated: true)
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task { await service.syncNewHealthKitRuns() }
        }
        .sheet(isPresented: $showMatchedSheet) {
            matchedRunsSheet
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $selectedRunForDetail) { run in
            RunDetailView(run: run)
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showImportSheet) {
            ImportRunHistorySheet()
                .presentationDetents([.height(460)])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Map

    private var mapLayer: some View {
        MapReader { proxy in
            Map(position: $cameraPosition) {
                ForEach(Array(visibleRuns.enumerated()), id: \.offset) { _, run in
                    if let coords = run.analyticsBlob?.routeCoordinates, !coords.isEmpty {
                        // Strava-style soft glow: three stacked polylines at
                        // decreasing widths + increasing opacities. MapKit
                        // doesn't expose a real shader-based blur for
                        // overlays, but stacking achieves the same falloff
                        // perceptually and stays GPU-cheap.
                        let color = baseColor(for: run)
                        let alphas = layerAlphas
                        MapPolyline(coordinates: coords)
                            .stroke(color.opacity(alphas.halo), lineWidth: 16)
                        MapPolyline(coordinates: coords)
                            .stroke(color.opacity(alphas.mid), lineWidth: 9)
                        MapPolyline(coordinates: coords)
                            .stroke(color.opacity(alphas.core), lineWidth: 3)
                    }
                }
            }
            .mapStyle(.standard(elevation: .flat))
            .onTapGesture { screenPoint in
                if let coord = proxy.convert(screenPoint, from: .local) {
                    handleMapTap(at: coord)
                }
            }
        }
    }

    /// Base hue for a run's polyline before opacity is applied.
    /// Frequency mode: every line shares a warm color so overlapping segments
    /// compound into "heat". Recency mode: hue fades from blue (oldest) to
    /// red (newest) across the visible set.
    private func baseColor(for run: LoggedRun) -> Color {
        switch colorMode {
        case .frequency:
            return Color(red: 1.0, green: 0.35, blue: 0.20)
        case .recency:
            guard let range = ageRange,
                  range.newest.timeIntervalSince(range.oldest) > 0 else {
                return Color.orange
            }
            let t = run.runDate.timeIntervalSince(range.oldest) /
                    range.newest.timeIntervalSince(range.oldest)
            let hue = (1.0 - t) * 0.66
            return Color(hue: hue, saturation: 0.9, brightness: 1.0)
        }
    }

    /// Per-mode alpha tuning for the 3-layer glow stack. Frequency uses very
    /// low alphas so dense overlap zones bloom toward white (Strava's
    /// hottest-stretch look); recency uses higher alphas because each run
    /// has its own distinct hue and shouldn't depend on overlap to be seen.
    private var layerAlphas: (halo: Double, mid: Double, core: Double) {
        switch colorMode {
        case .frequency: return (halo: 0.04, mid: 0.09, core: 0.28)
        case .recency:   return (halo: 0.06, mid: 0.14, core: 0.45)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Heatmap")
                    .font(.title2.bold())
                    .foregroundStyle(primaryTextColor)
                Text(headerSubtitle)
                    .font(.caption)
                    .foregroundStyle(secondaryTextColor)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Menu {
                Button {
                    showImportSheet = true
                } label: {
                    Label("Import from HealthKit", systemImage: "heart.text.square")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(secondaryTextColor)
                    .padding(10)
                    .background(Circle().fill(.ultraThinMaterial))
            }
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(secondaryTextColor)
                    .padding(10)
                    .background(Circle().fill(.ultraThinMaterial))
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(.primary.opacity(0.08), lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private var headerSubtitle: String {
        if isLoading { return "Loading routes…" }
        let count = visibleRuns.count
        if count == 0 { return "No routes in this range" }
        return "\(count) route\(count == 1 ? "" : "s") · tap a hotspot to see runs"
    }

    // MARK: - Legend

    /// Small gradient strip + min/max labels that decode the active color
    /// mode. Lives just above the controls bar — close enough to the
    /// pickers that the relationship is obvious, far enough from the map
    /// content that it doesn't compete with the routes.
    private var legendBar: some View {
        HStack(spacing: 10) {
            Text(legendLeftLabel)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.85))
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(LinearGradient(
                        colors: legendGradientColors,
                        startPoint: .leading,
                        endPoint: .trailing
                    ))
                    .frame(height: 8)
                Capsule()
                    .stroke(.white.opacity(0.15), lineWidth: 0.5)
                    .frame(height: 8)
            }
            .frame(maxWidth: .infinity)
            Text(legendRightLabel)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.85))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.55), in: Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.1), lineWidth: 1))
    }

    private var legendLeftLabel: String {
        switch colorMode {
        case .frequency: return "Less"
        case .recency:   return "Older"
        }
    }

    private var legendRightLabel: String {
        switch colorMode {
        case .frequency: return "More"
        case .recency:   return "Newer"
        }
    }

    /// Gradient stops mirror the actual rendered effect: frequency goes from
    /// faint orange to saturated white-hot (matching alpha compounding at
    /// dense overlap zones); recency walks the same blue→red hue ramp the
    /// renderer uses per-run.
    private var legendGradientColors: [Color] {
        switch colorMode {
        case .frequency:
            return [
                Color(red: 1.0, green: 0.35, blue: 0.20).opacity(0.25),
                Color(red: 1.0, green: 0.55, blue: 0.20).opacity(0.7),
                Color(red: 1.0, green: 0.85, blue: 0.55)
            ]
        case .recency:
            return stride(from: 0.0, through: 1.0, by: 0.2).map { t in
                Color(hue: (1.0 - t) * 0.66, saturation: 0.9, brightness: 1.0)
            }
        }
    }

    // MARK: - Controls bar

    private var controlsBar: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                ForEach(DateFilter.allCases) { filter in
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(.spring(duration: 0.3)) { dateFilter = filter }
                    } label: {
                        Text(filter.rawValue)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                Capsule().fill(dateFilter == filter
                                    ? Color.orange.opacity(0.85)
                                    : Color.primary.opacity(0.08))
                            )
                            .foregroundStyle(dateFilter == filter ? .white : primaryTextColor)
                    }
                    .buttonStyle(.plain)
                }
            }

            Picker("", selection: $colorMode) {
                ForEach(ColorMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 280)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(.primary.opacity(0.08), lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 24)
    }

    // MARK: - Empty state

    private var emptyOverlay: some View {
        VStack(spacing: 14) {
            Image(systemName: "map")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(secondaryTextColor)
            Text("No Routes Yet")
                .font(.headline)
                .foregroundStyle(primaryTextColor)
            Text("Pull in your past runs from HealthKit to start building your heatmap.")
                .font(.subheadline)
                .foregroundStyle(secondaryTextColor)
                .multilineTextAlignment(.center)
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                showImportSheet = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "heart.text.square")
                    Text("Import from HealthKit")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(Color.orange, in: Capsule())
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .padding(24)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Tap → matched runs

    /// Find every visible run whose route passes within ~75m of `tapped`.
    /// Uses local-tangent equirectangular distance — accurate enough at
    /// city scale and avoids per-point trig.
    private func handleMapTap(at tapped: CLLocationCoordinate2D) {
        let thresholdMeters = 75.0
        let metersPerDegLat = 111_000.0
        let metersPerDegLon = metersPerDegLat * cos(tapped.latitude * .pi / 180)
        let thresholdSq = thresholdMeters * thresholdMeters

        let matches: [LoggedRun] = visibleRuns.filter { run in
            guard let coords = run.analyticsBlob?.routeCoordinates else { return false }
            for coord in coords {
                let dLat = (coord.latitude - tapped.latitude) * metersPerDegLat
                let dLon = (coord.longitude - tapped.longitude) * metersPerDegLon
                if (dLat * dLat + dLon * dLon) < thresholdSq {
                    return true
                }
            }
            return false
        }

        guard !matches.isEmpty else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        matchedRuns = matches.sorted { $0.runDate > $1.runDate }
        showMatchedSheet = true
    }

    private var matchedRunsSheet: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 8) {
                        Image(systemName: "mappin.circle.fill").foregroundStyle(.orange)
                        Text("\(matchedRuns.count) run\(matchedRuns.count == 1 ? "" : "s") through this area")
                            .font(.subheadline.weight(.semibold))
                    }
                    .listRowBackground(Color.clear)
                }
                Section {
                    ForEach(matchedRuns, id: \.id) { run in
                        Button {
                            selectedRunForDetail = run
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(run.runDate.formatted(date: .abbreviated, time: .shortened))
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.primary)
                                    HStack(spacing: 12) {
                                        Label(String(format: "%.2f km", run.distanceKm),
                                              systemImage: "map.fill")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        if let pace = run.avgPace {
                                            Label(pace, systemImage: "stopwatch.fill")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Runs Here")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Camera

    private func recenterCamera(animated: Bool) {
        let coords = visibleRuns.flatMap { $0.analyticsBlob?.routeCoordinates ?? [] }
        guard !coords.isEmpty else { return }
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
        let region = MKCoordinateRegion(center: center, span: span)
        if animated {
            withAnimation(.easeInOut(duration: 0.4)) {
                cameraPosition = .region(region)
            }
        } else {
            cameraPosition = .region(region)
        }
    }
}

// MARK: - Heatmap card (Running tab widget)

/// Glanceable heatmap card that lives on the Running tab. Renders the same
/// stacked-polyline visualization as the full screen at preview size so the
/// feature is visually obvious — the row-button version blended in with
/// Pace Calculator and Run History.
struct RouteHeatmapCard: View {
    @StateObject private var service = FitnessService.shared
    var onTap: () -> Void

    @State private var cameraPosition: MapCameraPosition = .automatic

    /// Recent GPS-tracked runs. Card always uses a 30-day window so the
    /// preview doesn't get noisy with years of overlap.
    private var recentRuns: [LoggedRun] {
        let cutoff = Date().addingTimeInterval(-30 * 86_400)
        return service.runs.filter { run in
            guard let coords = run.analyticsBlob?.routeCoordinates, !coords.isEmpty else { return false }
            return run.runDate >= cutoff
        }
    }

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onTap()
        } label: {
            ZStack {
                if recentRuns.isEmpty {
                    emptyContent
                } else {
                    mapContent
                    overlay
                }
            }
            .frame(height: 180)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(.primary.opacity(0.08), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 6)
        }
        .buttonStyle(PressScaleStyle())
        .onAppear { fitCamera() }
        .onChange(of: recentRuns.count) { _, _ in fitCamera() }
    }

    private var mapContent: some View {
        Map(position: $cameraPosition, interactionModes: []) {
            ForEach(Array(recentRuns.enumerated()), id: \.offset) { _, run in
                if let coords = run.analyticsBlob?.routeCoordinates, !coords.isEmpty {
                    // Same 3-layer glow stack as the full screen, scaled
                    // down for the preview.
                    let color = Color(red: 1.0, green: 0.35, blue: 0.20)
                    MapPolyline(coordinates: coords)
                        .stroke(color.opacity(0.05), lineWidth: 11)
                    MapPolyline(coordinates: coords)
                        .stroke(color.opacity(0.12), lineWidth: 6)
                    MapPolyline(coordinates: coords)
                        .stroke(color.opacity(0.32), lineWidth: 2)
                }
            }
        }
        .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
        .allowsHitTesting(false)
    }

    private var overlay: some View {
        ZStack {
            VStack(spacing: 0) {
                LinearGradient(
                    colors: [.black.opacity(0.55), .clear],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(height: 70)
                Spacer()
                LinearGradient(
                    colors: [.clear, .black.opacity(0.55)],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(height: 90)
            }

            VStack {
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "map.fill")
                        Text("Route Heatmap")
                    }
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Color.black.opacity(0.4), in: Capsule())
                    Spacer()
                }
                Spacer()
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(subtitle)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                        Text("Tap to explore")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.85))
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white.opacity(0.85))
                }
            }
            .padding(16)
        }
    }

    private var subtitle: String {
        let n = recentRuns.count
        return "\(n) route\(n == 1 ? "" : "s") · last 30 days"
    }

    private var emptyContent: some View {
        ZStack {
            LinearGradient(
                colors: [Color.orange.opacity(0.18), Color.orange.opacity(0.06)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    Circle().fill(Color.orange.opacity(0.18)).frame(width: 44, height: 44)
                    Image(systemName: "map.fill").foregroundStyle(Color.orange)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Route Heatmap")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.primary)
                    Text("Log a GPS run and your routes will start lighting up here.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            .padding(20)
        }
    }

    private func fitCamera() {
        let coords = recentRuns.flatMap { $0.analyticsBlob?.routeCoordinates ?? [] }
        guard !coords.isEmpty else { return }
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
        cameraPosition = .region(MKCoordinateRegion(center: center, span: span))
    }
}

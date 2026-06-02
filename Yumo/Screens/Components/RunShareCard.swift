import SwiftUI
import CoreLocation

// MARK: - Transparent Overlay (Strava-style sticker)

/// 1080×1920 transparent route + stats overlay rendered as a PNG with alpha.
/// Designed to be pasted on top of a user's own photo (Instagram Stories,
/// Photos, iMessage) — no brand background, just the polyline and stats with
/// soft dark glows so they stay legible over any image.
struct RunShareOverlay: View {
    let distanceKm: Double
    let durationMinutes: Double
    let paceLabel: String
    let dateLabel: String
    let routeCoordinates: [CLLocationCoordinate2D]
    let elevationGain: Int?
    let avgHR: Int?
    let calories: Double?

    private var timeLabel: String {
        let totalSeconds = Int(durationMinutes * 60)
        let h = totalSeconds / 3600
        let m = (totalSeconds % 3600) / 60
        let s = totalSeconds % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%02d:%02d", m, s)
    }

    var body: some View {
        // ZStack with no background colour keeps the rendered PNG fully
        // transparent. Every text + line gets its own dark drop-shadow so
        // the sticker stays legible whether the user pastes it on a bright
        // beach photo or a dark city skyline.
        ZStack {
            Color.clear

            VStack(spacing: 0) {
                Spacer(minLength: 0)

                // Tight content cluster — date / route / stats sit right
                // next to each other so the sticker reads as one unit
                // instead of three islands floating in the canvas.
                Text(dateLabel)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.6), radius: 6, x: 0, y: 2)
                    .padding(.bottom, 18)

                routePanel
                    .frame(width: 880, height: 880)

                statsRow
                    .padding(.top, 24)
                    .padding(.horizontal, 40)

                if hasSecondaryStats {
                    secondaryStatsRow
                        .padding(.top, 20)
                        .padding(.horizontal, 64)
                }

                brandMark
                    .padding(.top, 28)

                Spacer(minLength: 0)
            }
        }
        .frame(width: 1080, height: 1920)
    }

    @ViewBuilder
    private var routePanel: some View {
        if routeCoordinates.count > 1 {
            ZStack {
                // Dark halo so a white line stays visible on bright photos.
                RoutePolylineShape(coordinates: routeCoordinates)
                    .stroke(.black.opacity(0.55),
                            style: StrokeStyle(lineWidth: 30, lineCap: .round, lineJoin: .round))
                    .blur(radius: 22)
                // White inner glow so a white line stays visible on dark photos.
                RoutePolylineShape(coordinates: routeCoordinates)
                    .stroke(.white.opacity(0.55),
                            style: StrokeStyle(lineWidth: 22, lineCap: .round, lineJoin: .round))
                    .blur(radius: 12)
                // Crisp core stroke.
                RoutePolylineShape(coordinates: routeCoordinates)
                    .stroke(.white,
                            style: StrokeStyle(lineWidth: 12, lineCap: .round, lineJoin: .round))
                    .shadow(color: .black.opacity(0.45), radius: 6, x: 0, y: 2)
            }
        } else {
            // No GPS — still produce a recognizable sticker so the user
            // doesn't get an empty translucent rectangle.
            ZStack {
                Circle()
                    .strokeBorder(.white.opacity(0.75), lineWidth: 5)
                    .frame(width: 480, height: 480)
                Image(systemName: "figure.run")
                    .font(.system(size: 260, weight: .bold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.5), radius: 8, x: 0, y: 3)
            }
        }
    }

    private var statsRow: some View {
        HStack(spacing: 0) {
            statColumn(label: "DISTANCE", value: String(format: "%.2f", distanceKm), unit: "km")
            statColumn(label: "TIME", value: timeLabel, unit: "")
            statColumn(label: "PACE", value: paceLabel, unit: "/km")
        }
    }

    private func statColumn(label: String, value: String, unit: String) -> some View {
        VStack(spacing: 10) {
            Text(label)
                .font(.system(size: 20, weight: .heavy))
                .kerning(2)
                .foregroundStyle(.white.opacity(0.85))
                .shadow(color: .black.opacity(0.6), radius: 4, x: 0, y: 1)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 70, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.6), radius: 6, x: 0, y: 2)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.9))
                        .shadow(color: .black.opacity(0.6), radius: 4, x: 0, y: 1)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    /// Subtle brand mark anchored at the bottom of the sticker. Logo only —
    /// readable enough on its own that the wordmark would be redundant.
    /// `LogoDarkMode` is the light-on-dark variant of the app icon, paired
    /// with a soft drop-shadow so it stays visible on bright photos too.
    private var brandMark: some View {
        Image("LogoDarkMode")
            .resizable()
            .scaledToFit()
            .frame(width: 140, height: 140)
            .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
            .shadow(color: .black.opacity(0.6), radius: 12, x: 0, y: 4)
    }

    private var hasSecondaryStats: Bool {
        (elevationGain ?? 0) > 0 || avgHR != nil || (calories ?? 0) > 0
    }

    private var secondaryStatsRow: some View {
        HStack(spacing: 36) {
            if let avgHR { secondaryStat(icon: "heart.fill", text: "\(avgHR) bpm") }
            if let elevationGain, elevationGain > 0 {
                secondaryStat(icon: "mountain.2.fill", text: "\(elevationGain) m")
            }
            if let calories, calories > 0 {
                secondaryStat(icon: "flame.fill", text: "\(Int(calories)) cal")
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func secondaryStat(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .bold))
            Text(text)
                .font(.system(size: 26, weight: .semibold, design: .rounded))
        }
        .foregroundStyle(.white.opacity(0.92))
        .shadow(color: .black.opacity(0.6), radius: 4, x: 0, y: 1)
    }
}

// MARK: - Route Polyline Shape

/// Renders a `[CLLocationCoordinate2D]` polyline into a SwiftUI `Path`,
/// fitting the path inside the given rect while preserving aspect ratio.
/// Latitude is flipped because lat increases northward but screen Y
/// increases downward.
struct RoutePolylineShape: Shape {
    let coordinates: [CLLocationCoordinate2D]

    func path(in rect: CGRect) -> Path {
        guard coordinates.count > 1 else { return Path() }

        var minLat = Double.greatestFiniteMagnitude
        var maxLat = -Double.greatestFiniteMagnitude
        var minLng = Double.greatestFiniteMagnitude
        var maxLng = -Double.greatestFiniteMagnitude
        for c in coordinates {
            if c.latitude < minLat { minLat = c.latitude }
            if c.latitude > maxLat { maxLat = c.latitude }
            if c.longitude < minLng { minLng = c.longitude }
            if c.longitude > maxLng { maxLng = c.longitude }
        }

        let latRange = max(maxLat - minLat, 0.0001)
        let lngRange = max(maxLng - minLng, 0.0001)

        // Account for latitude shrinking longitude visually as you move
        // away from the equator. Without this correction long east-west
        // routes look squashed.
        let midLat = (minLat + maxLat) / 2
        let lngScaleCorrection = cos(midLat * .pi / 180)
        let correctedLngRange = lngRange * lngScaleCorrection

        let scaleX = rect.width / correctedLngRange
        let scaleY = rect.height / latRange
        let scale = min(scaleX, scaleY)

        let drawnW = correctedLngRange * scale
        let drawnH = latRange * scale
        let dx = rect.minX + (rect.width - drawnW) / 2
        let dy = rect.minY + (rect.height - drawnH) / 2

        var path = Path()
        for (i, coord) in coordinates.enumerated() {
            let x = dx + (coord.longitude - minLng) * lngScaleCorrection * scale
            let y = dy + (maxLat - coord.latitude) * scale
            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        return path
    }
}

//
//  RunAnalyticsBlob.swift
//  Yumo
//
//  Cloud-persisted snapshot of a run's full HealthKit analytics. Stored in
//  `logged_runs.analytics_blob` (jsonb) so the route polyline, charts, and
//  splits all survive across devices — without this, signing in on a fresh
//  device shows the run with no graphs because HealthKit only has the data
//  on the device that recorded the workout.
//
//  Keys are intentionally short (single-letter where unambiguous) so the
//  JSON payload stays compact — a typical run produces 5–50 KB.
//

import Foundation
import CoreLocation

struct RunAnalyticsBlob: Codable, Sendable {
    struct PacePoint: Codable, Sendable {
        let d: Double  // distanceKm
        let p: Double  // paceSecPerKm
    }
    struct ElevationPoint: Codable, Sendable {
        let d: Double  // distanceKm
        let a: Double  // altitudeMeters
    }
    struct HRPoint: Codable, Sendable {
        let t: TimeInterval  // elapsed
        let bpm: Double
    }
    struct CadencePoint: Codable, Sendable {
        let t: TimeInterval  // elapsed
        let spm: Double
    }
    struct Split: Codable, Sendable {
        let i: Int                       // 1-indexed split number
        let d: Double                    // distanceKm
        let s: TimeInterval              // durationSeconds
        let h: Int?                      // avgHRBpm (optional)
    }
    struct HRZones: Codable, Sendable {
        let s: [TimeInterval]  // secondsPerZone (5 entries: Z1..Z5)
        let m: Int             // maxHR estimate
    }
    struct RoutePoint: Codable, Sendable {
        let lat: Double
        let lng: Double
    }

    let pacePoints: [PacePoint]?
    let elevationPoints: [ElevationPoint]?
    let hrPoints: [HRPoint]?
    let cadencePoints: [CadencePoint]?
    let splits: [Split]?
    let hrZones: HRZones?
    let elevationGainMeters: Int?
    let avgHeartRate: Int?
    let maxHeartRate: Int?
    let avgCadenceSPM: Int?
    let route: [RoutePoint]?

    enum CodingKeys: String, CodingKey {
        case pacePoints = "pace"
        case elevationPoints = "elev"
        case hrPoints = "hr"
        case cadencePoints = "cad"
        case splits
        case hrZones = "zones"
        case elevationGainMeters = "elev_gain"
        case avgHeartRate = "avg_hr"
        case maxHeartRate = "max_hr"
        case avgCadenceSPM = "avg_cad"
        case route
    }
}

// MARK: - Conversion to/from RunAnalytics

extension RunAnalyticsBlob {
    /// Serialize a HealthKit-derived `RunAnalytics` (and optional route) into
    /// a blob ready for upload. Returns nil if every field would be empty —
    /// no point storing a blob with nothing useful in it.
    init?(analytics: RunAnalytics?, route: [CLLocationCoordinate2D]) {
        let hasAnalytics = analytics?.hasAnyChartData == true
            || analytics?.elevationGainMeters != nil
            || analytics?.avgHeartRate != nil
            || analytics?.avgCadenceSPM != nil
        let hasRoute = !route.isEmpty
        guard hasAnalytics || hasRoute else { return nil }

        self.pacePoints = analytics?.pacePoints?.map {
            PacePoint(d: $0.distanceKm, p: $0.paceSecPerKm)
        }
        self.elevationPoints = analytics?.elevationPoints?.map {
            ElevationPoint(d: $0.distanceKm, a: $0.altitudeMeters)
        }
        self.hrPoints = analytics?.hrPoints?.map {
            HRPoint(t: $0.elapsed, bpm: $0.bpm)
        }
        self.cadencePoints = analytics?.cadencePoints?.map {
            CadencePoint(t: $0.elapsed, spm: $0.spm)
        }
        self.splits = analytics?.splits?.map {
            Split(i: $0.index, d: $0.distanceKm, s: $0.durationSeconds, h: $0.avgHRBpm)
        }
        if let zones = analytics?.hrZoneDistribution {
            self.hrZones = HRZones(s: zones.secondsPerZone, m: zones.maxHR)
        } else {
            self.hrZones = nil
        }
        self.elevationGainMeters = analytics?.elevationGainMeters
        self.avgHeartRate = analytics?.avgHeartRate
        self.maxHeartRate = analytics?.maxHeartRate
        self.avgCadenceSPM = analytics?.avgCadenceSPM
        self.route = route.isEmpty ? nil : route.map {
            RoutePoint(lat: $0.latitude, lng: $0.longitude)
        }
    }

    /// Rebuild a `RunAnalytics` from the persisted blob so `RunDetailView`
    /// can drive its existing chart code unchanged.
    func toAnalytics() -> RunAnalytics {
        RunAnalytics(
            pacePoints: pacePoints?.map {
                RunAnalytics.PacePoint(distanceKm: $0.d, paceSecPerKm: $0.p)
            },
            elevationPoints: elevationPoints?.map {
                RunAnalytics.ElevationPoint(distanceKm: $0.d, altitudeMeters: $0.a)
            },
            hrPoints: hrPoints?.map {
                RunAnalytics.HRPoint(elapsed: $0.t, bpm: $0.bpm)
            },
            cadencePoints: cadencePoints?.map {
                RunAnalytics.CadencePoint(elapsed: $0.t, spm: $0.spm)
            },
            splits: splits?.map {
                RunAnalytics.Split(
                    index: $0.i,
                    distanceKm: $0.d,
                    durationSeconds: $0.s,
                    avgHRBpm: $0.h
                )
            },
            hrZoneDistribution: hrZones.map {
                RunAnalytics.HRZoneDistribution(secondsPerZone: $0.s, maxHR: $0.m)
            },
            elevationGainMeters: elevationGainMeters,
            avgHeartRate: avgHeartRate,
            maxHeartRate: maxHeartRate,
            avgCadenceSPM: avgCadenceSPM
        )
    }

    var routeCoordinates: [CLLocationCoordinate2D] {
        (route ?? []).map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lng) }
    }
}

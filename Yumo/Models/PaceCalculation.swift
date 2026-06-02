import Foundation
import SwiftData

@Model
final class PaceCalculation {
    @Attribute(.unique) var id: UUID
    var userId: String?
    var timestamp: Date

    var label: String
    var distanceKm: Double
    var durationSeconds: Double
    var paceSecondsPerKm: Double
    var useMiles: Bool

    init(
        id: UUID = UUID(),
        userId: String? = nil,
        timestamp: Date = Date(),
        label: String,
        distanceKm: Double,
        durationSeconds: Double,
        paceSecondsPerKm: Double,
        useMiles: Bool
    ) {
        self.id = id
        self.userId = userId
        self.timestamp = timestamp
        self.label = label
        self.distanceKm = distanceKm
        self.durationSeconds = durationSeconds
        self.paceSecondsPerKm = paceSecondsPerKm
        self.useMiles = useMiles
    }
}

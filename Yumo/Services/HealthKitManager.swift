//
//  HealthKitManager.swift
//  Yumo
//

import Foundation
import HealthKit
import Combine

@MainActor
class HealthKitManager: ObservableObject {
    static let shared = HealthKitManager()

    private let healthStore = HKHealthStore()
    @Published var isAuthorized = false

    private init() {}

    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("HealthKit is not available on this device")
            throw HealthKitError.notAvailable
        }

        let typesToRead: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!
        ]

        try await healthStore.requestAuthorization(toShare: [], read: typesToRead)
        isAuthorized = true
        print("✅ HealthKit authorization granted")
    }
}

enum HealthKitError: Error {
    case notAvailable
}

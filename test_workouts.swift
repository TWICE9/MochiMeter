import Foundation
import HealthKit

let healthStore = HKHealthStore()

func run() {
    let type = HKObjectType.workoutType()
    let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
    let query = HKSampleQuery(sampleType: type, predicate: nil, limit: 10, sortDescriptors: [sort]) { _, results, error in
        guard let workouts = results as? [HKWorkout] else {
            print("No workouts")
            exit(0)
        }
        
        for workout in workouts {
            print("Workout: \(workout.workoutActivityType)")
            print("Source: \(workout.sourceRevision.source.name)")
            if let metadata = workout.metadata {
                for (k, v) in metadata {
                    print(" - \(k): \(v)")
                }
            } else {
                print(" - No metadata")
            }
            if let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate),
               let stats = workout.statistics(for: hrType),
               let avg = stats.averageQuantity() {
                print(" - HR from stats: \(avg)")
            } else {
                print(" - No HR in stats")
            }
        }
        exit(0)
    }
    healthStore.execute(query)
}

if HKHealthStore.isHealthDataAvailable() {
    print("HealthKit available")
    run()
    RunLoop.main.run()
} else {
    print("HealthKit not available")
}

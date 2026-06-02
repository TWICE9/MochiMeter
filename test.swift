import Foundation
import HealthKit

func testWorkout(workout: HKWorkout) {
    let type = HKQuantityType.quantityType(forIdentifier: .heartRate)!
    let stats = workout.statistics(for: type)
    let avg = stats?.averageQuantity()
    print(avg)
}

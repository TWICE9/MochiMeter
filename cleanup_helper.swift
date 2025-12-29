// Temporary helper to clean up 0-calorie CommonFood entries
// Add this to your HomeScreen or SettingsScreen temporarily
// Call it once on .onAppear, then remove it

import SwiftData

func cleanupInvalidCommonFoods(modelContext: ModelContext) {
    // Find all CommonFood entries with 0 or negative calories
    let allFoods = try? modelContext.fetch(FetchDescriptor<CommonFood>())
    
    var deletedCount = 0
    allFoods?.forEach { food in
        if food.caloriesPerServing <= 0 {
            print("🗑️ Deleting invalid food: \(food.name) (\(food.caloriesPerServing) cal)")
            modelContext.delete(food)
            deletedCount += 1
        }
    }
    
    if deletedCount > 0 {
        try? modelContext.save()
        print("✅ Cleaned up \(deletedCount) invalid food entries")
    } else {
        print("✅ No invalid entries found")
    }
}

// Usage in your view:
// .onAppear {
//     cleanupInvalidCommonFoods(modelContext: modelContext)
// }

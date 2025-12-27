import Foundation
import SwiftData

enum SharedModelContainer {

    static let appGroupIdentifier = "group.com.jesseta.yumo"

    static func create() -> ModelContainer {

        let schema = Schema([
            LoggedFood.self,
            LoggedWater.self,
            LoggedWeight.self,
            UserGoals.self,
            CommonFood.self,
            FastingLog.self,
            Recipe.self,
            Reminder.self,
            CloudFood.self
        ])

        // Attempt to load App Group directory
        if let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        ) {

            // Recommended: place SwiftData inside a dedicated folder
            let swiftDataURL = containerURL
                .appendingPathComponent("SwiftData", isDirectory: true)

            // Create folder if missing
            try? FileManager.default.createDirectory(
                at: swiftDataURL,
                withIntermediateDirectories: true
            )

            // Database file
            let sqliteURL = swiftDataURL.appendingPathComponent("Yumo.sqlite")

            let config = ModelConfiguration(
                url: sqliteURL,
                allowsSave: true
            )

            print("📦 SwiftData stored at: \(sqliteURL.path)")
            return try! ModelContainer(for: schema, configurations: [config])
        }

        // Fallback (will wipe each launch - should never happen)
        print("⚠️ App Group missing → SwiftData running in-memory")
        return try! ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
        )
    }
}

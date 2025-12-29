# MochiMeter

MochiMeter is an AI-powered calorie tracker designed to make food logging effortless. Instead of manually searching for every ingredient, you just snap a photo of your meal, and our AI breaks down the calories and macros for you.

We're trying to take the friction out of tracking your nutrition.

## Features

*   **AI Food Scanner:** Point your camera at a meal, and it'll recognise the food, estimate portions, and give you the nutritional breakdown.
*   **Barcode Scanner:** Quickly scan packaged foods using our database of over 2 million products.
*   **Smart Search:** If you prefer typing, search across multiple verified databases (USDA, OpenFoodFacts, etc.).
*   **Daily Tracking:** Keep an eye on your calories, macros, and water intake. Visual charts help you spot trends over time.
*   **Fasting Timer:** Built-in timer to help you stick to your eating windows if you're into intermittent fasting.
*   **Cloud Sync:** Everything syncs across your devices instantly.
*   **Home Screen Widgets:** Check your progress without even opening the app.

## Getting Started

To get this running locally:

1.  Clone the repository.
2.  Navigate to the project folder.
3.  You'll need a `Secrets.xcconfig` file for the API keys. Use `Secrets.example.xcconfig` as a template.
4.  Open `Yumo.xcodeproj` in Xcode.
5.  Build and run.

## Tech Stack

*   **iOS:** Swift, SwiftUI
*   **Backend:** Supabase
*   **ML:** Custom AI integration for food recognition

## Feedback

We're currently in Beta and keen to hear what you think. If you spot a bug or have an idea for a feature, let us know. The "Fix Result" feature is there if the AI gets it wrong—using it helps improve the accuracy for everyone.

Cheers.

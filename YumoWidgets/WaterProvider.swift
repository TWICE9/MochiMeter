// YumoWidgets/WaterWidget.swift

import WidgetKit
import SwiftUI
import SwiftData
import AppIntents

struct WaterProvider: TimelineProvider {
    func placeholder(in context: Context) -> WaterEntry {
        WaterEntry(date: Date(), currentAmount: 1250, goalAmount: 3000)
    }

    func getSnapshot(in context: Context, completion: @escaping (WaterEntry) -> ()) {
        let entry = WaterEntry(date: Date(), currentAmount: 1500, goalAmount: 3000)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        Task {
            let data = await fetchWaterData()
            let entry = WaterEntry(date: Date(), currentAmount: data.current, goalAmount: data.goal)
            
            let nextUpdate = Date().addingTimeInterval(15 * 60)
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            completion(timeline)
        }
    }
    
    @MainActor
    private func fetchWaterData() -> (current: Double, goal: Double) {
        let container = SharedModelContainer.create()
        let context = ModelContext(container)

        do {
            // Get userId from App Group UserDefaults
            let appGroupDefaults = UserDefaults(suiteName: "group.com.jesseta.yumo")
            let userId = appGroupDefaults?.string(forKey: "current_user_id")

            // Fetch user-scoped goals
            let goalsPredicate: Predicate<UserGoals>
            if let userId = userId {
                goalsPredicate = #Predicate { $0.userId == userId }
            } else {
                goalsPredicate = #Predicate { $0.userId == nil }
            }
            let goalDescriptor = FetchDescriptor<UserGoals>(predicate: goalsPredicate)
            let goal = try context.fetch(goalDescriptor).first?.dailyWaterML ?? 3000

            // Fetch user-scoped water logs for today
            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: Date())
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

            let waterPredicate: Predicate<LoggedWater>
            if let userId = userId {
                waterPredicate = #Predicate { log in
                    log.userId == userId && log.timestamp >= startOfDay && log.timestamp < endOfDay
                }
            } else {
                waterPredicate = #Predicate { log in
                    log.userId == nil && log.timestamp >= startOfDay && log.timestamp < endOfDay
                }
            }
            let waterDescriptor = FetchDescriptor<LoggedWater>(predicate: waterPredicate)
            let logs = try context.fetch(waterDescriptor)

            let total = logs.reduce(0.0) { currentTotal, log in
                currentTotal + log.amountML
            }

            return (total, goal)
        } catch {
            return (0, 3000)
        }
    }
}

struct WaterEntry: TimelineEntry {
    let date: Date
    let currentAmount: Double
    let goalAmount: Double
}

struct WaterWidgetEntryView : View {
    var entry: WaterProvider.Entry
    @Environment(\.colorScheme) var colorScheme

    var fillPercentage: Double {
        min(entry.currentAmount / max(entry.goalAmount, 1), 1.0)
    }

    // MARK: - Adaptive Colors (High Contrast for Light Mode)
    private var primaryTextColor: Color {
        colorScheme == .dark ? .white : .black
    }

    private var secondaryTextColor: Color {
        colorScheme == .dark ? .white.opacity(0.8) : Color(red: 60/255, green: 60/255, blue: 67/255)
    }

    private var backgroundColor: Color {
        colorScheme == .dark ? Color("AppPrimaryDark") : .white
    }

    private var cupOutlineColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.3) : Color.black.opacity(0.2)
    }

    private var buttonBackgroundColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.9) : Color.white
    }

    private var buttonForegroundColor: Color {
        colorScheme == .dark ? .black : .black
    }

    var body: some View {
        ZStack {
            // The Cup
            GeometryReader { geo in
                ZStack(alignment: .bottom) {
                    // Water Level
                    Rectangle()
                        .fill(Color("AppSecondaryAccent"))
                        .frame(height: geo.size.height * CGFloat(fillPercentage))

                    // Cup Outline Overlay
                    WaterCupShape()
                        .stroke(cupOutlineColor, lineWidth: 3)
                }
                .mask(WaterCupShape())
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            // Text Overlay
            VStack {
                Text("\(Int(entry.currentAmount))")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(primaryTextColor)
                    .shadow(color: colorScheme == .dark ? .black.opacity(0.3) : .clear, radius: 2, x: 0, y: 1)

                Text("of \(Int(entry.goalAmount))")
                    .font(.caption)
                    .foregroundStyle(secondaryTextColor)
                    .shadow(color: colorScheme == .dark ? .black.opacity(0.3) : .clear, radius: 2, x: 0, y: 1)

                Spacer()

                // Interactive Button
                Button(intent: LogWaterIntent()) {
                    Image(systemName: "plus")
                        .font(.title3.bold())
                        .foregroundStyle(buttonForegroundColor)
                        .frame(width: 32, height: 32)
                        .background(buttonBackgroundColor)
                        .clipShape(Circle())
                        .shadow(color: colorScheme == .dark ? .clear : .black.opacity(0.1), radius: 2, x: 0, y: 1)
                }
                .buttonStyle(.plain)
                .padding(.bottom, 4)
            }
            .padding()
        }
        .containerBackground(for: .widget) {
            if colorScheme == .dark {
                backgroundColor
            } else {
                ZStack {
                    backgroundColor
                    LinearGradient(
                        colors: [Color("AppSecondaryAccent").opacity(0.25), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            }
        }
    }
}

struct WaterWidget: Widget {
    let kind: String = "WaterWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WaterProvider()) { entry in
            WaterWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Hydration")
        .description("Track your daily water intake.")
        .supportedFamilies([.systemSmall])
    }
}

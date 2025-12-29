import WidgetKit
import SwiftUI
import SwiftData

// MARK: - MochiTheme (Duplicated for Widget)
enum MochiTheme: String, CaseIterable, Codable {
    case matcha = "Matcha"
    case strawberry = "Strawberry"
    case taro = "Taro"
    case mango = "Mango"
    case blueberry = "Blueberry"
    
    var primaryColor: Color {
        switch self {
        case .matcha: return Color(red: 0.63, green: 0.79, blue: 0.54)
        case .strawberry: return Color(red: 1.0, green: 0.55, blue: 0.65)
        case .taro: return Color(red: 0.75, green: 0.65, blue: 0.95)
        case .mango: return Color(red: 1.0, green: 0.85, blue: 0.4)
        case .blueberry: return Color(red: 0.5, green: 0.6, blue: 0.95)
        }
    }
    
    var darkPrimaryColor: Color {
        switch self {
        case .matcha: return Color(red: 0.72, green: 0.83, blue: 0.66)
        case .strawberry: return Color(red: 1.0, green: 0.7, blue: 0.75)
        case .taro: return Color(red: 0.75, green: 0.65, blue: 0.95)
        case .mango: return Color(red: 1.0, green: 0.85, blue: 0.4)
        case .blueberry: return Color(red: 0.65, green: 0.75, blue: 1.0)
        }
    }
}

// NOTE: You must ensure 'SharedModelContainer' is defined and correctly configured
// for App Group sharing in a separate file accessible by both your main app and widget extension.

// ------------------------------------------------------
// MARK: - TIMELINE PROVIDER
// ------------------------------------------------------

struct CalorieProvider: TimelineProvider {

    func placeholder(in context: Context) -> CalorieEntry {
        CalorieEntry(date: .now, current: 1250, goal: 2100, multiplier: 1.0, unit: "kcal")
    }

    func getSnapshot(in context: Context, completion: @escaping (CalorieEntry) -> ()) {
        Task {
            let data = fetchCalorieData()
            completion(CalorieEntry(date: .now, current: data.current, goal: data.goal, multiplier: data.multiplier, unit: data.unit))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        Task {
            let data = fetchCalorieData()
            let entry = CalorieEntry(date: .now, current: data.current, goal: data.goal, multiplier: data.multiplier, unit: data.unit)

            completion(
                Timeline(
                    entries: [entry],
                    policy: .after(.now.addingTimeInterval(900)) // 15 min
                )
            )
        }
    }

    private func fetchCalorieData() -> (current: Double, goal: Double, multiplier: Double, unit: String) {
        // Warning: Repeatedly creating the ModelContainer can be unstable.
        // It is strongly recommended to use a single, shared static instance.
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
            let goalsDescriptor = FetchDescriptor<UserGoals>(predicate: goalsPredicate)
            let goals = try context.fetch(goalsDescriptor).first
            let dailyGoal = goals?.dailyCalories ?? 2000

            // Fetch user-scoped food logs for today
            let cal = Calendar.current
            let start = cal.startOfDay(for: .now)
            let end = cal.date(byAdding: .day, value: 1, to: start)!

            let logsPredicate: Predicate<LoggedFood>
            if let userId = userId {
                logsPredicate = #Predicate {
                    $0.userId == userId && $0.timestamp >= start && $0.timestamp < end && $0.recipe == nil
                }
            } else {
                logsPredicate = #Predicate {
                    $0.userId == nil && $0.timestamp >= start && $0.timestamp < end && $0.recipe == nil
                }
            }

            let logs = try context.fetch(FetchDescriptor(predicate: logsPredicate))
            let total = logs.reduce(0) { $0 + $1.totalCalories }

            // Determine Unit
            var multiplier = 1.0
            var unit = "kcal"
            if let g = goals, g.energyUnitRaw == "kilojoules" {
                multiplier = 4.184
                unit = "kJ"
            }

            return (total, dailyGoal, multiplier, unit)
        }
        catch {
            print("Calorie Widget Data Fetch Error: \(error)")
            return (0, 2000, 1.0, "kcal")
        }
    }
}


// ------------------------------------------------------
// MARK: - ENTRY
// ------------------------------------------------------

struct CalorieEntry: TimelineEntry {
    let date: Date
    let current: Double
    let goal: Double
    let multiplier: Double
    let unit: String
}

// ------------------------------------------------------
// MARK: - WIDGET VIEW
// ------------------------------------------------------

struct CalorieWidgetEntryView: View {

    var entry: CalorieProvider.Entry
    @Environment(\.widgetFamily) var family
    @Environment(\.colorScheme) var colorScheme

    var progress: Double {
        entry.goal > 0 ? min(entry.current / entry.goal, 1.0) : 0
    }

    // MARK: - Adaptive Colors (High Contrast for Light Mode)
    private var primaryTextColor: Color {
        colorScheme == .dark ? .white : .black
    }

    private var secondaryTextColor: Color {
        colorScheme == .dark ? .white.opacity(0.7) : Color(red: 60/255, green: 60/255, blue: 67/255)
    }

    private var backgroundColor: Color {
        colorScheme == .dark ? Color("AppPrimaryDark") : .white
    }

    private var ringTrackColor: Color {
        colorScheme == .dark ? Color.black.opacity(0.3) : Color.black.opacity(0.15)
    }

    private var macroBackgroundColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.10) : Color.black.opacity(0.08)
    }
    
    // MARK: - Theme Color Support
    private var themeColor: Color {
        if let themeName = UserDefaults(suiteName: "group.com.jesseta.yumo")?.string(forKey: "selectedTheme"),
           let theme = MochiTheme(rawValue: themeName) {
            return colorScheme == .dark ? theme.darkPrimaryColor : theme.primaryColor
        }
        return Color("AppSecondaryAccent") // Fallback
    }

    var body: some View {
        switch family {

        // -------------------------------
        // SMALL WIDGET
        // -------------------------------
        case .systemSmall:
            VStack(spacing: 0) {

                Spacer()

                // Ring
                ZStack {
                    Circle()
                        .stroke(ringTrackColor, lineWidth: 10)

                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(
                            themeColor,
                            style: StrokeStyle(lineWidth: 10, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))

                    VStack(spacing: 0) {
                        Text("\(Int((entry.goal - entry.current) * entry.multiplier))")
                            .font(.system(size: 22, weight: .heavy))
                            .foregroundColor(primaryTextColor)

                        Text("left")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(secondaryTextColor)
                    }
                }
                .frame(width: 70, height: 70)

                Spacer()

                // MACROS
                HStack(spacing: 14) {
                    macro("C", Int(entry.current/4), .red)
                    macro("P", Int(entry.current/10), .yellow)
                    macro("F", Int(entry.current/20), .blue)
                }
                .frame(maxWidth: .infinity)
                .padding(8)
                .background(macroBackgroundColor)
                .clipShape(RoundedRectangle(cornerRadius: 12))

                Spacer()
            }
            .padding(12)
            .widgetURL(URL(string: "yumo://home"))
            // Full bleed background for small widget
            .containerBackground(for: .widget) {
                if colorScheme == .dark {
                    backgroundColor
                } else {
                    ZStack {
                        backgroundColor
                        LinearGradient(
                            colors: [themeColor.opacity(0.25), .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    }
                }
            }

        // -------------------------------
        // MEDIUM WIDGET
        // -------------------------------
        case .systemMedium:
            HStack {
                // 1. Progress Ring (bigger)
                ZStack {
                    Circle()
                        .stroke(ringTrackColor, lineWidth: 14)

                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(
                            themeColor,
                            style: StrokeStyle(lineWidth: 14, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))

                    VStack(spacing: 0) {
                        Text("\(Int(entry.goal - entry.current))")
                            .font(.system(size: 28, weight: .heavy))
                            .foregroundColor(primaryTextColor)

                        Text("left")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(secondaryTextColor)
                    }
                }
                .frame(width: 105, height: 105)
                .padding(.trailing, 14)

                // 2. Main Calorie Data & Macros
                VStack(alignment: .leading, spacing: 6) {
                    Text("Today's Energy")
                        .font(.caption)
                        .foregroundColor(secondaryTextColor)

                    Text("\(Int(entry.current * entry.multiplier)) / \(Int(entry.goal * entry.multiplier)) \(entry.unit)")
                        .font(.title3.weight(.bold))
                        .foregroundColor(primaryTextColor)

                    // Macros
                    HStack(spacing: 14) {
                        macro("C", Int(entry.current/4), .red)
                        macro("P", Int(entry.current/10), .yellow)
                        macro("F", Int(entry.current/20), .blue)
                    }
                    .padding(8)
                    .background(macroBackgroundColor)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Spacer()
            }
            .padding(16)
            .widgetURL(URL(string: "yumo://home"))
            // Full bleed background for medium widget
            .containerBackground(for: .widget) {
                if colorScheme == .dark {
                    backgroundColor
                } else {
                    ZStack {
                        backgroundColor
                        LinearGradient(
                            colors: [themeColor.opacity(0.25), .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    }
                }
            }


        // -------------------------------
        // LOCK SCREEN (Circular)
        // -------------------------------
        case .accessoryCircular:
            Gauge(value: entry.current, in: 0...max(entry.goal, 1)) {
                EmptyView()
            } currentValueLabel: {
                VStack(spacing: 0) {
                    Text("\(Int((entry.goal - entry.current) * entry.multiplier))")
                        .font(.system(size: 18, weight: .bold))
                    Text("left")
                        .font(.system(size: 8))
                }
            }
            .gaugeStyle(.accessoryCircular)
            // Required for accessory widgets
            .containerBackground(.fill.tertiary, for: .widget)

        // -------------------------------
        // LOCK SCREEN (Rectangular)
        // -------------------------------
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 4) {
                // Calories
                HStack {
                    Text("Calories:")
                        .font(.system(size: 12, weight: .semibold))
                    Spacer()
                    Text("\(Int(entry.current * entry.multiplier)) / \(Int(entry.goal * entry.multiplier)) \(entry.unit)")
                        .font(.system(size: 12, weight: .bold))
                }

                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.white.opacity(0.3))
                            .frame(height: 4)

                        Rectangle()
                            .fill(Color.green)
                            .frame(width: geometry.size.width * min(progress, 1.0), height: 4)
                    }
                }
                .frame(height: 4)

                // Macros
                HStack(spacing: 12) {
                    lockScreenMacro("C", Int(entry.current/4), .red)
                    lockScreenMacro("P", Int(entry.current/10), .yellow)
                    lockScreenMacro("F", Int(entry.current/20), .blue)
                }
            }
            .containerBackground(.fill.tertiary, for: .widget)

        default:
            EmptyView()
        }
    }

    private func macro(_ label: String, _ value: Int, _ color: Color) -> some View {
        VStack {
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(color)

            Text("\(value)")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(primaryTextColor)
        }
    }

    private func lockScreenMacro(_ label: String, _ value: Int, _ color: Color) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(color)
            Text("\(value)g")
                .font(.system(size: 11, weight: .semibold))
        }
    }

    private func miniRing(_ progress: Double, _ color: Color) -> some View {
        let clampedProgress = min(max(progress, 0.0), 1.0)

        return ZStack {
            Circle()
                .stroke(Color.black.opacity(0.3), lineWidth: 3)

            Circle()
                .trim(from: 0, to: clampedProgress)
                .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: 28, height: 28)
    }
}

// ------------------------------------------------------
// MARK: - WIDGET
// ------------------------------------------------------

struct CalorieWidget: Widget {
    let kind = "CalorieWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CalorieProvider()) { entry in
            CalorieWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Daily Calories")
        .description("Your calories for the day.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular])
    }
}

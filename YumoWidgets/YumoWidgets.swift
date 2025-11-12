// YumoWidgets/YumoWidgets.swift

import WidgetKit
import SwiftUI

// 1. The Provider
struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(date: Date())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let entry = SimpleEntry(date: Date())
        // Update once an hour
        let timeline = Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(3600)))
        completion(timeline)
    }
}

// 2. The Entry
struct SimpleEntry: TimelineEntry {
    let date: Date
}

// 3. The View (Content Only)
struct ScanWidgetEntryView : View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family
    @Environment(\.colorScheme) var colorScheme

    // MARK: - Adaptive Colors (High Contrast for Light Mode)
    private var primaryTextColor: Color {
        colorScheme == .dark ? .white : .black
    }

    private var backgroundColor: Color {
        colorScheme == .dark ? Color("AppPrimaryDark") : .white
    }

    var body: some View {
        switch family {
        case .accessoryCircular:
            // Lock screen widget - icon only
            Image(systemName: "barcode.viewfinder")
                .font(.system(size: 32))
                .widgetURL(URL(string: "yumo://scan"))
                .containerBackground(.fill.tertiary, for: .widget)

        default:
            // Small widget - icon + text
            VStack(spacing: 8) {
                Image(systemName: "barcode.viewfinder")
                    .font(.system(size: 40))
                    .foregroundStyle(Color("AppSecondaryAccent"))

                Text("Scan")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(primaryTextColor)
            }
            .widgetURL(URL(string: "yumo://scan"))
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
}

// 4. The Widget Definition
struct ScanWidget: Widget {
    let kind: String = "ScanWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            ScanWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Quick Scan")
        .description("Immediately open the barcode scanner.")
        .supportedFamilies([.systemSmall, .accessoryCircular])
    }
}

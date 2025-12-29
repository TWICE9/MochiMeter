import SwiftUI
import SwiftData
import Charts

struct WeightHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var themeManager: ThemeManager
    
    @Query private var weightLogs: [LoggedWeight]
    @Query private var userGoals: [UserGoals]
    
    init(userId: String = "") {
        let weightPredicate = #Predicate<LoggedWeight> { $0.userId == userId }
        _weightLogs = Query(filter: weightPredicate, sort: \.timestamp, order: .reverse)
        
        let goalsPredicate = #Predicate<UserGoals> { $0.userId == userId }
        _userGoals = Query(filter: goalsPredicate)
    }
    
    private var goals: UserGoals? {
        userGoals.first
    }
    
    private var primaryAccent: Color {
        colorScheme == .dark ? themeManager.currentTheme.darkPrimaryColor : themeManager.currentTheme.primaryColor
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                backgroundColor
                    .ignoresSafeArea()
                
                if weightLogs.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "scalemass")
                            .font(.system(size: 48))
                            .foregroundStyle(.gray)
                        Text("No weight logs yet")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    List {
                        if !weightLogs.isEmpty {
                            Section {
                                _buildChart()
                                    .listRowInsets(EdgeInsets())
                                    .listRowBackground(Color.clear)
                                    .padding(.bottom, 8)
                            }
                        }
                        
                        ForEach(weightLogs) { log in
                            WeightLogRow(log: log)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        deleteWeight(log)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                                .listRowBackground(Color.clear)
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Weight History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }

        }
    }
    
    private var backgroundColor: Color {
        colorScheme == .dark ? Color.black : Color(hex: "F2F2F7")
    }
    
    @ViewBuilder
    private func _buildChart() -> some View {
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let recentLogs = weightLogs
            .filter { $0.timestamp >= thirtyDaysAgo }
            .sorted { $0.timestamp < $1.timestamp }
        
        if !recentLogs.isEmpty {
            VStack(alignment: .leading, spacing: 16) {
                Text("Last 30 Days")
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .padding(.horizontal)
                    .padding(.top)
                
                Chart {
                    if let targetWeight = goals?.targetWeight {
                        RuleMark(y: .value("Goal", targetWeight))
                            .lineStyle(.init(lineWidth: 1, dash: [6, 6]))
                            .foregroundStyle(.gray.opacity(0.5))
                    }
                    
                    ForEach(recentLogs) { log in
                        LineMark(
                            x: .value("Date", log.timestamp),
                            y: .value("Weight", log.weightKg)
                        )
                        .interpolationMethod(.catmullRom)
                        .lineStyle(.init(lineWidth: 3))
                        .foregroundStyle(primaryAccent)
                        
                        PointMark(
                            x: .value("Date", log.timestamp),
                            y: .value("Weight", log.weightKg)
                        )
                        .symbol(.circle)
                        .symbolSize(60)
                        .foregroundStyle(primaryAccent)
                    }
                }
                .frame(height: 200)
                .chartXAxis {
                    AxisMarks(values: .automatic) { _ in
                        AxisGridLine().foregroundStyle(.gray.opacity(0.1))
                        AxisValueLabel(format: .dateTime.day().month())
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisGridLine().foregroundStyle(.gray.opacity(0.1))
                        AxisValueLabel()
                    }
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .background(Color(hex: "F2F2F7").opacity(colorScheme == .dark ? 0.1 : 0.5))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)
        }
    }

    private func deleteWeight(_ log: LoggedWeight) {
        let weightId = log.id.uuidString
        let userId = log.userId
        
        withAnimation {
            modelContext.delete(log)
            try? modelContext.save()
        }
        
        // Delete from cloud if user is signed in
        if let userId = userId {
            Task {
                await CloudSyncManager.shared.deleteWeightLogFromCloud(logId: weightId, userId: userId)
            }
        }
    }
}

private struct WeightLogRow: View {
    let log: LoggedWeight
    
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme
    
    private var primaryAccent: Color {
        colorScheme == .dark ? themeManager.currentTheme.darkPrimaryColor : themeManager.currentTheme.primaryColor
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(log.timestamp.formatted(date: .abbreviated, time: .shortened))
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                
                if let note = log.note, !note.isEmpty {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            Text("\(String(format: "%.1f", log.weightKg)) kg")
                .font(.headline)
                .foregroundStyle(primaryAccent)
        }
        .padding(.vertical, 4)
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

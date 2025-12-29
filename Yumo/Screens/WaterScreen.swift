// Screens/WaterScreen.swift

import SwiftUI
import SwiftData
import WidgetKit

struct WaterScreen: View {
    
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var themeManager: ThemeManager

    // MARK: - Local State

    @State private var waterLogsToday: [LoggedWater] = []
    @State private var goals: UserGoals = UserGoals()
    
    // Animation State
    @State private var offset1: CGSize = .zero
    @State private var offset2: CGSize = .zero

    // MARK: - Computed Properties
    
    private var totalWaterToday: Double {
        waterLogsToday.reduce(0) { $0 + $1.amountML }
    }
    
    private var fillPercentage: Double {
        guard goals.dailyWaterML > 0 else { return 0.0 }
        let percentage = totalWaterToday / goals.dailyWaterML
        return min(percentage, 1.1)
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color("AppPrimaryDark").ignoresSafeArea()
                _buildDynamicBackground()
                
                VStack(spacing: 24) {
                    
                    // --- 1. Header (Content Title) ---
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Stay Hydrated")
                            .font(.title2)
                            .fontWeight(.medium)
                            .foregroundColor(Color("AppTextPrimary").opacity(0.8))
                        
                        Text("Your Daily Water")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(Color("AppTextPrimary"))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    
                    Spacer()
                    
                    // --- 2. Animated Water Cup ---
                    ZStack {
                        WaterCupShape()
                            .stroke(Color("AppTextPrimary").opacity(0.2), lineWidth: 6)
                        
                        WaterCupShape()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color("AppSecondaryAccent").opacity(0.8),
                                        Color("AppSecondaryAccent")
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .mask {
                                // Wave Animation
                                TimelineView(.animation(minimumInterval: 0.025)) { context in
                                    GeometryReader { geo in
                                        let time = context.date.timeIntervalSinceReferenceDate
                                        let amplitude: CGFloat = 8
                                        let frequency: CGFloat = 15
                                        let phase = -time.truncatingRemainder(dividingBy: 2) * .pi
                                        let waterLevel = max(geo.size.height * (1.0 - fillPercentage), 0)
                                            
                                        Path { path in
                                            path.move(to: CGPoint(x: 0, y: geo.size.height))
                                            for x in stride(from: 0, through: geo.size.width, by: 1) {
                                                let relativeX = x / frequency
                                                let sine = sin(relativeX + phase)
                                                let y = waterLevel + (sine * amplitude)
                                                path.addLine(to: CGPoint(x: x, y: y))
                                            }
                                            path.addLine(to: CGPoint(x: geo.size.width, y: waterLevel))
                                            path.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height))
                                            path.closeSubpath()
                                        }
                                    }
                                }
                            }
                    }
                    .frame(width: 200, height: 300)
                    .animation(.easeInOut(duration: 0.6), value: fillPercentage)
                    
                    Spacer()
                    
                    // --- 3. Water Log Button ---
                    Button { logWater() } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "plus")
                            Text("Log \(Int(goals.waterCupSizeML)) mL")
                        }
                        .font(.headline).bold().foregroundColor(.black)
                        .padding()
                        .frame(maxWidth: 250)
                        .background(Color("AppSecondaryAccent"))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)
                    
                    // --- "REMOVE" BUTTON ---
                    Button { removeLastWater() } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.uturn.backward").font(.subheadline)
                            Text("Remove Last Cup").font(.headline)
                        }
                        .foregroundStyle(waterLogsToday.isEmpty ? .gray : Color("AppTextPrimary").opacity(0.8))
                        .padding()
                        .frame(maxWidth: 250)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(waterLogsToday.isEmpty ? .gray.opacity(0.5) : Color("AppTextPrimary").opacity(0.5), lineWidth: 2)
                        )
                    }
                    .disabled(waterLogsToday.isEmpty)
                    .animation(.default, value: waterLogsToday.isEmpty)
                    
                    Text("\(Int(totalWaterToday)) of \(Int(goals.dailyWaterML)) mL")
                        .font(.title3).bold().foregroundStyle(Color("AppTextPrimary"))
                    
                    Spacer()
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Color("AppTextPrimary").opacity(0.6))
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text("Daily Water")
                        .font(.headline).bold()
                        .foregroundStyle(Color("AppTextPrimary"))
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await refreshData()
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    Task { await refreshData() }
                }
            }
            .onAppear {
                animateOrbs()
            }
        }
    }

    // MARK: - Functions

    private func refreshData() async {
        // Fetch user-scoped water logs for today
        waterLogsToday = await UserScopedQuery.fetchWaterLogsForToday(context: modelContext)
        if let fetchedGoals = await UserScopedQuery.fetchUserGoals(context: modelContext) {
            goals = fetchedGoals
        }
    }

    private func logWater() {
        Task {
            let userId = await UserSession.shared.getCurrentUserId()
            let validatedAmount = InputValidation.capCupSize(goals.waterCupSizeML)
            let newLog = LoggedWater(amountML: validatedAmount)
            newLog.userId = userId
            modelContext.insert(newLog)
            try? modelContext.save()

            // Upload to cloud if user is signed in
            if let userId = userId {
                await CloudSyncManager.shared.uploadWaterLogImmediately(newLog, userId: userId)
            }
            
            // Track analytics
            AnalyticsManager.shared.trackWaterLogged(amountML: validatedAmount)
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        WidgetCenter.shared.reloadAllTimelines()

        // Refresh data to show new log
        Task { await refreshData() }
    }

    private func removeLastWater() {
        if let lastLog = waterLogsToday.first {
            let logId = lastLog.id.uuidString
            let userId = lastLog.userId

            modelContext.delete(lastLog)
            try? modelContext.save() // Ensure delete is persisted before widget reload
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            WidgetCenter.shared.reloadAllTimelines()

            // Delete from cloud if user is signed in
            if let userId = userId {
                Task {
                    await CloudSyncManager.shared.deleteWaterLogFromCloud(logId: logId, userId: userId)
                }
            }

            // Refresh data to update UI
            Task { await refreshData() }
        }
    }

    @ViewBuilder
    private func _buildDynamicBackground() -> some View {
        ZStack {
            // Orb 1: Primary Theme Color (Top Left)
            RadialGradient(
                gradient: Gradient(colors: [
                    colorScheme == .light 
                        ? themeManager.currentTheme.primaryColor.opacity(0.4) 
                        : themeManager.currentTheme.darkPrimaryColor.opacity(0.25),
                    .clear
                ]),
                center: .topLeading,
                startRadius: 50,
                endRadius: 450
            )
            .offset(offset1)
            .offset(x: -150, y: -150)
            .ignoresSafeArea()

            // Orb 2: Complementary Color (Bottom Right)
            RadialGradient(
                gradient: Gradient(colors: [
                    themeManager.currentTheme.complementaryColor.opacity(colorScheme == .light ? 0.35 : 0.25),
                    .clear
                ]),
                center: .bottomTrailing,
                startRadius: 100,
                endRadius: 500
            )
            .offset(offset2)
            .offset(x: 100, y: 150)
            .ignoresSafeArea()
        }
        .blur(radius: 60)
    }

    private func animateOrbs() {
        withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
            offset1 = CGSize(width: 80, height: 60)
        }
        withAnimation(.easeInOut(duration: 10).repeatForever(autoreverses: true)) {
            offset2 = CGSize(width: -100, height: -70)
        }
    }
}

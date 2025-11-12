// Screens/FastingView.swift

import SwiftUI
import SwiftData

struct FastingView: View {

    @EnvironmentObject private var fastingManager: FastingManager
    @Environment(\.modelContext) private var modelContext
    @State private var selectedGoal: Double = 16.0

    // Background animation state
    @State private var offset1: CGSize = .zero
    @State private var offset2: CGSize = .zero

    var body: some View {
        ZStack {
            _buildDynamicBackground()

            ScrollView {
                VStack(spacing: 32) {

                    // --- Header ---
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Intermittent Fasting")
                            .font(.title2)
                            .fontWeight(.medium)
                            .foregroundColor(Color("AppTextPrimary").opacity(0.8))

                        Text("Fasting Timer")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(Color("AppTextPrimary"))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.top, 20)

                    // --- Main Timer Display ---
                    if fastingManager.timerRunning {
                        _buildActiveTimerView()
                    } else {
                        _buildGoalSelectionView()
                    }

                    Spacer()
                }
                .padding(.bottom, 100)
            }
            .scrollIndicators(.hidden)
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Fasting")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            animateOrbs()
            if fastingManager.timerRunning {
                fastingManager.timeElapsed = Date().timeIntervalSince(fastingManager.currentLog!.startTime)
            }
        }
    }

    // MARK: - Active Timer View
    @ViewBuilder
    private func _buildActiveTimerView() -> some View {
        if let log = fastingManager.currentLog {
            let progress = fastingManager.timeElapsed / log.goalDuration
            let remainingTime = max(0, log.goalDuration - fastingManager.timeElapsed)
            let projectedEndTime = log.startTime.addingTimeInterval(log.goalDuration)

            VStack(spacing: 22) {
                FrostedGlassContainer {
                    VStack(spacing: 20) {
                        // Top time pills
                        HStack(spacing: 12) {
                            _buildTimePill(title: "Start", time: log.startTime)
                            _buildTimePill(title: "Ends", time: projectedEndTime)
                        }

                        // Ring + remaining
                        ZStack {
                            Circle().stroke(Color("AppTextPrimary").opacity(0.12), lineWidth: 18)

                            // Zone markers
                            ForEach(FastingZone.allCases, id: \.self) { zone in
                                if (zone.startHour / log.goalHours) < 1.0 {
                                    Circle()
                                        .fill(zone.color)
                                        .frame(width: 8, height: 8)
                                        .offset(y: -110)
                                        .rotationEffect(.degrees((zone.startHour / log.goalHours) * 360))
                                }
                            }

                            Circle()
                                .trim(from: 0, to: progress)
                                .stroke(
                                    AngularGradient(
                                        gradient: Gradient(colors: [Color("AppPrimaryAccent"), Color("AppSecondaryAccent")]),
                                        center: .center
                                    ),
                                    style: StrokeStyle(lineWidth: 18, lineCap: .round)
                                )
                                .rotationEffect(.degrees(-90))
                                .animation(.easeOut(duration: 0.8), value: progress)

                            VStack(spacing: 6) {
                                Text(progress >= 1.0 ? "Goal Reached" : "Remaining")
                                    .font(.caption).bold()
                                    .foregroundStyle(progress >= 1.0 ? .green : Color("AppTextPrimary").opacity(0.65))
                                Text(FastingManager.formatTime(seconds: remainingTime))
                                    .font(.title2).bold()
                                    .foregroundStyle(Color("AppTextPrimary"))
                                Text("\(Int(progress * 100))%")
                                    .font(.caption)
                                    .foregroundStyle(Color("AppTextPrimary").opacity(0.6))
                            }
                        }
                        .frame(width: 230, height: 230)

                        // Zone description like macro cards
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Current Zone")
                                .font(.headline)
                                .foregroundStyle(Color("AppTextPrimary").opacity(0.85))
                            Text(fastingManager.currentZone.name)
                                .font(.title3.bold())
                                .foregroundStyle(fastingManager.currentZone.color)
                            Text(fastingManager.currentZone.description)
                                .font(.callout)
                                .foregroundStyle(Color("AppTextPrimary").opacity(0.75))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal, 20)

                // End Button
                Button {
                    fastingManager.endFast()
                } label: {
                    Text("End Fast")
                        .font(.headline).bold()
                        .foregroundColor(.black)
                        .padding()
                        .frame(maxWidth: 250)
                        .background(Color("AppSecondaryAccent"))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 10)
        } else {
            EmptyView()
        }
    }

    // Helper for Start/End times
    @ViewBuilder
    private func _buildTimeBlock(title: String, time: Date) -> some View {
        _buildTimePill(title: title, time: time)
    }

    private func _buildTimePill(title: String, time: Date) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label {
                Text(time, format: .dateTime.hour().minute())
                    .font(.headline)
                    .foregroundStyle(Color("AppTextPrimary"))
            } icon: {
                Image(systemName: title.lowercased().contains("start") ? "play.fill" : "flag.checkered")
                    .font(.caption)
                    .foregroundStyle(Color("AppSecondaryAccent"))
            }
            .labelStyle(.titleAndIcon)

            Text(title.uppercased())
                .font(.caption2)
                .foregroundStyle(Color("AppTextPrimary").opacity(0.6))
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color("AppTextPrimary").opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Goal Selection View
    @ViewBuilder
    private func _buildGoalSelectionView() -> some View {

        // Calculate the eating window based on the current time and selected goal
        let eatingWindowHours = 24.0 - selectedGoal

        VStack(spacing: 30) {

            FrostedGlassContainer {
                VStack(spacing: 20) {

                    Text("\(Int(selectedGoal)):\(Int(eatingWindowHours))") // e.g., 16:8
                        .font(.system(size: 40, weight: .bold))
                        .foregroundStyle(Color("AppPrimaryAccent"))

                    // Goal Picker
                    Picker("Goal Hours", selection: $selectedGoal) {
                        ForEach([12.0, 14.0, 16.0, 18.0, 20.0, 24.0], id: \.self) { hour in
                            Text("\(Int(hour)) hours").tag(hour)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 120)
                    .labelsHidden()
                }
                .padding(.vertical)
            }
            .padding(.horizontal, 24)

            // Eating Window Information
            FrostedGlassContainer {
                VStack(spacing: 10) {
                    Text("Your Eating Window")
                        .font(.headline)
                        .foregroundStyle(Color("AppTextPrimary"))

                    Text("Your fast will end today at:")
                        .font(.subheadline)
                        .foregroundStyle(Color("AppTextPrimary").opacity(0.7))

                    Text("\(Date().addingTimeInterval(selectedGoal * 3600), style: .time)")
                        .font(.title2).bold()
                        .foregroundStyle(Color("AppSecondaryAccent"))
                        .padding(.bottom, 5)

                    Text("After this, your **\(Int(eatingWindowHours))** hour eating window begins.")
                        .font(.caption)
                        .foregroundStyle(Color("AppTextPrimary").opacity(0.6))
                }
            }
            .padding(.horizontal, 24)

            // Start Button
            Button {
                fastingManager.startFast(goalHours: selectedGoal)
            } label: {
                Text("Start Fasting (\(Int(selectedGoal))h)")
                    .font(.headline).bold()
                    .foregroundColor(.black)
                    .padding()
                    .frame(maxWidth: 250)
                    .background(Color("AppSecondaryAccent"))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 20)
    }

    // MARK: - Background Functions

    @ViewBuilder
    private func _buildDynamicBackground() -> some View {
        ZStack {
            Color("AppPrimaryDark", bundle: nil).ignoresSafeArea()
            RadialGradient(gradient: Gradient(colors: [Color("AppSecondaryAccent").opacity(0.3), .clear]), center: .topLeading, startRadius: 50, endRadius: 450)
                .offset(offset1).offset(x: -150, y: -150).ignoresSafeArea()
            RadialGradient(gradient: Gradient(colors: [Color("AppPrimaryAccent").opacity(0.4), .clear]), center: .bottomTrailing, startRadius: 100, endRadius: 500)
                .offset(offset2).offset(x: 100, y: 150).ignoresSafeArea()
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

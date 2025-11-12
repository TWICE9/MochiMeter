// Screens/FastingScreen.swift

import SwiftUI
import SwiftData

struct FastingScreen: View {
    
    // 1. Change from @StateObject to @EnvironmentObject
    @EnvironmentObject private var manager: FastingManager
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedGoal: Double = 16.0
    @State private var dialRotation: Double = 0
    
    private var primaryTextColor: Color {
        colorScheme == .dark ? .white : Color(red: 30/255, green: 30/255, blue: 36/255)
    }
    
    private var secondaryTextColor: Color {
        colorScheme == .dark ? .white.opacity(0.7) : Color(red: 120/255, green: 120/255, blue: 130/255)
    }
    
    private var backgroundColor: Color {
        colorScheme == .dark ? Color("AppPrimaryDark") : Color(red: 244/255, green: 245/255, blue: 247/255)
    }
    
    private var cardBorderColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.08)
    }
    
    private var cardFillColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.white
    }
    
    private var cardShadowColor: Color {
        colorScheme == .dark ? Color.black.opacity(0.3) : Color.black.opacity(0.08)
    }
    
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
                        .foregroundColor(primaryTextColor.opacity(colorScheme == .dark ? 1 : 0.7))
                        
                        Text("Fasting Timer")
                            .font(.system(size: 40, weight: .heavy, design: .rounded))
                            .foregroundColor(primaryTextColor)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.top, 60)
                    
                    // --- Main Timer Display ---
                    if manager.timerRunning {
                        _buildActiveTimerView()
                    } else {
                        _buildGoalSelectionView()
                    }
                    
                    Spacer()
                }
            }
        }
        .scrollIndicators(.hidden)
        .scrollContentBackground(.hidden)
        .ignoresSafeArea(edges: .top)
        .onAppear {
            if manager.timerRunning {
                manager.timeElapsed = Date().timeIntervalSince(manager.currentLog!.startTime)
            }
        }
    }

    // MARK: - Active View
    @ViewBuilder
    private func _buildActiveTimerView() -> some View {
        if let log = manager.currentLog {
            let progress = manager.timeElapsed / log.goalDuration
            let remainingTime = max(0, log.goalDuration - manager.timeElapsed)
            let projectedEndTime = log.startTime.addingTimeInterval(log.goalDuration)
            
            VStack(spacing: 30) {
                
                HStack(spacing: 20) {
                    _buildTimeBlock(title: "Start Time", time: log.startTime)
                    _buildTimeBlock(title: "Projected End", time: projectedEndTime)
                }
                .padding(.horizontal, 24)
                
                Text("TIME ELAPSED")
                    .font(.headline)
                    .foregroundStyle(secondaryTextColor)
                
                Text(FastingManager.formatTime(seconds: manager.timeElapsed))
                    .font(.system(size: 60, weight: .thin, design: .monospaced))
                    .foregroundStyle(Color("AppSecondaryAccent"))
                
                ZStack {
                    Circle().stroke(primaryTextColor.opacity(0.15), lineWidth: 20)
                    
                    // Fasting Zone Markers
                    ForEach(FastingZone.allCases, id: \.self) { zone in
                        if (zone.startHour / log.goalHours) < 1.0 {
                            Circle()
                                .fill(zone.color)
                                .frame(width: 10, height: 10)
                                .offset(y: -125)
                                .rotationEffect(.degrees((zone.startHour / log.goalHours) * 360))
                        }
                    }
                    
                    // Progress Arc
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(
                            Color("AppPrimaryAccent"),
                            style: StrokeStyle(lineWidth: 20, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 1), value: progress)
                    
                    VStack {
                        Text(progress >= 1.0 ? "GOAL REACHED" : "REMAINING")
                            .font(.caption).bold()
                            .foregroundStyle(progress >= 1.0 ? .green : secondaryTextColor)
                        
                        Text(FastingManager.formatTime(seconds: remainingTime))
                            .font(.title2).bold()
                            .foregroundStyle(primaryTextColor)
                    }
                }
                .frame(width: 250, height: 250)
                
                _adaptiveCard {
                    VStack(spacing: 8) {
                        Text("CURRENT ZONE: \(manager.currentZone.name)")
                            .font(.headline)
                            .foregroundStyle(manager.currentZone.color)
                        Text(manager.currentZone.description)
                            .font(.caption)
                            .foregroundStyle(secondaryTextColor)
                            .multilineTextAlignment(.center)
                            .frame(height: 50)
                    }
                }
                .padding(.horizontal, 24)
                
                // End Button
                Button {
                    manager.endFast()
                } label: {
                    Text("End Fast")
                        .font(.headline).bold()
                        .foregroundColor(colorScheme == .dark ? .black : .white)
                        .padding()
                        .frame(maxWidth: 250)
                        .background(Color("AppSecondaryAccent"))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                // ⭐️ FIX: Removed .buttonStyle(ScaleEffectOnTap()) ⭐️
                .buttonStyle(.plain)

            }
            .padding(.top, 20)
        } else {
            EmptyView()
        }
    }
    
    // Helper for Start/End times
    @ViewBuilder
    private func _buildTimeBlock(title: String, time: Date) -> some View {
        _adaptiveCard {
            VStack {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(secondaryTextColor)
                Text(time, format: .dateTime.hour().minute())
                    .font(.title3).bold()
                    .foregroundStyle(primaryTextColor)
            }
            .frame(maxWidth: .infinity)
        }
    }
    
    // MARK: - Goal Selection View (UPDATED)
    @ViewBuilder
    private func _buildGoalSelectionView() -> some View {
        
        // Calculate the eating window based on the current time and selected goal
        let eatingWindowHours = 24.0 - selectedGoal
        
        VStack(spacing: 40) {
            
            Text("Select Fasting Goal")
                .font(.title2).bold()
                .foregroundStyle(primaryTextColor)
            
            _adaptiveCard {
                VStack(spacing: 20) {

                    Text("\(Int(selectedGoal)):\(Int(eatingWindowHours))") // e.g., 16:8
                        .font(.system(size: 50, weight: .bold))
                        .foregroundStyle(Color("AppPrimaryAccent"))

                    Text("hours fasting")
                        .font(.caption)
                        .foregroundStyle(secondaryTextColor)

                    // Rotary Dial
                    _buildRotaryDial()
                }
                .padding(.vertical, 30)
            }
            .padding(.horizontal, 24)
            
            // ⭐️ NEW: Eating Window Information ⭐️
            _adaptiveCard {
                VStack(spacing: 10) {
                    Text("Your Eating Window")
                        .font(.headline)
                        .foregroundStyle(primaryTextColor.opacity(colorScheme == .dark ? 1 : 0.8))
                    
                    Text("Your fast will end today at:")
                        .font(.subheadline)
                        .foregroundStyle(secondaryTextColor)
                    
                    Text("\(Date().addingTimeInterval(selectedGoal * 3600), style: .time)")
                        .font(.title2).bold()
                        .foregroundStyle(Color("AppSecondaryAccent"))
                        .padding(.bottom, 5)
                        
                    Text("After this, your **\(Int(eatingWindowHours))** hour eating window begins.")
                        .font(.caption)
                        .foregroundStyle(secondaryTextColor)
                }
            }
            .padding(.horizontal, 24)

            // Start Button
            Button {
                manager.startFast(goalHours: selectedGoal)
            } label: {
                Text("Start Fasting (\(Int(selectedGoal))h)")
                    .font(.headline).bold()
                    .foregroundColor(colorScheme == .dark ? .black : .white)
                    .padding()
                    .frame(maxWidth: 250)
                    .background(Color("AppSecondaryAccent"))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            // ⭐️ FIX: Removed .buttonStyle(ScaleEffectOnTap()) ⭐️
            .buttonStyle(.plain)

        }
        .padding(.top, 40)
    }

    // MARK: - Rotary Dial
    @ViewBuilder
    private func _buildRotaryDial() -> some View {
        let hours = [12.0, 14.0, 16.0, 18.0, 20.0, 24.0]
        let radius: CGFloat = 120

        GeometryReader { geometry in
            ZStack {
                // Semi-circle background arc
                Path { path in
                    path.addArc(
                        center: CGPoint(x: geometry.size.width / 2, y: geometry.size.height - 20),
                        radius: radius,
                        startAngle: .degrees(180),
                        endAngle: .degrees(0),
                        clockwise: false
                    )
                }
                .stroke(primaryTextColor.opacity(0.2), lineWidth: 3)

                // Tick marks and hour labels
                ForEach(Array(hours.enumerated()), id: \.offset) { index, hour in
                    let angle = angleForHour(hour: hour, hours: hours)
                    let tickRadius = radius - 15
                    let labelRadius = radius - 45

                    // Tick marks
                    Path { path in
                        let startPoint = pointOnCircle(
                            center: CGPoint(x: geometry.size.width / 2, y: geometry.size.height - 20),
                            radius: radius - 5,
                            angle: angle
                        )
                        let endPoint = pointOnCircle(
                            center: CGPoint(x: geometry.size.width / 2, y: geometry.size.height - 20),
                            radius: tickRadius,
                            angle: angle
                        )
                        path.move(to: startPoint)
                        path.addLine(to: endPoint)
                    }
                    .stroke(primaryTextColor.opacity(0.5), lineWidth: 2)

                    // Hour labels
                    Text("\(Int(hour))")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(primaryTextColor)
                        .position(
                            pointOnCircle(
                                center: CGPoint(x: geometry.size.width / 2, y: geometry.size.height - 20),
                                radius: labelRadius,
                                angle: angle
                            )
                        )
                }

                // Dial indicator (like the finger stopper on old phones)
                let currentAngle = angleForHour(hour: selectedGoal, hours: hours)
                Circle()
                    .fill(Color("AppSecondaryAccent"))
                    .frame(width: 30, height: 30)
                    .overlay(
                        Circle()
                            .stroke(colorScheme == .dark ? Color.white : primaryTextColor, lineWidth: 3)
                    )
                    .shadow(color: Color("AppSecondaryAccent").opacity(0.5), radius: 10)
                    .position(
                        pointOnCircle(
                            center: CGPoint(x: geometry.size.width / 2, y: geometry.size.height - 20),
                            radius: radius,
                            angle: currentAngle
                        )
                    )
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                updateSelectedGoal(
                                    location: value.location,
                                    center: CGPoint(x: geometry.size.width / 2, y: geometry.size.height - 20),
                                    hours: hours
                                )
                            }
                    )
            }
        }
        .frame(height: 140)
    }

    // Helper to calculate angle for a given hour
    private func angleForHour(hour: Double, hours: [Double]) -> Double {
        guard let index = hours.firstIndex(of: hour) else { return 180 }
        let totalSteps = hours.count - 1
        let stepAngle = 180.0 / Double(totalSteps)
        return 180.0 + (stepAngle * Double(index))
    }

    // Helper to calculate point on circle
    private func pointOnCircle(center: CGPoint, radius: CGFloat, angle: Double) -> CGPoint {
        let radians = angle * .pi / 180
        return CGPoint(
            x: center.x + radius * CGFloat(Foundation.cos(radians)),
            y: center.y + radius * CGFloat(Foundation.sin(radians))
        )
    }

    // Update selected goal based on drag position
    private func updateSelectedGoal(location: CGPoint, center: CGPoint, hours: [Double]) {
        let dx = location.x - center.x
        let dy = location.y - center.y
        var angle = atan2(dy, dx) * 180 / .pi

        // Normalize angle to 180-360 range (bottom semi-circle)
        if angle < 0 {
            angle += 360
        }

        // Clamp to semi-circle range
        angle = max(180, min(360, angle))

        // Map angle to hours
        let normalizedAngle = (angle - 180) / 180 // 0 to 1
        let stepSize = 1.0 / Double(hours.count - 1)
        let index = Int(round(normalizedAngle / stepSize))
        let clampedIndex = max(0, min(hours.count - 1, index))

        selectedGoal = hours[clampedIndex]

        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }

    // MARK: - Background Helper
    @ViewBuilder
    private func _buildDynamicBackground() -> some View {
        let accentOpacity = colorScheme == .dark ? 0.3 : 0.15
        let primaryOpacity = colorScheme == .dark ? 0.4 : 0.08
        ZStack {
            backgroundColor.ignoresSafeArea()
            RadialGradient(gradient: Gradient(colors: [Color("AppSecondaryAccent").opacity(accentOpacity), .clear]), center: .topLeading, startRadius: 80, endRadius: 500)
                .offset(x: -150, y: -150).ignoresSafeArea()
            RadialGradient(gradient: Gradient(colors: [Color("AppPrimaryAccent").opacity(primaryOpacity), .clear]), center: .bottomTrailing, startRadius: 120, endRadius: 520)
                .offset(x: 100, y: 150).ignoresSafeArea()
        }
        .blur(radius: colorScheme == .dark ? 60 : 40)
    }

    @ViewBuilder
    private func _adaptiveCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(cardFillColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(cardBorderColor, lineWidth: 1)
                    )
            )
            .shadow(color: cardShadowColor, radius: colorScheme == .dark ? 18 : 10, y: colorScheme == .dark ? 0 : 6)
    }
}

// ⚠️ Note: ScaleEffectOnPress definition (the replacement for the old style)
// needs to be included in a file accessible by FastingScreen.swift (e.g., a shared helper file).

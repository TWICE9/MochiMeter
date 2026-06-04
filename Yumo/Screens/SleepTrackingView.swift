// Screens/SleepTrackingView.swift

import SwiftUI
import Charts

struct SleepTrackingView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var themeManager: ThemeManager
    
    @ObservedObject var healthKit = HealthKitManager.shared
    
    @State private var isLoading = true
    @State private var selectedSleepDay: SleepData? = nil
    
    // Background animation
    @State private var offset1: CGSize = .zero
    @State private var offset2: CGSize = .zero
    
    // Adaptive Colors
    private var primaryTextColor: Color {
        colorScheme == .dark ? .white : Color(red: 32/255, green: 32/255, blue: 38/255)
    }
    
    private var secondaryTextColor: Color {
        colorScheme == .dark ? .white.opacity(0.7) : Color(red: 120/255, green: 120/255, blue: 130/255)
    }
    
    private var primaryAccent: Color {
        colorScheme == .dark ? themeManager.currentTheme.darkPrimaryColor : themeManager.currentTheme.primaryColor
    }
    
    // Sleep stage colors
    private let deepColor = Color(red: 0.2, green: 0.3, blue: 0.9)
    private let coreColor = Color(red: 0.4, green: 0.5, blue: 0.95)
    private let remColor = Color(red: 0.6, green: 0.4, blue: 0.9)
    private let awakeColor = Color(red: 0.95, green: 0.6, blue: 0.3)
    
    var body: some View {
        ZStack {
                _buildBackground()
                
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Header
                        HStack {
                            Text("Sleep & Recovery")
                                .font(.largeTitle.bold())
                                .foregroundStyle(primaryTextColor)
                            Spacer()
                            Button(action: { dismiss() }) {
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(secondaryTextColor)
                                    .padding(8)
                                    .background(Circle().fill(secondaryTextColor.opacity(0.1)))
                            }
                        }
                        .padding(.horizontal, 4) // Slight inset to align with cards visually
                        
                        // MARK: - Last Night Summary
                        if let sleep = healthKit.lastNightSleep {
                            _buildLastNightCard(sleep)
                        } else if !isLoading {
                            _buildNoDataCard()
                        }
                        
                        // MARK: - Recovery Score
                        if healthKit.recoveryScore != nil {
                            _buildRecoveryCard()
                        }
                        
                        // MARK: - Sleep Stages Breakdown
                        if let sleep = healthKit.lastNightSleep {
                            _buildStagesCard(sleep)
                        }
                        
                        // MARK: - Heart Metrics
                        _buildHeartMetricsCard()
                        
                        // MARK: - Weekly Sleep Trend
                        if !healthKit.weeklySleep.isEmpty {
                            _buildWeeklyTrendCard()
                        }
                        
                        // MARK: - Sleep Tips
                        _buildTipsCard()
                        
                        Color.clear.frame(height: 40)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    .readableContentColumn(640)
                }
            }
            .task {
                // Re-request authorization to ensure new health types (sleep, HRV, resting HR)
                // are authorized for existing users who onboarded before these were added.
                // HealthKit only prompts for types not yet authorized, so this is safe to call every time.
                try? await healthKit.requestAuthorization()
                
                await healthKit.fetchRecoveryData()
                withAnimation(.easeOut(duration: 0.5)) {
                    isLoading = false
                }
            }

    }
    
    // MARK: - Last Night Summary Card
    
    @ViewBuilder
    private func _buildLastNightCard(_ sleep: SleepData) -> some View {
        FrostedGlassContainer {
            VStack(spacing: 16) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Last Night")
                            .font(.subheadline)
                            .foregroundStyle(secondaryTextColor)
                        
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(SleepData.formatDuration(sleep.totalSleepSeconds))
                                .font(.system(size: 42, weight: .bold, design: .rounded))
                                .foregroundStyle(primaryTextColor)
                            
                            Text("total sleep")
                                .font(.subheadline)
                                .foregroundStyle(secondaryTextColor)
                        }
                    }
                    
                    Spacer()
                    
                    // Quality Badge
                    VStack(spacing: 4) {
                        ZStack {
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        colors: sleepQualityGradient(sleep),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 4
                                )
                                .frame(width: 64, height: 64)
                            
                            Text("\(Int(sleep.sleepEfficiency))")
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundStyle(primaryTextColor)
                        }
                        
                        Text("Efficiency")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(secondaryTextColor)
                    }
                }
                
                // Bedtime / Wake
                HStack(spacing: 24) {
                    _timeChip(
                        icon: "moon.fill",
                        label: "Bedtime",
                        time: sleep.bedtime,
                        color: .indigo
                    )
                    
                    _timeChip(
                        icon: "sun.and.horizon.fill",
                        label: "Wake Up",
                        time: sleep.wakeTime,
                        color: .orange
                    )
                    
                    Spacer()
                }
                
                // Sleep stage bar
                if sleep.totalSleepSeconds > 0 {
                    _buildStageBar(sleep)
                }
            }
        }
    }
    
    @ViewBuilder
    private func _timeChip(icon: String, label: String, time: Date, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(color)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(secondaryTextColor)
                
                Text(time, style: .time)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(primaryTextColor)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(color.opacity(0.1))
        )
    }
    
    @ViewBuilder
    private func _buildStageBar(_ sleep: SleepData) -> some View {
        let total = sleep.totalSleepSeconds + sleep.awakeSeconds
        
        if total > 0 {
            VStack(alignment: .leading, spacing: 8) {
                GeometryReader { geo in
                    HStack(spacing: 1.5) {
                        if sleep.deepSleepSeconds > 0 {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(deepColor)
                                .frame(width: geo.size.width * (sleep.deepSleepSeconds / total))
                        }
                        if sleep.coreSleepSeconds > 0 {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(coreColor)
                                .frame(width: geo.size.width * (sleep.coreSleepSeconds / total))
                        }
                        if sleep.remSleepSeconds > 0 {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(remColor)
                                .frame(width: geo.size.width * (sleep.remSleepSeconds / total))
                        }
                        if sleep.awakeSeconds > 0 {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(awakeColor)
                                .frame(width: geo.size.width * (sleep.awakeSeconds / total))
                        }
                    }
                }
                .frame(height: 10)
                .clipShape(RoundedRectangle(cornerRadius: 5))
                
                // Legend
                HStack(spacing: 12) {
                    _legendDot(color: deepColor, label: "Deep")
                    _legendDot(color: coreColor, label: "Core")
                    _legendDot(color: remColor, label: "REM")
                    _legendDot(color: awakeColor, label: "Awake")
                }
            }
            .drawingGroup() // Optimize rendering of the stage bar
        }
    }
    
    @ViewBuilder
    private func _legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(secondaryTextColor)
        }
    }
    
    // MARK: - Sleep Stages Detail Card
    
    @ViewBuilder
    private func _buildStagesCard(_ sleep: SleepData) -> some View {
        FrostedGlassContainer {
            VStack(alignment: .leading, spacing: 16) {
                Text("Sleep Stages")
                    .font(.headline)
                    .foregroundStyle(primaryTextColor)
                
                _stageRow(
                    icon: "waveform.path",
                    label: "Deep Sleep",
                    duration: sleep.deepSleepSeconds,
                    total: sleep.totalSleepSeconds,
                    color: deepColor,
                    idealRange: "1-2h recommended"
                )
                
                _stageRow(
                    icon: "waveform",
                    label: "Core Sleep",
                    duration: sleep.coreSleepSeconds,
                    total: sleep.totalSleepSeconds,
                    color: coreColor,
                    idealRange: "3-4h typical"
                )
                
                _stageRow(
                    icon: "brain.head.profile.fill",
                    label: "REM Sleep",
                    duration: sleep.remSleepSeconds,
                    total: sleep.totalSleepSeconds,
                    color: remColor,
                    idealRange: "1.5-2h ideal"
                )
                
                _stageRow(
                    icon: "eye",
                    label: "Awake",
                    duration: sleep.awakeSeconds,
                    total: sleep.totalSleepSeconds + sleep.awakeSeconds,
                    color: awakeColor,
                    idealRange: "< 30m ideal"
                )
                
                Divider().background(primaryTextColor.opacity(0.1))
                
                _stageRow(
                    icon: "bed.double.fill",
                    label: "Time in Bed",
                    duration: sleep.timeInBedSeconds,
                    total: 0,  // Don't show percentage
                    color: .gray,
                    idealRange: ""
                )
            }
        }
    }
    
    @ViewBuilder
    private func _stageRow(icon: String, label: String, duration: TimeInterval, total: TimeInterval, color: Color, idealRange: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 28)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(primaryTextColor)
                
                if !idealRange.isEmpty {
                    Text(idealRange)
                        .font(.system(size: 10))
                        .foregroundStyle(secondaryTextColor)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(SleepData.formatDuration(duration))
                    .font(.subheadline.weight(.bold).monospacedDigit())
                    .foregroundStyle(primaryTextColor)
                
                if total > 0 {
                    Text("\(Int((duration / total) * 100))%")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(color)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Recovery Score Card
    
    @ViewBuilder
    private func _buildRecoveryCard() -> some View {
        let score = healthKit.recoveryScore ?? 0
        let status = healthKit.recoveryStatus
        
        FrostedGlassContainer {
            VStack(spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Recovery Score")
                            .font(.headline)
                            .foregroundStyle(primaryTextColor)
                        
                        Text(status.message)
                            .font(.caption)
                            .foregroundStyle(secondaryTextColor)
                            .lineLimit(2)
                    }
                    
                    Spacer()
                    
                    // Circular score
                    ZStack {
                        Circle()
                            .stroke(recoveryColor(score).opacity(0.2), lineWidth: 6)
                            .frame(width: 72, height: 72)
                        
                        Circle()
                            .trim(from: 0, to: Double(score) / 100.0)
                            .stroke(
                                recoveryColor(score),
                                style: StrokeStyle(lineWidth: 6, lineCap: .round)
                            )
                            .frame(width: 72, height: 72)
                            .rotationEffect(.degrees(-90))
                        
                        VStack(spacing: 0) {
                            Text("\(score)")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundStyle(primaryTextColor)
                            
                            Text(status.label)
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(recoveryColor(score))
                        }
                    }
                    .padding(6)
                    .drawingGroup() // Optimize rendering of the circular score
                }
                
                // What contributes
                HStack(spacing: 12) {
                    _recoveryFactor(
                        icon: "moon.zzz.fill",
                        label: "Sleep",
                        value: healthKit.lastNightSleep.map { SleepData.formatDuration($0.totalSleepSeconds) } ?? "—",
                        color: .indigo
                    )
                    
                    _recoveryFactor(
                        icon: "waveform.path.ecg",
                        label: "HRV",
                        value: healthKit.latestHRV.map { "\(Int($0))ms" } ?? "—",
                        color: .pink
                    )
                    
                    _recoveryFactor(
                        icon: "heart.fill",
                        label: "Rest HR",
                        value: healthKit.latestRestingHR.map { "\(Int($0))bpm" } ?? "—",
                        color: .red
                    )
                }
            }
        }
    }
    
    @ViewBuilder
    private func _recoveryFactor(icon: String, label: String, value: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(color)
            
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(primaryTextColor)
            
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(secondaryTextColor)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(color.opacity(0.08))
        )
    }
    
    @ViewBuilder
    private func _buildHeartMetricsCard() -> some View {
        FrostedGlassContainer {
            VStack(alignment: .leading, spacing: 16) {
                Text("Heart Metrics")
                    .font(.headline)
                    .foregroundStyle(primaryTextColor)
                
                HStack(spacing: 16) {
                    // HRV
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "waveform.path.ecg")
                                .foregroundStyle(.pink)
                            Text("HRV")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(secondaryTextColor)
                        }
                        
                        if let hrv = healthKit.latestHRV {
                            HStack(alignment: .firstTextBaseline, spacing: 2) {
                                Text("\(Int(hrv))")
                                    .font(.system(size: 32, weight: .bold, design: .rounded))
                                    .foregroundStyle(primaryTextColor)
                                Text("ms")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(secondaryTextColor)
                            }
                            
                            if let avg = healthKit.averageHRV {
                                let diff = hrv - avg
                                let isUp = diff >= 0
                                HStack(spacing: 4) {
                                    Image(systemName: isUp ? "arrow.up.right" : "arrow.down.right")
                                        .font(.system(size: 10, weight: .bold))
                                    Text("\(abs(Int(diff)))ms vs avg")
                                        .font(.system(size: 11, weight: .medium))
                                }
                                .foregroundStyle(isUp ? .green : .orange)
                            }
                        } else {
                            Text("No data")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(secondaryTextColor)
                            
                            Text("Needs Apple Watch")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(secondaryTextColor.opacity(0.7))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Divider()
                        .frame(height: 60)
                    
                    // Resting HR
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "heart.fill")
                                .foregroundStyle(.red)
                            Text("Resting HR")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(secondaryTextColor)
                        }
                        
                        if let rhr = healthKit.latestRestingHR {
                            HStack(alignment: .firstTextBaseline, spacing: 2) {
                                Text("\(Int(rhr))")
                                    .font(.system(size: 32, weight: .bold, design: .rounded))
                                    .foregroundStyle(primaryTextColor)
                                Text("bpm")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(secondaryTextColor)
                            }
                            
                            Text(restingHRLabel(rhr))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(restingHRColor(rhr))
                        } else {
                            Text("No data")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(secondaryTextColor)
                            
                            Text("Needs Apple Watch")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(secondaryTextColor.opacity(0.7))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                // HRV Trend Mini Chart
                if healthKit.weeklyHRV.count >= 2 {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("7-Day HRV Trend")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(secondaryTextColor)
                        
                        Chart {
                            ForEach(Array(healthKit.weeklyHRV.enumerated()), id: \.offset) { _, point in
                                LineMark(
                                    x: .value("Date", point.date),
                                    y: .value("HRV", point.hrv)
                                )
                                .foregroundStyle(.pink.gradient)
                                .interpolationMethod(.catmullRom)
                                
                                AreaMark(
                                    x: .value("Date", point.date),
                                    y: .value("HRV", point.hrv)
                                )
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.pink.opacity(0.3), .pink.opacity(0.0)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .interpolationMethod(.catmullRom)
                            }
                        }
                        .chartYAxis {
                            AxisMarks(position: .leading) { value in
                                AxisValueLabel {
                                    Text("\(value.as(Double.self).map { Int($0) } ?? 0)")
                                        .font(.system(size: 9))
                                        .foregroundStyle(secondaryTextColor)
                                }
                            }
                        }
                        .chartXAxis {
                            AxisMarks(values: .stride(by: .day)) { value in
                                AxisValueLabel {
                                    if let date = value.as(Date.self) {
                                        Text(date, format: .dateTime.weekday(.abbreviated))
                                            .font(.system(size: 9))
                                            .foregroundStyle(secondaryTextColor)
                                    }
                                }
                            }
                        }
                        .frame(height: 100)
                        .drawingGroup() // Optimize rendering of the HRV trend chart
                    }
                }
                
                // HRV explainer when missing
                if healthKit.latestHRV == nil {
                    VStack(alignment: .leading, spacing: 8) {
                        Divider().background(primaryTextColor.opacity(0.1))
                        
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "info.circle.fill")
                                .foregroundStyle(.blue)
                                .font(.system(size: 14))
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("How to get HRV data")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(primaryTextColor)
                                
                                Text("HRV is measured by Apple Watch during sleep or Breathe/Mindfulness sessions. Make sure sleep tracking is enabled on your watch.")
                                    .font(.system(size: 11))
                                    .foregroundStyle(secondaryTextColor)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        
                        Button {
                            if let url = URL(string: "x-apple-health://") {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "heart.fill")
                                    .font(.system(size: 11))
                                Text("Check in Apple Health")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .foregroundStyle(.pink)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(Color.pink.opacity(0.1))
                            )
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Weekly Sleep Trend
    
    @ViewBuilder
    private func _buildWeeklyTrendCard() -> some View {
        FrostedGlassContainer {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Weekly Sleep")
                        .font(.headline)
                        .foregroundStyle(primaryTextColor)
                    
                    Spacer()
                    
                    if !healthKit.weeklySleep.isEmpty {
                        let avg = healthKit.weeklySleep.reduce(0) { $0 + $1.totalSleepHours } / Double(healthKit.weeklySleep.count)
                        Text("Avg: \(String(format: "%.1f", avg))h")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(primaryAccent)
                    }
                }
                
                Chart {
                    ForEach(healthKit.weeklySleep) { day in
                        BarMark(
                            x: .value("Day", day.date, unit: .day),
                            y: .value("Hours", day.totalSleepHours)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [deepColor, coreColor],
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                        .cornerRadius(6)
                    }
                    
                    // 7-hour recommendation line
                    RuleMark(y: .value("Recommended", 7))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 3]))
                        .foregroundStyle(secondaryTextColor.opacity(0.5))
                        .annotation(position: .leading) {
                            Text("7h")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(secondaryTextColor)
                        }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisValueLabel {
                            Text("\(value.as(Double.self).map { Int($0) } ?? 0)h")
                                .font(.system(size: 9))
                                .foregroundStyle(secondaryTextColor)
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { value in
                        AxisValueLabel {
                            if let date = value.as(Date.self) {
                                Text(date, format: .dateTime.weekday(.abbreviated))
                                    .font(.system(size: 10))
                                    .foregroundStyle(secondaryTextColor)
                            }
                        }
                    }
                }
                .frame(height: 160)
                .drawingGroup() // Optimize rendering of the weekly sleep trend chart
            }
        }
    }
    
    // MARK: - No Data Card
    
    @ViewBuilder
    private func _buildNoDataCard() -> some View {
        FrostedGlassContainer {
            VStack(spacing: 16) {
                Image(systemName: "moon.zzz.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.indigo, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                Text("No Sleep Data")
                    .font(.title3.bold())
                    .foregroundStyle(primaryTextColor)
                
                Text("Sleep data is automatically recorded by Apple Watch or compatible sleep trackers connected to Apple Health.")
                    .font(.subheadline)
                    .foregroundStyle(secondaryTextColor)
                    .multilineTextAlignment(.center)
                
                Button {
                    if let url = URL(string: "x-apple-health://") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    HStack {
                        Image(systemName: "heart.fill")
                        Text("Open Apple Health")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [.indigo, .purple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
                }
            }
            .padding(.vertical, 8)
        }
    }
    
    // MARK: - Tips Card
    
    @ViewBuilder
    private func _buildTipsCard() -> some View {
        FrostedGlassContainer {
            VStack(alignment: .leading, spacing: 12) {
                Text("Sleep Tips")
                    .font(.headline)
                    .foregroundStyle(primaryTextColor)
                
                VStack(alignment: .leading, spacing: 14) {
                    _tipRow(icon: "iphone.slash", text: "Avoid screens 30 min before bed", color: .red)
                    _tipRow(icon: "thermometer.medium", text: "Keep room temperature at 15-19°C (60-67°F)", color: .blue)
                    _tipRow(icon: "cup.and.saucer.fill", text: "No caffeine after 2 PM", color: .brown)
                    _tipRow(icon: "alarm.fill", text: "Maintain consistent sleep/wake times", color: .orange)
                    _tipRow(icon: "figure.run", text: "Exercise earlier in the day, not before bed", color: .green)
                }
            }
        }
    }
    
    @ViewBuilder
    private func _tipRow(icon: String, text: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(color.opacity(0.8))
                .frame(width: 20)
                
            Text(text)
                .font(.subheadline)
                .foregroundStyle(secondaryTextColor)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    
    // MARK: - Background
    
    @ViewBuilder
    private func _buildBackground() -> some View {
        ZStack {
            Color("AppPrimaryDark", bundle: nil).ignoresSafeArea()
            
            if colorScheme == .dark {
                RadialGradient(
                    gradient: Gradient(colors: [Color.indigo.opacity(0.2), .clear]),
                    center: .topLeading,
                    startRadius: 50,
                    endRadius: 450
                )
                .offset(offset1).offset(x: -100, y: -100)
                .ignoresSafeArea()
                
                RadialGradient(
                    gradient: Gradient(colors: [Color.purple.opacity(0.12), .clear]),
                    center: .bottomTrailing,
                    startRadius: 50,
                    endRadius: 400
                )
                .offset(offset2).offset(x: 100, y: 100)
                .ignoresSafeArea()
            } else {
                RadialGradient(
                    gradient: Gradient(colors: [Color.indigo.opacity(0.15), .clear]),
                    center: .topLeading,
                    startRadius: 50,
                    endRadius: 450
                )
                .offset(offset1).offset(x: -100, y: -100)
                .ignoresSafeArea()
                
                RadialGradient(
                    gradient: Gradient(colors: [Color.purple.opacity(0.1), .clear]),
                    center: .bottomTrailing,
                    startRadius: 50,
                    endRadius: 400
                )
                .offset(offset2).offset(x: 100, y: 100)
                .ignoresSafeArea()
            }
        }
        .blur(radius: 60)
        .onAppear {
            withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
                offset1 = CGSize(width: 60, height: 40)
            }
            withAnimation(.easeInOut(duration: 10).repeatForever(autoreverses: true)) {
                offset2 = CGSize(width: -80, height: -50)
            }
        }
    }
    
    // MARK: - Helpers
    
    private func sleepQualityGradient(_ sleep: SleepData) -> [Color] {
        switch sleep.sleepQualityColor {
        case "green": return [.green, .mint]
        case "yellow": return [.yellow, .orange]
        case "orange": return [.orange, .red]
        default: return [.red, .pink]
        }
    }
    
    private func recoveryColor(_ score: Int) -> Color {
        switch score {
        case 80...100: return .green
        case 60..<80: return .yellow
        case 40..<60: return .orange
        case 20..<40: return .red
        default: return .gray
        }
    }
    
    private func restingHRLabel(_ hr: Double) -> String {
        if hr <= 55 { return "Athletic" }
        if hr <= 65 { return "Good" }
        if hr <= 75 { return "Average" }
        if hr <= 85 { return "Above average" }
        return "Elevated"
    }
    
    private func restingHRColor(_ hr: Double) -> Color {
        if hr <= 55 { return .green }
        if hr <= 65 { return .mint }
        if hr <= 75 { return .yellow }
        if hr <= 85 { return .orange }
        return .red
    }
}

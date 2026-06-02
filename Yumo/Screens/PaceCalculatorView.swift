import SwiftUI
import SwiftData

// MARK: - Solve Target

private enum SolveTarget: String, CaseIterable, Identifiable {
    case distance, pace, time

    var id: String { rawValue }

    var label: String {
        switch self {
        case .distance: return "Distance"
        case .pace:     return "Pace"
        case .time:     return "Finish Time"
        }
    }

    var shortLabel: String {
        switch self {
        case .distance: return "Distance"
        case .pace:     return "Pace"
        case .time:     return "Time"
        }
    }

    var icon: String {
        switch self {
        case .distance: return "ruler"
        case .pace:     return "stopwatch"
        case .time:     return "flag.checkered"
        }
    }
}

// MARK: - Preset Distances

private struct PresetDistance: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let km: Double

    static let all: [PresetDistance] = [
        .init(name: "1K",   km: 1.0),
        .init(name: "1mi",  km: 1.609344),
        .init(name: "5K",   km: 5.0),
        .init(name: "10K",  km: 10.0),
        .init(name: "Half", km: 21.0975),
        .init(name: "Full", km: 42.195)
    ]
}

// MARK: - Conversion helpers

private enum PaceMath {
    static let mileInKm: Double = 1.609344

    static func toKm(_ value: Double, useMiles: Bool) -> Double {
        useMiles ? value * mileInKm : value
    }

    static func fromKm(_ km: Double, useMiles: Bool) -> Double {
        useMiles ? km / mileInKm : km
    }

    /// Format total seconds as h:mm:ss or mm:ss.
    static func formatDuration(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "—" }
        let total = Int(seconds.rounded())
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%d:%02d", m, s)
    }

    /// Format pace seconds as m:ss.
    static func formatPace(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds > 0 else { return "—" }
        let total = Int(seconds.rounded())
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - View

struct PaceCalculatorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var themeManager: ThemeManager

    @Query(sort: \PaceCalculation.timestamp, order: .reverse) private var history: [PaceCalculation]
    @Query private var allGoals: [UserGoals]

    @State private var solveTarget: SolveTarget = .time
    @State private var useMiles: Bool = false
    @State private var didApplyInitialUnits: Bool = false

    // Distance (stored in current display unit)
    @State private var distance: Double = 5.0

    // Pace: minutes + seconds per current unit
    @State private var paceMinutes: Int = 5
    @State private var paceSeconds: Int = 30

    // Time: hours + minutes + seconds
    @State private var timeHours: Int = 0
    @State private var timeMinutes: Int = 25
    @State private var timeSeconds: Int = 0

    @State private var showSavedToast: Bool = false
    @State private var showSplits: Bool = false

    /// Tracks running pace-wheel spin tasks so a fast double-tap on the unit
    /// toggle cancels the previous animation instead of stacking values.
    @State private var paceSpinTask: Task<Void, Never>? = nil

    @State private var recentRuns: [WorkoutSummary] = []
    @State private var selectedRunID: UUID?

    @FocusState private var distanceFieldFocused: Bool

    // MARK: - Adaptive colors

    private var primaryTextColor: Color {
        colorScheme == .dark ? .white : Color(red: 32/255, green: 32/255, blue: 38/255)
    }

    private var secondaryTextColor: Color {
        colorScheme == .dark ? .white.opacity(0.7) : Color(red: 120/255, green: 120/255, blue: 130/255)
    }

    private var tertiaryTextColor: Color {
        colorScheme == .dark ? .white.opacity(0.5) : Color(red: 150/255, green: 150/255, blue: 160/255)
    }

    // MARK: - Computed metrics

    private var unitLabel: String { useMiles ? "mi" : "km" }
    private var paceUnitLabel: String { useMiles ? "/mi" : "/km" }

    private var paceSecondsPerUnit: Double { Double(paceMinutes * 60 + paceSeconds) }
    private var timeTotalSeconds: Double { Double(timeHours * 3600 + timeMinutes * 60 + timeSeconds) }

    private var derivedTimeSeconds: Double {
        switch solveTarget {
        case .time:
            return distance * paceSecondsPerUnit
        case .pace, .distance:
            return timeTotalSeconds
        }
    }

    private var derivedPaceSecondsPerUnit: Double {
        switch solveTarget {
        case .pace:
            guard distance > 0 else { return 0 }
            return timeTotalSeconds / distance
        case .time, .distance:
            return paceSecondsPerUnit
        }
    }

    private var derivedDistance: Double {
        switch solveTarget {
        case .distance:
            guard paceSecondsPerUnit > 0 else { return 0 }
            return timeTotalSeconds / paceSecondsPerUnit
        case .time, .pace:
            return distance
        }
    }

    private var derivedPaceKmh: Double {
        let secPerUnit = derivedPaceSecondsPerUnit
        guard secPerUnit > 0 else { return 0 }
        let secPerKm = useMiles ? secPerUnit / PaceMath.mileInKm : secPerUnit
        return 3600.0 / secPerKm
    }

    // MARK: - Theming

    private var accentColor: Color {
        colorScheme == .dark
            ? themeManager.currentTheme.darkPrimaryColor
            : themeManager.currentTheme.primaryColor
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            DynamicBackgroundView()

            ScrollView {
                VStack(spacing: 18) {
                    unitToggle
                    solverCard
                    splitsDisclosure
                    recentRunsCard
                    historyCard

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 80)
            }
            .scrollIndicators(.hidden)

            if showSavedToast {
                VStack {
                    Spacer()
                    Text("Saved")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(Color.green))
                        .padding(.bottom, 40)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .navigationTitle("Pace Calculator")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    saveCalculation()
                } label: {
                    Image(systemName: "square.and.arrow.down")
                }
                .disabled(!canSave)
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    distanceFieldFocused = false
                }
            }
        }
        .onAppear {
            if !didApplyInitialUnits, let goals = allGoals.first {
                useMiles = goals.unitSystem == .imperial
                didApplyInitialUnits = true
            }
        }
        .onChange(of: distance)      { _, _ in clearRunSelection() }
        .onChange(of: paceMinutes)   { _, _ in clearRunSelection() }
        .onChange(of: paceSeconds)   { _, _ in clearRunSelection() }
        .onChange(of: timeHours)     { _, _ in clearRunSelection() }
        .onChange(of: timeMinutes)   { _, _ in clearRunSelection() }
        .onChange(of: timeSeconds)   { _, _ in clearRunSelection() }
        .onChange(of: solveTarget)   { _, _ in clearRunSelection() }
        .onChange(of: useMiles)      { _, _ in clearRunSelection() }
        .task {
            print("🏃 PaceCalculator: fetching recent runs from HealthKit…")
            try? await HealthKitManager.shared.requestAuthorization()
            let runs = await HealthKitManager.shared.fetchRecentRuns(limit: 10, daysBack: 90)
            await MainActor.run {
                recentRuns = runs
            }
        }
    }

    // MARK: - Glass card

    /// Swaps between km and mi while preserving the physical meaning of the
    /// values on screen — distance and pace get converted, so the run the
    /// user is calculating doesn't change. Time stays the same (unit-free).
    /// Lets users do "I saw a video where someone ran 5:00/mi — what's that
    /// in km?" without retyping anything.
    private func switchUnits(toMiles newValue: Bool) {
        guard newValue != useMiles else { return }

        let mile = PaceMath.mileInKm

        // Distance: km × 0.621 = mi, mi × 1.609 = km. The display Text uses
        // .contentTransition(.numericText) so this snap reads as a smooth
        // slot-machine roll inside the surrounding withAnimation block.
        if newValue {
            distance = distance / mile           // km → mi
        } else {
            distance = distance * mile           // mi → km
        }

        // Pace per unit: sec/km × 1.609 = sec/mi, sec/mi / 1.609 = sec/km.
        let totalPaceSec = paceMinutes * 60 + paceSeconds
        let convertedPaceSec: Int
        if newValue {
            convertedPaceSec = Int((Double(totalPaceSec) * mile).rounded())
        } else {
            convertedPaceSec = Int((Double(totalPaceSec) / mile).rounded())
        }
        let targetMinutes = max(0, min(29, convertedPaceSec / 60))
        let targetSeconds = max(0, min(59, convertedPaceSec % 60))

        // Wheel pickers ignore `withAnimation` for programmatic value changes
        // — they snap instantly. Step through values frame-by-frame so the
        // wheel actually spins to the target. Total spin caps at ~450ms.
        spinPaceWheel(toMinutes: targetMinutes, toSeconds: targetSeconds)

        // Time fields don't change — a 25-minute run is 25 minutes regardless.

        useMiles = newValue
    }

    /// Animates the two pace wheel pickers to a target by stepping their
    /// values one notch at a time. The spin runs in parallel for the minutes
    /// and seconds wheels, so a 5:30→8:51 conversion doesn't look like the
    /// minutes hand finishes before seconds even starts moving.
    private func spinPaceWheel(toMinutes targetMin: Int, toSeconds targetSec: Int) {
        paceSpinTask?.cancel()

        let startMin = paceMinutes
        let startSec = paceSeconds
        guard startMin != targetMin || startSec != targetSec else { return }

        // Cap the spin duration so very long jumps (e.g. 8:51 → 5:00) still
        // feel responsive. Each notch needs at least ~22 ms to render.
        let minSteps = abs(targetMin - startMin)
        let secSteps = abs(targetSec - startSec)
        let maxSteps = max(minSteps, secSteps, 1)
        let totalDuration: TimeInterval = 0.45
        let stepInterval = max(0.022, totalDuration / Double(maxSteps))

        paceSpinTask = Task { @MainActor in
            for step in 1...maxSteps {
                try? await Task.sleep(nanoseconds: UInt64(stepInterval * 1_000_000_000))
                if Task.isCancelled { return }
                // Eased progress (0..1) — heavier in the middle so the wheel
                // eases out as it nears the target rather than slamming.
                let raw = Double(step) / Double(maxSteps)
                let eased = 1 - pow(1 - raw, 2)  // quadratic ease-out

                let nextMin = startMin + Int((Double(targetMin - startMin) * eased).rounded())
                let nextSec = startSec + Int((Double(targetSec - startSec) * eased).rounded())
                paceMinutes = nextMin
                paceSeconds = nextSec
            }
            // Snap to exact target on the last frame to absorb any rounding.
            paceMinutes = targetMin
            paceSeconds = targetSec
        }
    }

    /// Wraps a card body in the app-wide `FrostedGlassContainer` so the
    /// calculator's surfaces match Home / Activity / Reports rather than the
    /// older translucent `ultraThinMaterial` look.
    private func glassCard<V: View>(@ViewBuilder _ content: () -> V) -> some View {
        FrostedGlassContainer {
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var softDivider: some View {
        Rectangle()
            .fill(primaryTextColor.opacity(0.08))
            .frame(height: 1)
    }

    // MARK: - Unit Toggle

    private var unitToggle: some View {
        HStack(spacing: 4) {
            ForEach([(false, "km"), (true, "mi")], id: \.0) { option in
                let isSelected = useMiles == option.0
                Button {
                    // Smoother spring than easeInOut(0.2) — gives the
                    // distance Text a chance to do its slot-machine
                    // contentTransition properly, and lets the pace pickers
                    // spin to their new positions instead of snapping.
                    withAnimation(.smooth(duration: 0.45)) {
                        switchUnits(toMiles: option.0)
                    }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    Text(option.1)
                        .font(.footnote.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .foregroundStyle(isSelected ? .white : primaryTextColor)
                        .background(
                            Capsule()
                                .fill(isSelected ? AnyShapeStyle(accentColor) : AnyShapeStyle(Color.clear))
                        )
                }
            }
        }
        .padding(4)
        .background(Capsule().fill(primaryTextColor.opacity(0.06)))
        .frame(maxWidth: 220)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    // MARK: - Solver card (3 unified rows)

    private var solverCard: some View {
        glassCard {
            VStack(alignment: .leading, spacing: 14) {
                solveForPicker

                VStack(alignment: .leading, spacing: 0) {
                    solverRow(.distance)
                    rowSeparator(between: .distance, and: .pace)
                    solverRow(.pace)
                    rowSeparator(between: .pace, and: .time)
                    solverRow(.time)
                }

                softDivider

                HStack(spacing: 6) {
                    Image(systemName: "speedometer")
                        .font(.caption2.weight(.semibold))
                    Text("Speed")
                        .textCase(.uppercase)
                        .tracking(0.5)
                    Spacer()
                    Text(String(format: "%.1f km/h", derivedPaceKmh))
                        .monospacedDigit()
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(tertiaryTextColor)
            }
        }
    }

    // Explicit segmented control — makes the "which field am I solving for?"
    // decision obvious to first-time users.
    private var solveForPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Calculate")
                .font(.caption.weight(.semibold))
                .foregroundStyle(secondaryTextColor)
                .textCase(.uppercase)
                .tracking(0.5)

            HStack(spacing: 4) {
                ForEach(SolveTarget.allCases) { target in
                    let isSelected = solveTarget == target
                    Button {
                        setSolveTarget(target)
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: target.icon)
                                .font(.caption2.weight(.bold))
                            Text(target.shortLabel)
                                .font(.caption.weight(.semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .foregroundStyle(isSelected ? .white : primaryTextColor)
                        .background(
                            Capsule()
                                .fill(isSelected ? AnyShapeStyle(accentColor) : AnyShapeStyle(Color.clear))
                        )
                        .shadow(color: isSelected ? accentColor.opacity(0.3) : .clear, radius: 6, y: 2)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(4)
            .background(Capsule().fill(primaryTextColor.opacity(0.06)))
        }
    }

    @ViewBuilder
    private func rowSeparator(between a: SolveTarget, and b: SolveTarget) -> some View {
        if solveTarget == a || solveTarget == b {
            Color.clear.frame(height: 6)
        } else {
            softDivider
        }
    }

    @ViewBuilder
    private func solverRow(_ target: SolveTarget) -> some View {
        let isOutput = solveTarget == target
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: target.icon)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(isOutput ? accentColor : secondaryTextColor)
                Text(target.label)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isOutput ? accentColor : secondaryTextColor)
                    .textCase(.uppercase)
                    .tracking(0.5)
                Spacer()
                if isOutput {
                    Text("= Result")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(Capsule().fill(accentColor))
                }
            }

            if isOutput {
                outputView(for: target)
            } else {
                inputView(for: target)
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, isOutput ? 12 : 0)
        .background(
            isOutput
                ? RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(accentColor.opacity(colorScheme == .dark ? 0.12 : 0.08))
                : nil
        )
    }

    @ViewBuilder
    private func outputView(for target: SolveTarget) -> some View {
        let (text, unit) = outputValue(for: target)
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(text)
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(primaryTextColor)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .contentTransition(.numericText())
                .animation(.snappy(duration: 0.25), value: text)
            if !unit.isEmpty {
                Text(unit)
                    .font(.title3.weight(.medium))
                    .foregroundStyle(tertiaryTextColor)
            }
            Spacer()
        }
    }

    private func outputValue(for target: SolveTarget) -> (String, String) {
        switch target {
        case .distance:
            return (String(format: "%.2f", derivedDistance), unitLabel)
        case .pace:
            return (PaceMath.formatPace(derivedPaceSecondsPerUnit), paceUnitLabel)
        case .time:
            return (PaceMath.formatDuration(derivedTimeSeconds), "")
        }
    }

    @ViewBuilder
    private func inputView(for target: SolveTarget) -> some View {
        switch target {
        case .distance: distanceInput
        case .pace:     paceInput
        case .time:     timeInput
        }
    }

    // MARK: - Input views

    private func isPresetActive(_ preset: PresetDistance) -> Bool {
        let presetInUnit = useMiles ? preset.km / PaceMath.mileInKm : preset.km
        let rounded = (presetInUnit * 100).rounded() / 100
        return abs(distance - rounded) < 0.01
    }

    private var distanceInput: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                // Show a static Text in display mode so the value can animate
                // smoothly via `.contentTransition(.numericText())` when units
                // toggle. SwiftUI TextFields don't honor contentTransition —
                // they snap to the new value, which felt crude. Tap reveals
                // the actual TextField for keyboard input.
                ZStack(alignment: .leading) {
                    if distanceFieldFocused {
                        TextField("0", value: $distance, format: .number.precision(.fractionLength(0...2)))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.leading)
                            .font(.title2.weight(.semibold).monospacedDigit())
                            .foregroundStyle(primaryTextColor)
                            .focused($distanceFieldFocused)
                    } else {
                        Text(distance == distance.rounded()
                             ? String(format: "%.0f", distance)
                             : String(format: "%.2f", distance))
                            .font(.title2.weight(.semibold).monospacedDigit())
                            .foregroundStyle(primaryTextColor)
                            .contentTransition(.numericText(value: distance))
                            .onTapGesture { distanceFieldFocused = true }
                    }
                }
                Text(unitLabel)
                    .font(.headline.weight(.medium))
                    .foregroundStyle(tertiaryTextColor)
                    .contentTransition(.opacity)
                Spacer()
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(primaryTextColor.opacity(0.05))
            )

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(PresetDistance.all) { preset in
                        let isActive = isPresetActive(preset)
                        Button {
                            let newVal = useMiles ? preset.km / PaceMath.mileInKm : preset.km
                            withAnimation(.spring(response: 0.3)) {
                                distance = (newVal * 100).rounded() / 100
                            }
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        } label: {
                            Text(preset.name)
                                .font(.caption.weight(.semibold))
                                .padding(.vertical, 7)
                                .padding(.horizontal, 14)
                                .foregroundStyle(isActive ? .white : accentColor)
                                .background(
                                    Capsule()
                                        .fill(isActive ? AnyShapeStyle(accentColor) : AnyShapeStyle(accentColor.opacity(0.15)))
                                )
                                .overlay(
                                    Capsule()
                                        .strokeBorder(
                                            isActive ? Color.clear : accentColor.opacity(0.25),
                                            lineWidth: 0.8
                                        )
                                )
                        }
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }

    private var paceInput: some View {
        HStack(spacing: 0) {
            Picker("min", selection: $paceMinutes) {
                ForEach(0..<30, id: \.self) { Text("\($0)").tag($0) }
            }
            .pickerStyle(.wheel)
            .frame(maxWidth: .infinity)
            .frame(height: 100)
            .clipped()

            Text(":")
                .font(.title2.weight(.bold))
                .foregroundStyle(secondaryTextColor)

            Picker("sec", selection: $paceSeconds) {
                ForEach(0..<60, id: \.self) { Text(String(format: "%02d", $0)).tag($0) }
            }
            .pickerStyle(.wheel)
            .frame(maxWidth: .infinity)
            .frame(height: 100)
            .clipped()

            Text(paceUnitLabel)
                .font(.footnote.weight(.medium))
                .foregroundStyle(tertiaryTextColor)
                .padding(.horizontal, 8)
        }
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(primaryTextColor.opacity(0.04))
        )
    }

    private var timeInput: some View {
        HStack(spacing: 0) {
            Picker("hr", selection: $timeHours) {
                ForEach(0..<10, id: \.self) { Text("\($0)h").tag($0) }
            }
            .pickerStyle(.wheel)
            .frame(maxWidth: .infinity)
            .frame(height: 100)
            .clipped()

            Picker("min", selection: $timeMinutes) {
                ForEach(0..<60, id: \.self) { Text("\($0)m").tag($0) }
            }
            .pickerStyle(.wheel)
            .frame(maxWidth: .infinity)
            .frame(height: 100)
            .clipped()

            Picker("sec", selection: $timeSeconds) {
                ForEach(0..<60, id: \.self) { Text("\($0)s").tag($0) }
            }
            .pickerStyle(.wheel)
            .frame(maxWidth: .infinity)
            .frame(height: 100)
            .clipped()
        }
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(primaryTextColor.opacity(0.04))
        )
    }

    // MARK: - Solve target switching

    private func setSolveTarget(_ target: SolveTarget) {
        guard target != solveTarget else { return }
        // Sync the outgoing (previously output) target's input state to its
        // last-derived value so the picker/field reflects what was just shown.
        switch solveTarget {
        case .distance:
            distance = max(0, (derivedDistance * 100).rounded() / 100)
        case .pace:
            let p = Int(derivedPaceSecondsPerUnit.rounded())
            paceMinutes = min(29, max(0, p / 60))
            paceSeconds = min(59, max(0, p % 60))
        case .time:
            let t = Int(derivedTimeSeconds.rounded())
            timeHours   = min(9,  max(0, t / 3600))
            timeMinutes = min(59, max(0, (t % 3600) / 60))
            timeSeconds = min(59, max(0, t % 60))
        }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            solveTarget = target
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    // MARK: - Splits

    @ViewBuilder
    private var splitsDisclosure: some View {
        if canShowSplits {
            glassCard {
                VStack(alignment: .leading, spacing: 0) {
                    Button {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                            showSplits.toggle()
                        }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "list.number")
                                .font(.subheadline)
                                .foregroundStyle(accentColor)
                            Text("Splits")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(secondaryTextColor)
                                .textCase(.uppercase)
                                .tracking(0.5)
                            Spacer()
                            Image(systemName: "chevron.down")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(secondaryTextColor)
                                .rotationEffect(.degrees(showSplits ? 180 : 0))
                        }
                    }
                    .buttonStyle(.plain)

                    if showSplits {
                        softDivider
                            .padding(.vertical, 12)

                        HStack {
                            Text("Split")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(tertiaryTextColor)
                            Spacer()
                            Text("Cumulative")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(tertiaryTextColor)
                        }
                        .padding(.bottom, 6)

                        let splits = buildSplits()
                        VStack(spacing: 0) {
                            ForEach(Array(splits.enumerated()), id: \.offset) { idx, split in
                                HStack {
                                    Text(split.label)
                                        .font(.subheadline.weight(.medium).monospacedDigit())
                                        .foregroundStyle(primaryTextColor)
                                    Spacer()
                                    Text(PaceMath.formatDuration(split.cumulativeSeconds))
                                        .font(.subheadline.monospacedDigit())
                                        .foregroundStyle(secondaryTextColor)
                                }
                                .padding(.vertical, 10)
                                .padding(.horizontal, 12)
                                .background(
                                    idx.isMultiple(of: 2)
                                        ? Color.clear
                                        : primaryTextColor.opacity(0.04)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            }
                        }
                    }
                }
            }
        }
    }

    private var canShowSplits: Bool {
        derivedDistance > 0 && derivedPaceSecondsPerUnit > 0
    }

    private struct SplitRow {
        let label: String
        let cumulativeSeconds: Double
    }

    private func buildSplits() -> [SplitRow] {
        let totalUnits = derivedDistance
        let secPerUnit = derivedPaceSecondsPerUnit
        guard totalUnits > 0, secPerUnit > 0 else { return [] }

        let whole = Int(totalUnits.rounded(.down))
        var rows: [SplitRow] = []
        rows.reserveCapacity(whole + 1)

        for i in 1...max(whole, 1) {
            if Double(i) > totalUnits { break }
            rows.append(SplitRow(
                label: "\(i) \(unitLabel)",
                cumulativeSeconds: Double(i) * secPerUnit
            ))
        }

        let remainder = totalUnits - Double(whole)
        if remainder > 0.01 {
            rows.append(SplitRow(
                label: String(format: "%.2f %@", totalUnits, unitLabel),
                cumulativeSeconds: totalUnits * secPerUnit
            ))
        }

        return rows
    }

    // MARK: - Recent Runs Card (HealthKit)

    private var recentRunsCard: some View {
        Group {
            if !recentRuns.isEmpty {
                glassCard {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 8) {
                            Image(systemName: "figure.run")
                                .font(.subheadline)
                                .foregroundStyle(accentColor)
                            Text("Recent Runs")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(secondaryTextColor)
                                .textCase(.uppercase)
                                .tracking(0.5)
                            Spacer()
                            Text("HealthKit")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(tertiaryTextColor)
                        }

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(recentRuns) { run in
                                    let isSelected = selectedRunID == run.id
                                    Button {
                                        loadRun(run)
                                    } label: {
                                        let km = (run.distanceMeters ?? 0) / 1000.0
                                        let displayDist = useMiles ? km / PaceMath.mileInKm : km
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(run.date, format: .dateTime.month().day())
                                                .font(.caption.weight(.semibold))
                                                .foregroundStyle(isSelected ? .white : primaryTextColor)
                                            Text(String(format: "%.2f %@", displayDist, unitLabel))
                                                .font(.caption2.monospacedDigit())
                                                .foregroundStyle(isSelected ? .white.opacity(0.85) : secondaryTextColor)
                                            Text(String(format: "%.0f min", run.durationMinutes))
                                                .font(.caption2.monospacedDigit())
                                                .foregroundStyle(isSelected ? .white.opacity(0.85) : secondaryTextColor)
                                        }
                                        .padding(.vertical, 10)
                                        .padding(.horizontal, 14)
                                        .background(
                                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                .fill(isSelected ? AnyShapeStyle(accentColor) : AnyShapeStyle(primaryTextColor.opacity(0.06)))
                                        )
                                        .shadow(color: isSelected ? accentColor.opacity(0.25) : .clear, radius: 6, y: 2)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func clearRunSelection() {
        guard selectedRunID != nil else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            selectedRunID = nil
        }
    }

    private func loadRun(_ run: WorkoutSummary) {
        let km = (run.distanceMeters ?? 0) / 1000.0
        guard km > 0 else { return }

        let unitDistance = useMiles ? km / PaceMath.mileInKm : km
        distance = (unitDistance * 100).rounded() / 100

        let totalSec = Int(run.durationMinutes * 60)
        timeHours = totalSec / 3600
        timeMinutes = (totalSec % 3600) / 60
        timeSeconds = totalSec % 60

        let paceSecPerKm = (run.durationMinutes * 60) / km
        let paceSecPerUnit = useMiles ? paceSecPerKm * PaceMath.mileInKm : paceSecPerKm
        paceMinutes = Int(paceSecPerUnit) / 60
        paceSeconds = Int(paceSecPerUnit) % 60

        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            solveTarget = .pace
        }

        // Set selectedRunID after onChange listeners fire and clear it —
        // so the selection sticks after the "loaded" state mutations propagate.
        let runID = run.id
        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedRunID = runID
            }
        }

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    // MARK: - History Card

    private var historyCard: some View {
        Group {
            if !history.isEmpty {
                glassCard {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 8) {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.subheadline)
                                .foregroundStyle(accentColor)
                            Text("Saved")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(secondaryTextColor)
                                .textCase(.uppercase)
                                .tracking(0.5)
                            Spacer()
                        }

                        VStack(spacing: 0) {
                            ForEach(history.prefix(5)) { entry in
                                HStack(spacing: 12) {
                                    Button {
                                        loadHistory(entry)
                                    } label: {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(entry.label)
                                                    .font(.subheadline.weight(.semibold))
                                                    .foregroundStyle(primaryTextColor)
                                                Text(entry.timestamp, format: .dateTime.month().day().hour().minute())
                                                    .font(.caption2)
                                                    .foregroundStyle(tertiaryTextColor)
                                            }
                                            Spacer()
                                            Text(PaceMath.formatDuration(entry.durationSeconds))
                                                .font(.subheadline.monospacedDigit())
                                                .foregroundStyle(secondaryTextColor)
                                        }
                                    }
                                    .buttonStyle(.plain)

                                    Button {
                                        withAnimation {
                                            modelContext.delete(entry)
                                        }
                                    } label: {
                                        Image(systemName: "trash")
                                            .font(.caption)
                                            .foregroundStyle(.red.opacity(0.8))
                                            .padding(6)
                                    }
                                }
                                .padding(.vertical, 10)

                                if entry.id != history.prefix(5).last?.id {
                                    softDivider
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func loadHistory(_ entry: PaceCalculation) {
        useMiles = entry.useMiles
        let unitDist = useMiles ? entry.distanceKm / PaceMath.mileInKm : entry.distanceKm
        distance = (unitDist * 100).rounded() / 100

        let totalSec = Int(entry.durationSeconds)
        timeHours = totalSec / 3600
        timeMinutes = (totalSec % 3600) / 60
        timeSeconds = totalSec % 60

        let paceSecPerUnit = useMiles ? entry.paceSecondsPerKm * PaceMath.mileInKm : entry.paceSecondsPerKm
        paceMinutes = Int(paceSecPerUnit) / 60
        paceSeconds = Int(paceSecPerUnit) % 60

        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    // MARK: - Save

    private var canSave: Bool {
        derivedDistance > 0 && derivedTimeSeconds > 0 && derivedPaceSecondsPerUnit > 0
    }

    private func saveCalculation() {
        guard canSave else { return }

        let kmDistance = PaceMath.toKm(derivedDistance, useMiles: useMiles)
        let secPerKm: Double = {
            let secPerUnit = derivedPaceSecondsPerUnit
            return useMiles ? secPerUnit / PaceMath.mileInKm : secPerUnit
        }()

        let label = "\(String(format: "%.2f", derivedDistance)) \(unitLabel) @ \(PaceMath.formatPace(derivedPaceSecondsPerUnit))\(paceUnitLabel)"

        let entry = PaceCalculation(
            label: label,
            distanceKm: kmDistance,
            durationSeconds: derivedTimeSeconds,
            paceSecondsPerKm: secPerKm,
            useMiles: useMiles
        )
        modelContext.insert(entry)

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation(.spring(response: 0.3)) {
            showSavedToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeOut) {
                showSavedToast = false
            }
        }
    }
}

#Preview {
    NavigationStack {
        PaceCalculatorView()
    }
    .environmentObject(ThemeManager())
    .modelContainer(for: PaceCalculation.self, inMemory: true)
}

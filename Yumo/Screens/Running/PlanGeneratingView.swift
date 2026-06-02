//
//  PlanGeneratingView.swift
//  Yumo

import SwiftUI

struct PlanGeneratingView: View {
    @Environment(\.colorScheme) private var colorScheme

    @State private var currentTipIndex = 0
    @State private var tipVisible = true
    @State private var pulseScale: CGFloat = 1.0
    @State private var ring1Scale: CGFloat = 1.0
    @State private var ring2Scale: CGFloat = 1.0
    @State private var ring1Opacity: Double = 0.5
    @State private var ring2Opacity: Double = 0.3
    @State private var figureOffset: CGFloat = 0

    private let tips: [(icon: String, title: String, body: String)] = [
        ("tortoise.fill",     "Start slow",           "The easy run is your best friend. 80% of your training should feel completely comfortable."),
        ("arrow.up.right",    "The 10% rule",         "Never increase your weekly mileage by more than 10%. Most injuries come from doing too much too soon."),
        ("heart.fill",        "Aerobic base first",   "Building your aerobic engine takes months, but the speed and endurance gains last for years."),
        ("moon.zzz.fill",     "Sleep is training",    "Your body adapts and repairs during sleep. 7–9 hours is as important as the run itself."),
        ("drop.fill",         "Hydrate early",        "Start hydrating 24 hours before a long run. Thirst is already a sign you're behind."),
        ("flame.fill",        "Warm up properly",     "5 minutes of easy jogging and dynamic drills activates the muscles and reduces injury risk."),
        ("figure.strengthtraining.traditional", "Add strength work", "Two sessions of strength training a week improves running economy and protects your joints."),
        ("arrow.down.right",  "Negative splits",      "Running the second half of a race faster than the first is the mark of great pacing. Practice it in training."),
        ("waveform.path",     "Cadence counts",       "Aim for 170–180 steps per minute. A higher cadence means less time on the ground and fewer injuries."),
        ("mountain.2.fill",   "Run hills",            "Hill repeats build explosive strength and speed without the harsh impact of track intervals."),
        ("brain.head.profile","Trust the process",    "Fitness improvements often appear 4–6 weeks after consistent training. Patience is part of the plan."),
        ("cloud.rain.fill",   "Train in all weather", "Race day won't wait for perfect conditions. Running in wind, rain and heat makes you adaptable."),
        ("figure.run",        "Form matters",         "Lean slightly forward from the ankles, keep your arms relaxed, and look ahead — not at the ground."),
        ("chart.line.uptrend.xyaxis", "Track your effort", "Heart rate and perceived effort tell you more about your fitness than pace alone."),
        ("bandage.fill",      "Listen to your body",  "There's a difference between discomfort and pain. Pain is a signal — not a challenge to ignore."),
    ]

    private var tip: (icon: String, title: String, body: String) { tips[currentTipIndex] }

    private var primaryText: Color { Color("AppTextPrimary") }
    private var secondaryText: Color { Color("AppTextPrimary").opacity(0.8) }

    var body: some View {
        ZStack {
            background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Animated center icon
                ZStack {
                    Circle()
                        .stroke(.white.opacity(ring2Opacity), lineWidth: 1)
                        .frame(width: 80, height: 80)
                        .scaleEffect(ring2Scale)

                    Circle()
                        .stroke(.white.opacity(ring1Opacity), lineWidth: 2)
                        .frame(width: 80, height: 80)
                        .scaleEffect(ring1Scale)

                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.purple, .indigo],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 80, height: 80)

                        Image(systemName: "figure.run")
                            .font(.system(size: 36, weight: .semibold))
                            .foregroundStyle(.white)
                            .offset(y: figureOffset)
                    }
                    .scaleEffect(pulseScale)
                }
                .padding(.bottom, 36)

                // Headline
                VStack(spacing: 8) {
                    Text("Building your plan…")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)

                    Text("AI is crafting sessions tailored to your goals.\nThis usually takes about a minute.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 48)

                // Tip card
                tipCard
                    .padding(.horizontal, 24)
                    .opacity(tipVisible ? 1 : 0)
                    .animation(.easeInOut(duration: 0.5), value: tipVisible)

                Spacer()
                Spacer()
            }
        }
        .onAppear { startAnimations() }
    }

    // MARK: - Tip card

    private var tipCard: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: tip.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(tip.title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                Text(tip.body)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(2)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.12))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.15), lineWidth: 1))
        )
    }

    // MARK: - Background

    private var background: some View {
        ZStack {
            Color(red: 20/255, green: 14/255, blue: 40/255)

            LinearGradient(
                colors: [Color.purple.opacity(0.6), Color.clear],
                startPoint: .topLeading,
                endPoint: .center
            ).blur(radius: 40)

            LinearGradient(
                colors: [Color.clear, Color.indigo.opacity(0.4)],
                startPoint: .center,
                endPoint: .bottomTrailing
            ).blur(radius: 50)

            RadialGradient(
                colors: [Color.purple.opacity(0.3), Color.clear],
                center: .init(x: 0.5, y: 0.35),
                startRadius: 0,
                endRadius: 300
            )
        }
    }

    // MARK: - Animations

    private func startAnimations() {
        // Pulse the icon
        withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
            pulseScale = 1.06
        }

        // Running figure sway
        withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
            figureOffset = 2
        }

        // Ripple ring 1
        withAnimation(.easeOut(duration: 2.0).repeatForever(autoreverses: false)) {
            ring1Scale = 1.6
            ring1Opacity = 0
        }

        // Ripple ring 2 — delayed
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeOut(duration: 2.0).repeatForever(autoreverses: false)) {
                ring2Scale = 1.6
                ring2Opacity = 0
            }
        }

        // Cycle tips every 6 seconds
        cycleTips()
    }

    private func cycleTips() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
            withAnimation { tipVisible = false }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                currentTipIndex = (currentTipIndex + 1) % tips.count
                withAnimation { tipVisible = true }
                cycleTips()
            }
        }
    }
}

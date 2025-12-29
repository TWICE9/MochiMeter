//
//  PaywallView.swift
//  Yumo
//
//  Premium subscription paywall screen
//

import SwiftUI

enum SubscriptionPlan: String {
    case monthly = "monthly"
    case yearly = "yearly"

    var price: String {
        switch self {
        case .monthly: return "$4.50"
        case .yearly: return "$30.00"
        }
    }

    var displayPrice: String {
        switch self {
        case .monthly: return "$4.50/mo"
        case .yearly: return "$30.00/yr"
        }
    }

    var period: String {
        switch self {
        case .monthly: return "month"
        case .yearly: return "year"
        }
    }
}

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var selectedPlan: SubscriptionPlan = .monthly
    @State private var offset1: CGSize = .zero
    @State private var offset2: CGSize = .zero

    var body: some View {
        ZStack {
            // Background
            Color("AppPrimaryDark").ignoresSafeArea()
            _buildDynamicBackground()

            VStack(spacing: 0) {
                // Header
                _buildHeader()

                // Scrollable features list
                ScrollView {
                    VStack(spacing: 24) {
                        _buildFeaturesSection()
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 280) // Space for sticky footer
                }

                Spacer()
            }

            // Sticky bottom pricing section
            VStack {
                Spacer()
                _buildPricingSection()
            }
        }
        .onAppear {
            animateOrbs()
        }
    }

    // MARK: - Header

    @ViewBuilder
    private func _buildHeader() -> some View {
        ZStack {
            HStack {
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.white.opacity(0.6))
                }
                .padding(.trailing, 20)
            }

            VStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 44))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color("AppSecondaryAccent"), Color("AppPrimaryAccent")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Text("Unlock Mochi Meter Premium")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top, 60)
        .padding(.bottom, 20)
    }

    // MARK: - Features Section

    @ViewBuilder
    private func _buildFeaturesSection() -> some View {
        VStack(spacing: 16) {
            _buildFeatureRow(
                icon: "camera.metering.multispot",
                title: "Unlimited AI Scans",
                description: "Scan any food with AI-powered recognition"
            )

            _buildFeatureRow(
                icon: "nosign",
                title: "No Ads",
                description: "Enjoy an ad-free experience"
            )

            _buildFeatureRow(
                icon: "infinity",
                title: "Unlimited Daily Food Logs",
                description: "Log as many meals as you want every day"
            )

            _buildFeatureRow(
                icon: "text.bubble",
                title: "AI Meal Text Logging",
                description: "Describe your meal and AI will log it for you"
            )
        }
    }

    @ViewBuilder
    private func _buildFeatureRow(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color("AppSecondaryAccent").opacity(0.3), Color("AppPrimaryAccent").opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 56)

                Image(systemName: icon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(Color("AppSecondaryAccent"))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)

                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
            }

            Spacer()
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }

    // MARK: - Pricing Section

    @ViewBuilder
    private func _buildPricingSection() -> some View {
        VStack(spacing: 16) {
            // Pricing cards
            HStack(spacing: 12) {
                // Monthly plan
                _buildPricingCard(
                    plan: .monthly,
                    isSelected: selectedPlan == .monthly,
                    showBadge: false
                )

                // Yearly plan
                _buildPricingCard(
                    plan: .yearly,
                    isSelected: selectedPlan == .yearly,
                    showBadge: true,
                    badgeText: "Save 44%"
                )
            }
            .padding(.horizontal, 24)

            // Subscribe button
            Button {
                handleSubscribe()
            } label: {
                Text("Subscribe for \(selectedPlan.displayPrice)")
                    .font(.headline.bold())
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        LinearGradient(
                            colors: [Color("AppSecondaryAccent"), Color("AppPrimaryAccent")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal, 24)

            // Terms text
            Text("Auto-renewable. Cancel anytime.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.5))
                .padding(.bottom, 8)
        }
        .padding(.vertical, 20)
        .background(
            .ultraThinMaterial.opacity(0.9),
            in: RoundedRectangle(cornerRadius: 0)
        )
        .background(Color("AppPrimaryDark"))
    }

    @ViewBuilder
    private func _buildPricingCard(
        plan: SubscriptionPlan,
        isSelected: Bool,
        showBadge: Bool,
        badgeText: String = ""
    ) -> some View {
        Button {
            withAnimation(.spring(response: 0.3)) {
                selectedPlan = plan
            }
        } label: {
            VStack(spacing: 8) {
                // Badge (if applicable)
                if showBadge {
                    Text(badgeText)
                        .font(.caption.bold())
                        .foregroundStyle(.black)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Color("AppSecondaryAccent"))
                        .clipShape(Capsule())
                } else {
                    // Invisible spacer to maintain consistent height
                    Text("")
                        .font(.caption.bold())
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .hidden()
                }

                // Price
                Text(plan.price)
                    .font(.title2.bold())
                    .foregroundStyle(.white)

                // Period
                Text("per \(plan.period)")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))

                // Checkmark (if selected)
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Color("AppSecondaryAccent"))
                } else {
                    Circle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 2)
                        .frame(width: 24, height: 24)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                isSelected
                ? Color("AppSecondaryAccent").opacity(0.15)
                : Color.white.opacity(0.05)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        isSelected
                        ? Color("AppSecondaryAccent")
                        : Color.white.opacity(0.2),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func handleSubscribe() {
        // TODO: Implement subscription logic
        print("🎁 Subscribe tapped for plan: \(selectedPlan.rawValue)")
        print("💰 Price: \(selectedPlan.price)")

        // This is where you'll integrate with StoreKit or your payment provider
        // For now, just dismiss
        dismiss()
    }

    // MARK: - Background

    @ViewBuilder
    private func _buildDynamicBackground() -> some View {
        ZStack {
            // Orb 1: Primary Theme Color (Top Left)
            RadialGradient(
                gradient: Gradient(colors: [
                    colorScheme == .light 
                        ? themeManager.currentTheme.primaryColor.opacity(0.4) 
                        : themeManager.currentTheme.darkPrimaryColor.opacity(0.2),
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
                    themeManager.currentTheme.complementaryColor.opacity(colorScheme == .light ? 0.35 : 0.2),
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

#Preview {
    PaywallView()
        .preferredColorScheme(.dark)
}

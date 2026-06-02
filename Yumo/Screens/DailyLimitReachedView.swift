//
//  DailyLimitReachedView.swift
//  Yumo
//
//  Shown when a non-premium user exhausts their free daily quota for a feature.
//  Offers a friendly message + reset info and a route to the full paywall.
//

import SwiftUI

enum DailyLimitFeature {
    case aiScan
    case quickMeal

    var analyticsName: String {
        switch self {
        case .aiScan: return "ai_scan"
        case .quickMeal: return "quick_meal"
        }
    }

    var title: String {
        switch self {
        case .aiScan: return "You've used today's free scans"
        case .quickMeal: return "You've used today's free meal logs"
        }
    }

    var message: String {
        switch self {
        case .aiScan:
            return "You've used all 3 of your free food scans for today. They reset at midnight — or upgrade for unlimited scans anytime."
        case .quickMeal:
            return "You've used all 3 of your free quick meal logs for today. They reset at midnight — or upgrade for unlimited logs anytime."
        }
    }

    var iconName: String {
        switch self {
        case .aiScan: return "sparkles"
        case .quickMeal: return "fork.knife"
        }
    }
}

struct DailyLimitReachedView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager

    let feature: DailyLimitFeature
    let onUpgrade: () -> Void

    // MARK: - Colors

    private var primaryTextColor: Color {
        colorScheme == .dark ? .white : Color(red: 32/255, green: 32/255, blue: 38/255)
    }

    private var secondaryTextColor: Color {
        colorScheme == .dark ? .white.opacity(0.7) : Color(red: 120/255, green: 120/255, blue: 130/255)
    }

    private var accentGradient: LinearGradient {
        LinearGradient(
            colors: themeManager.currentTheme.buttonGradient(for: colorScheme),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            _buildBackground()

            VStack(spacing: 0) {
                // Close button
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(secondaryTextColor)
                            .frame(width: 30, height: 30)
                            .background(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.06))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)

                Spacer()

                // Icon
                ZStack {
                    Circle()
                        .fill(accentGradient.opacity(0.18))
                        .frame(width: 96, height: 96)

                    Image(systemName: feature.iconName)
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundStyle(accentGradient)
                }
                .padding(.bottom, 28)

                // Title
                Text(feature.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(primaryTextColor)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 12)

                // Message
                Text(feature.message)
                    .font(.subheadline)
                    .foregroundStyle(secondaryTextColor)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 24)

                // Reset pill
                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Resets at midnight")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundStyle(secondaryTextColor)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.05))
                )

                Spacer()

                // CTAs
                VStack(spacing: 12) {
                    Button {
                        dismiss()
                        // Slight delay so the sheet dismiss animation starts before
                        // the paywall presents, otherwise iOS can drop the second sheet.
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            onUpgrade()
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 15, weight: .bold))
                            Text("Upgrade to Premium")
                                .font(.system(size: 16, weight: .bold))
                        }
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(accentGradient)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    Button {
                        dismiss()
                    } label: {
                        Text("Not now")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(secondaryTextColor)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
        .onAppear {
            AnalyticsManager.shared.trackDailyLimitViewed(feature: feature.analyticsName)
        }
    }

    // MARK: - Background

    @ViewBuilder
    private func _buildBackground() -> some View {
        ZStack {
            Color("AppPrimaryDark").ignoresSafeArea()

            RadialGradient(
                gradient: Gradient(colors: [
                    colorScheme == .light
                        ? themeManager.currentTheme.primaryColor.opacity(0.22)
                        : themeManager.currentTheme.darkPrimaryColor.opacity(0.12),
                    .clear
                ]),
                center: .topLeading,
                startRadius: 50,
                endRadius: 500
            )
            .offset(x: -80, y: -100)
            .ignoresSafeArea()

            RadialGradient(
                gradient: Gradient(colors: [
                    themeManager.currentTheme.complementaryColor.opacity(colorScheme == .light ? 0.18 : 0.1),
                    .clear
                ]),
                center: .bottomTrailing,
                startRadius: 100,
                endRadius: 450
            )
            .offset(x: 50, y: 80)
            .ignoresSafeArea()
        }
    }
}

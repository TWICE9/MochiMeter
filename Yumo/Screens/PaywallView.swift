//
//  PaywallView.swift
//  Yumo
//
//  2-page premium paywall with free trial + StoreKit 2
//

import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @ObservedObject private var storeKit = StoreKitManager.shared

    @State private var currentPage = 0
    @State private var selectedProductID: String = StoreKitManager.yearlyProductID
    @State private var showSuccessAnimation = false

    private let totalPages = 3

    /// Analytics tag for where the paywall was opened from.
    let trigger: String

    init(trigger: String = "unknown") {
        self.trigger = trigger
    }

    // MARK: - Adaptive Colors (matching app design system)

    private var primaryTextColor: Color {
        colorScheme == .dark ? .white : Color(red: 32/255, green: 32/255, blue: 38/255)
    }

    private var secondaryTextColor: Color {
        colorScheme == .dark ? .white.opacity(0.7) : Color(red: 120/255, green: 120/255, blue: 130/255)
    }

    private var cardBorderColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.06)
    }

    private var primaryAccent: Color {
        colorScheme == .dark ? themeManager.currentTheme.darkPrimaryColor : themeManager.currentTheme.primaryColor
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
            _buildDynamicBackground()

            VStack(spacing: 0) {
                _buildTopBar()

                TabView(selection: $currentPage) {
                    _trialPage().tag(0)
                    _howItWorksPage().tag(1)
                    _detailsPage().tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.3), value: currentPage)

                _buildBottomSection()
            }

            if showSuccessAnimation {
                _buildSuccessOverlay()
            }
        }
        .task {
            if storeKit.products.isEmpty {
                await storeKit.loadProducts()
            }
        }
        .onAppear {
            AnalyticsManager.shared.trackPaywallViewed(trigger: trigger)
        }
    }

    // MARK: - Dynamic Background (matches app)

    @ViewBuilder
    private func _buildDynamicBackground() -> some View {
        ZStack {
            Color("AppPrimaryDark").ignoresSafeArea()

            RadialGradient(
                gradient: Gradient(colors: [
                    colorScheme == .light
                        ? themeManager.currentTheme.primaryColor.opacity(0.25)
                        : themeManager.currentTheme.darkPrimaryColor.opacity(0.12),
                    .clear
                ]),
                center: .topLeading,
                startRadius: 50,
                endRadius: 550
            )
            .offset(x: -80, y: -100)
            .ignoresSafeArea()

            RadialGradient(
                gradient: Gradient(colors: [
                    themeManager.currentTheme.complementaryColor.opacity(colorScheme == .light ? 0.2 : 0.1),
                    .clear
                ]),
                center: .bottomTrailing,
                startRadius: 100,
                endRadius: 500
            )
            .offset(x: 50, y: 80)
            .ignoresSafeArea()
        }
    }

    // MARK: - Top Bar

    @ViewBuilder
    private func _buildTopBar() -> some View {
        HStack {
            if currentPage == 0 {
                // De-emphasised Skip — present for App Store compliance and
                // user freedom, but visually quiet so the CTA pulls more
                // weight on a first scan. Jumps straight to the subscribe
                // page (last) so a hurried user can decide immediately.
                Button {
                    withAnimation { currentPage = totalPages - 1 }
                } label: {
                    Text("Skip")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(secondaryTextColor.opacity(0.55))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                }
            } else {
                // Step back one page at a time so the user can review the
                // marketing pages they passed through.
                Button {
                    withAnimation { currentPage = max(0, currentPage - 1) }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(secondaryTextColor)
                }
            }

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
    }

    // MARK: - Page 1: Free Trial

    @ViewBuilder
    private func _trialPage() -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                Spacer().frame(height: 12)

                // Logo
                Image(colorScheme == .light ? "LogoHS" : "LogoDarkMode")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 56)
                    .padding(.bottom, 22)

                Text(heroHeadline)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(primaryTextColor)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 10)

                Text(heroSubhead)
                    .font(.subheadline)
                    .foregroundStyle(secondaryTextColor)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 28)

                // Trial cards
                VStack(spacing: 12) {
                    _trialCard(
                        label: "Yearly Plan",
                        trial: "1 week free",
                        price: storeKit.yearlyProduct?.displayPrice ?? "$24.99",
                        period: "/year",
                        perMonth: yearlyPerMonth(),
                        badge: yearlyBadgeText,
                        isSelected: selectedProductID == StoreKitManager.yearlyProductID,
                        productID: StoreKitManager.yearlyProductID
                    )

                    _trialCard(
                        label: "Monthly Plan",
                        trial: "3 days free",
                        price: storeKit.monthlyProduct?.displayPrice ?? "$4.49",
                        period: "/month",
                        perMonth: nil,
                        badge: nil,
                        isSelected: selectedProductID == StoreKitManager.monthlyProductID,
                        productID: StoreKitManager.monthlyProductID
                    )
                }
                .padding(.horizontal, 24)

                _trialTimeline()
                    .padding(.horizontal, 24)
                    .padding(.top, 22)

                _trustStrip()
                    .padding(.top, 14)
                    .padding(.bottom, 8)
            }
        }
    }

    // MARK: Trial timeline

    /// Three-step "what happens during the trial" timeline. The biggest
    /// objection on free trials is the fear of being charged silently — this
    /// shows users *exactly* what to expect and when, which lifts opt-in
    /// rates without requiring any change to the underlying offer.
    @ViewBuilder
    private func _trialTimeline() -> some View {
        VStack(alignment: .leading, spacing: 0) {
            _timelineRow(
                day: "Today",
                text: "Unlock every Premium feature instantly",
                isLast: false
            )
            _timelineRow(
                day: "Day 5",
                text: "We'll remind you before your trial ends",
                isLast: false
            )
            _timelineRow(
                day: "Day 7",
                text: "Trial ends — cancel anytime in Settings",
                isLast: true
            )
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(colorScheme == .dark
                      ? Color.white.opacity(0.04)
                      : Color.black.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(cardBorderColor, lineWidth: 1)
                )
        )
    }

    @ViewBuilder
    private func _timelineRow(day: String, text: String, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 0) {
                Circle()
                    .fill(accentGradient)
                    .frame(width: 10, height: 10)
                if !isLast {
                    Rectangle()
                        .fill(primaryAccent.opacity(0.35))
                        .frame(width: 1.5)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: 10)

            VStack(alignment: .leading, spacing: 1) {
                Text(day)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(primaryTextColor)
                Text(text)
                    .font(.caption)
                    .foregroundStyle(secondaryTextColor)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.bottom, isLast ? 0 : 14)

            Spacer(minLength: 0)
        }
    }

    // MARK: - Page 2: How It Works

    /// Three-step value-prop page that sits between the trial picker and the
    /// details page. Reinforces the "personalised + adaptive" story so the
    /// user understands *why* Premium is different before they see the full
    /// feature list and the subscribe button.
    @ViewBuilder
    private func _howItWorksPage() -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                Spacer().frame(height: 12)

                Image(colorScheme == .light ? "LogoHS" : "LogoDarkMode")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 48)
                    .padding(.bottom, 22)

                Text("Built around you")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(primaryTextColor)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 10)

                Text("From goal to result in three simple steps.")
                    .font(.subheadline)
                    .foregroundStyle(secondaryTextColor)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 36)

                VStack(alignment: .leading, spacing: 0) {
                    _howItWorksRow(
                        number: 1,
                        icon: "scope",
                        title: "Tell us your goal",
                        body: "A race, a weight target, or just consistent training. Pick what matters and we tailor everything to it.",
                        isLast: false
                    )
                    _howItWorksRow(
                        number: 2,
                        icon: "sparkles",
                        title: "AI builds your plan",
                        body: "Nutrition targets and training calibrated to your fitness today — not someone else's average.",
                        isLast: false
                    )
                    _howItWorksRow(
                        number: 3,
                        icon: "arrow.triangle.2.circlepath",
                        title: "It evolves with you",
                        body: "Off track for a week or pushed too hard? Your plan adjusts automatically — and you can fine-tune anything.",
                        isLast: true
                    )
                }
                .padding(.horizontal, 32)

                Spacer().frame(height: 24)
            }
        }
    }

    @ViewBuilder
    private func _howItWorksRow(
        number: Int,
        icon: String,
        title: String,
        body: String,
        isLast: Bool
    ) -> some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(accentGradient)
                        .frame(width: 38, height: 38)
                        .shadow(color: primaryAccent.opacity(colorScheme == .dark ? 0 : 0.3), radius: 6, y: 2)
                    Text("\(number)")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                }

                if !isLast {
                    Rectangle()
                        .fill(primaryAccent.opacity(0.25))
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                        .padding(.vertical, 6)
                }
            }
            .frame(width: 38)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(primaryAccent)
                    Text(title)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(primaryTextColor)
                }

                Text(body)
                    .font(.subheadline)
                    .foregroundStyle(secondaryTextColor)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.bottom, isLast ? 0 : 26)

            Spacer(minLength: 0)
        }
    }

    // MARK: Trust strip

    @ViewBuilder
    private func _trustStrip() -> some View {
        HStack(spacing: 14) {
            _trustItem(icon: "lock.shield.fill", text: "No charge today")
            Circle().fill(secondaryTextColor.opacity(0.3)).frame(width: 3, height: 3)
            _trustItem(icon: "arrow.uturn.backward", text: "Cancel anytime")
        }
    }

    @ViewBuilder
    private func _trustItem(icon: String, text: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
            Text(text)
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundStyle(secondaryTextColor)
    }

    @ViewBuilder
    private func _trialCard(
        label: String,
        trial: String,
        price: String,
        period: String,
        perMonth: String?,
        badge: String?,
        isSelected: Bool,
        productID: String
    ) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedProductID = productID
            }
        } label: {
            VStack(spacing: 0) {
                // Badge ribbon
                if let badge {
                    Text(badge)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(accentGradient)
                }

                HStack(spacing: 14) {
                    // Radio
                    ZStack {
                        Circle()
                            .stroke(isSelected ? Color.clear : secondaryTextColor.opacity(0.4), lineWidth: 2)
                            .frame(width: 24, height: 24)

                        if isSelected {
                            Circle()
                                .fill(accentGradient)
                                .frame(width: 24, height: 24)
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(label)
                            .font(.headline)
                            .foregroundStyle(primaryTextColor)

                        HStack(spacing: 6) {
                            Text(trial)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(primaryAccent)

                            if let perMonth {
                                Text("then \(perMonth)")
                                    .font(.caption)
                                    .foregroundStyle(secondaryTextColor)
                            }
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(price)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(primaryTextColor)
                        Text(period)
                            .font(.caption)
                            .foregroundStyle(secondaryTextColor)
                    }
                }
                .padding(16)
            }
            .background(
                colorScheme == .dark
                    ? Color(UIColor.secondarySystemGroupedBackground)
                    : Color.white
            )
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        isSelected ? primaryAccent.opacity(0.6) : cardBorderColor,
                        lineWidth: isSelected ? 2 : 1
                    )
            )
            .shadow(color: .black.opacity(colorScheme == .dark ? 0 : 0.05), radius: colorScheme == .dark ? 0 : 8, y: colorScheme == .dark ? 0 : 4)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Page 2: Details + Subscribe

    @ViewBuilder
    private func _detailsPage() -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                // Logo + Hero
                VStack(spacing: 14) {
                    Image(colorScheme == .light ? "LogoHS" : "LogoDarkMode")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 48)

                    Text("What You Get")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(primaryTextColor)

                    Text(trialSummaryText)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(primaryAccent)
                }
                .padding(.top, 20)
                .padding(.bottom, 28)

                // Feature list in FrostedGlassContainer style — grouped by
                // domain so the running benefits are easy to scan alongside
                // the nutrition ones.
                FrostedGlassContainer(clipsContent: true) {
                    VStack(spacing: 0) {
                        _sectionHeader("NUTRITION")
                        _featureRow(icon: "camera.viewfinder", title: "Unlimited AI Scans", subtitle: "Scan any meal with AI-powered recognition")
                        Divider().background(cardBorderColor)
                        _featureRow(icon: "text.bubble.fill", title: "AI Text Logging", subtitle: "Describe meals, AI logs them for you")
                        Divider().background(cardBorderColor)
                        _featureRow(icon: "list.bullet.clipboard.fill", title: "Unlimited Daily Logs", subtitle: "No cap on how many meals you track")
                        Divider().background(cardBorderColor)
                        _featureRow(icon: "wand.and.stars", title: "Fix AI Results", subtitle: "Correct any scan with a single tap")

                        Divider().background(cardBorderColor)
                        _sectionHeader("RUNNING")
                        _featureRow(icon: "figure.run", title: "Unlimited AI Plans", subtitle: "Regenerate your training plan whenever your goals shift")
                        Divider().background(cardBorderColor)
                        _featureRow(icon: "slider.horizontal.3", title: "Fine-Tune Workouts", subtitle: "Swap, shorten or shift any session in seconds")
                        Divider().background(cardBorderColor)
                        _featureRow(icon: "arrow.triangle.2.circlepath", title: "Smart Adaptations", subtitle: "Plan auto-adjusts when you miss runs or life gets busy")

                        Divider().background(cardBorderColor)
                        _sectionHeader("EXTRAS")
                        _featureRow(icon: "eye.slash.fill", title: "No Ads", subtitle: "Clean, distraction-free experience")
                    }
                }
                .padding(.horizontal, 24)

                // Selected plan recap
                _planRecap()
                    .padding(.horizontal, 24)
                    .padding(.top, 20)

                // Footer
                _buildFooter()
                    .padding(.top, 20)
                    .padding(.bottom, 20)
            }
        }
    }

    @ViewBuilder
    private func _sectionHeader(_ text: String) -> some View {
        HStack {
            Text(text)
                .font(.system(size: 11, weight: .bold))
                .tracking(1.0)
                .foregroundStyle(primaryAccent)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 6)
    }

    @ViewBuilder
    private func _featureRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(accentGradient)
                .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(primaryTextColor)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(secondaryTextColor)
            }

            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18))
                .foregroundStyle(primaryAccent.opacity(0.8))
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func _planRecap() -> some View {
        let isYearly = selectedProductID == StoreKitManager.yearlyProductID
        let trialText = isYearly ? "1 week free trial" : "3 day free trial"
        let product = isYearly ? storeKit.yearlyProduct : storeKit.monthlyProduct
        let priceText = product?.displayPrice ?? (isYearly ? "$24.99/yr" : "$4.49/mo")
        let periodText = isYearly ? "/year" : "/month"

        FrostedGlassContainer {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(isYearly ? "Yearly Plan" : "Monthly Plan")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(primaryTextColor)
                    Text(trialText + ", then \(priceText)\(periodText)")
                        .font(.caption)
                        .foregroundStyle(secondaryTextColor)
                }

                Spacer()

                Button {
                    withAnimation { currentPage = 0 }
                } label: {
                    Text("Change")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(primaryAccent)
                }
            }
        }
    }

    // MARK: - Bottom Section

    @ViewBuilder
    private func _buildBottomSection() -> some View {
        VStack(spacing: 14) {
            // Page dots
            HStack(spacing: 8) {
                ForEach(0..<totalPages, id: \.self) { index in
                    Capsule()
                        .fill(index == currentPage ? AnyShapeStyle(accentGradient) : AnyShapeStyle(secondaryTextColor.opacity(0.3)))
                        .frame(width: index == currentPage ? 24 : 8, height: 8)
                        .animation(.spring(response: 0.3), value: currentPage)
                }
            }

            if currentPage < totalPages - 1 {
                Button {
                    withAnimation { currentPage += 1 }
                } label: {
                    Text(currentPage == 0 ? "Try Premium Free" : "Continue")
                        .font(.headline)
                        .foregroundStyle(colorScheme == .dark ? .white : .black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(accentGradient)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            } else {
                Button {
                    Task { await handlePurchase() }
                } label: {
                    Group {
                        if storeKit.isPurchasing {
                            ProgressView()
                                .tint(colorScheme == .dark ? .white : .black)
                        } else {
                            Text(subscribeButtonText)
                                .font(.headline)
                        }
                    }
                    .foregroundStyle(colorScheme == .dark ? .white : .black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(accentGradient)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .disabled(storeKit.isPurchasing || storeKit.products.isEmpty)
                .opacity(storeKit.products.isEmpty ? 0.5 : 1)

                if let error = storeKit.purchaseError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 28)
        .padding(.top, 8)
    }

    // MARK: - Footer

    @ViewBuilder
    private func _buildFooter() -> some View {
        VStack(spacing: 8) {
            Text("Auto-renewable subscription. Cancel anytime.")
                .font(.caption2)
                .foregroundStyle(secondaryTextColor)

            HStack(spacing: 16) {
                Button("Restore Purchases") {
                    Task { await storeKit.restorePurchases() }
                }
                .font(.caption2).fontWeight(.medium)
                .foregroundStyle(secondaryTextColor)

                Text("•").foregroundStyle(secondaryTextColor.opacity(0.5))

                Link("Terms of Use", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                    .font(.caption2).fontWeight(.medium)
                    .foregroundStyle(secondaryTextColor)

                Text("•").foregroundStyle(secondaryTextColor.opacity(0.5))

                Link("Privacy", destination: URL(string: "https://mochimeter.com.au/privacy/")!)
                    .font(.caption2).fontWeight(.medium)
                    .foregroundStyle(secondaryTextColor)
            }
        }
    }

    // MARK: - Success Overlay

    @ViewBuilder
    private func _buildSuccessOverlay() -> some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.green)

                Text("Welcome to Premium!")
                    .font(.title2.bold())
                    .foregroundStyle(.white)

                Text("You've unlocked all features")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
            }
            .transition(.scale.combined(with: .opacity))
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                dismiss()
            }
        }
    }

    // MARK: - Actions

    private func handlePurchase() async {
        guard let product = storeKit.products.first(where: { $0.id == selectedProductID }) else { return }

        let success = await storeKit.purchase(product)
        if success {
            withAnimation(.spring()) {
                showSuccessAnimation = true
            }
            AnalyticsManager.shared.trackSubscriptionPurchased(plan: product.id)
        }
    }

    // MARK: - Helpers

    private var trialSummaryText: String {
        selectedProductID == StoreKitManager.yearlyProductID
            ? "1 week free trial — Yearly Plan"
            : "3 day free trial — Monthly Plan"
    }

    private var subscribeButtonText: String {
        let isYearly = selectedProductID == StoreKitManager.yearlyProductID
        let trial = isYearly ? "1 Week" : "3 Days"
        return "Start \(trial) Free Trial"
    }

    private func yearlyPerMonth() -> String? {
        guard let product = storeKit.yearlyProduct else { return nil }
        let monthly = product.price / 12
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = product.priceFormatStyle.locale
        let formatted = formatter.string(from: NSDecimalNumber(decimal: monthly)) ?? "\(monthly)"
        return "\(formatted)/mo"
    }

    // MARK: - Trigger-aware hero copy

    /// True when the paywall was opened from a running-related gate. Used to
    /// lead the hero with the benefit closest to the user's current intent —
    /// runners shouldn't have to read "Track every meal" before they see the
    /// thing they actually came for.
    private var isRunningTrigger: Bool {
        trigger.lowercased().contains("running")
    }

    private var heroHeadline: String {
        if isRunningTrigger {
            return "Train smarter.\nReach your goals."
        }
        return "Eat better.\nMove further."
    }

    private var heroSubhead: String {
        if isRunningTrigger {
            return "Personalised AI plans that adapt to your progress — plus everything Yumo offers. Free for 7 days."
        }
        return "AI scans, smart logging, and personalised training. Built around you. Free for 7 days."
    }

    // MARK: - Yearly savings

    /// Percentage saved on the yearly plan vs paying monthly for 12 months.
    /// Computed from real product prices when StoreKit has loaded; falls
    /// back to nil so the badge degrades gracefully to "Best Value" alone.
    private var yearlySavingsPercent: Int? {
        guard let yearly = storeKit.yearlyProduct,
              let monthly = storeKit.monthlyProduct,
              monthly.price > 0 else { return nil }
        let twelveMonthsCost = monthly.price * 12
        guard twelveMonthsCost > 0 else { return nil }
        let savings = (twelveMonthsCost - yearly.price) / twelveMonthsCost
        let percent = NSDecimalNumber(decimal: savings * 100).intValue
        // Sanity-clamp so a misconfigured product can't render "Save -8%".
        guard percent > 0 else { return nil }
        return percent
    }

    private var yearlyBadgeText: String {
        if let percent = yearlySavingsPercent {
            return "BEST VALUE · SAVE \(percent)%"
        }
        return "BEST VALUE"
    }
}

#Preview {
    PaywallView()
        .environmentObject(ThemeManager())
}

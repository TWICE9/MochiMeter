// MainTabView.swift

import SwiftUI
import SwiftData
import Auth

struct MainTabView: View {

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var authManager: AuthManager
    @Environment(\.colorScheme) private var colorScheme

    @EnvironmentObject var tabRouter: TabRouter
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var deepLinkManager: DeepLinkManager

    // Legacy tab bar state
    @State private var showFabMenu = false
    @State private var showFabMenuItems = false
    @Namespace private var tabAnimation

    var body: some View {
        mainTabContent
        // MARK: - Shared Modifiers
        .onOpenURL { url in
            handleDeepLink(url: url)
        }
        .alert("Discard Changes?", isPresented: $tabRouter.showUnsavedChangesAlert) {
            Button("Discard", role: .destructive) {
                tabRouter.confirmDiscardAndSwitch()
            }
            Button("Keep Editing", role: .cancel) {
                tabRouter.pendingTab = nil
            }
        } message: {
            Text("You have unsaved changes. Are you sure you want to discard them?")
        }
    }

    @ViewBuilder
    private var mainTabContent: some View {
        ZStack {
            // Each tab paints its own opaque background, so we don't need a
            // shared background layer here. The previous full-screen 60pt blur
            // was wasted GPU work behind always-opaque tab content.
            Color("AppPrimaryDark").ignoresSafeArea()

            // ── Persistent tab rendering ──────────────────────────────────
            // All tabs are kept alive simultaneously, just shown or hidden via
            // opacity + hit-testing. This mirrors how UITabBarController works
            // internally and is the reason native TabView feels instant.
            //
            // The previous `switch tabRouter.selectedTab { ... }` pattern was
            // destroying and recreating HealthRingsView on every tab switch,
            // which re-fired every @StateObject init, @Query subscription, and
            // .task modifier — causing the observed lag.
            // ─────────────────────────────────────────────────────────────────
            let activeTab = tabRouter.selectedTab

            HomeScreen()
                .environmentObject(themeManager)
                .opacity(activeTab == .home ? 1 : 0)
                .allowsHitTesting(activeTab == .home)
                .accessibilityHidden(activeTab != .home)

            HealthRingsView()
                .environmentObject(themeManager)
                .opacity(activeTab == .health ? 1 : 0)
                .allowsHitTesting(activeTab == .health)
                .accessibilityHidden(activeTab != .health)

            ReportsView(userId: authManager.currentUser?.id.uuidString.lowercased() ?? "")
                .environmentObject(themeManager)
                .opacity(activeTab == .reports ? 1 : 0)
                .allowsHitTesting(activeTab == .reports)
                .accessibilityHidden(activeTab != .reports)

            MoreScreen()
                .environmentObject(themeManager)
                .opacity(activeTab == .more ? 1 : 0)
                .allowsHitTesting(activeTab == .more)
                .accessibilityHidden(activeTab != .more)

            // FAB pop-up menu
            if showFabMenu {
                ZStack {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .onTapGesture {
                            closeFabMenu()
                        }

                    VStack {
                        Spacer()
                        HStack(spacing: 16) {
                            FabMenuButton(
                                title: "Food",
                                subtitle: "Find or log foods",
                                systemImage: "magnifyingglass",
                                accent: themeManager.currentTheme.buttonGradient(for: colorScheme)[0],
                                action: {
                                    let haptic = UIImpactFeedbackGenerator(style: .medium); haptic.impactOccurred()
                                    closeFabMenu {
                                        tabRouter.selectedTab = .home
                                        tabRouter.homePath = NavigationPath()
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                            tabRouter.homePath.append(HomeDestination.search)
                                        }
                                    }
                                }
                            )
                            .opacity(showFabMenuItems ? 1 : 0)
                            .scaleEffect(showFabMenuItems ? 1 : 0.8)
                            .animation(.spring(response: 0.35, dampingFraction: 0.75).delay(0.05), value: showFabMenuItems)

                            FabMenuButton(
                                title: "Scan",
                                subtitle: "Camera & Barcodes",
                                systemImage: "camera.viewfinder",
                                accent: themeManager.currentTheme.buttonGradient(for: colorScheme)[1],
                                action: {
                                    let haptic = UIImpactFeedbackGenerator(style: .medium); haptic.impactOccurred()
                                    closeFabMenu { deepLinkManager.showScanner = true }
                                }
                            )
                            .opacity(showFabMenuItems ? 1 : 0)
                            .scaleEffect(showFabMenuItems ? 1 : 0.8)
                            .animation(.spring(response: 0.35, dampingFraction: 0.75).delay(0.1), value: showFabMenuItems)
                        }
                        .tutorialTarget(id: "fabMenuOptions")
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .onAppear { animateFabMenuIn() }
                        .onDisappear { showFabMenuItems = false }
                    }
                }
                .transition(.opacity)
                .zIndex(5)
            }
        }
        .safeAreaInset(edge: .bottom) {
            _buildCustomTabBar()
        }
        .ignoresSafeArea(edges: .bottom)
        .onAppear {
            DatabaseSeeder.seedIfEmpty(context: modelContext)
        }
        // Auto-open FAB menu when tutorial reaches that step
        .onChange(of: TutorialManager.shared.currentStepIndex) { _, newIndex in
            let tutorial = TutorialManager.shared
            if tutorial.isShowingTutorial && !tutorial.isShowingWelcome {
                if let step = tutorial.currentStep, step.id == "fabMenuOptions" {
                    if !showFabMenu {
                        openFabMenu()
                    }
                }
            }
        }
        // Close FAB menu when tutorial ends
        .onChange(of: TutorialManager.shared.isShowingTutorial) { _, isShowing in
            if !isShowing && showFabMenu {
                closeFabMenu()
            }
        }
    }

    // MARK: - Deep Linking

    private func handleDeepLink(url: URL) {
        print("🚀 MainTabView Deep Link received: \(url.absoluteString)")

        if url.absoluteString == "yumo://home" {
            tabRouter.selectedTab = .home
            tabRouter.homePath = NavigationPath()
        }
    }

    // MARK: - Legacy Custom Tab Bar

    @ViewBuilder
    private func _buildCustomTabBar() -> some View {
        let activeColor: Color = {
            if colorScheme == .light && (themeManager.currentTheme == .mango || themeManager.currentTheme == .matcha) {
                return Color.black.opacity(0.8)
            }
            return colorScheme == .dark
                ? themeManager.currentTheme.darkPrimaryColor
                : themeManager.currentTheme.primaryColor
        }()
        let inactiveColor: Color = colorScheme == .dark
            ? Color.white.opacity(0.5)
            : Color.black.opacity(0.45)

        HStack(spacing: 16) {
            // Navigation Pill
            ZStack {
                if #unavailable(iOS 26) {
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)

                    Capsule()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    .white.opacity(colorScheme == .light ? 0.6 : 0.3),
                                    .white.opacity(colorScheme == .light ? 0.2 : 0.05)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                }

                HStack(alignment: .center, spacing: 0) {
                    _buildTabItem(tab: .home, activeColor: activeColor, inactiveColor: inactiveColor) {
                        tabRouter.attemptTabSwitch(to: .home)
                    }
                    _buildTabItem(tab: .health, activeColor: activeColor, inactiveColor: inactiveColor) {
                        tabRouter.attemptTabSwitch(to: .health)
                    }
                    _buildTabItem(tab: .reports, activeColor: activeColor, inactiveColor: inactiveColor) {
                        tabRouter.attemptTabSwitch(to: .reports)
                    }
                    _buildTabItem(tab: .more, activeColor: activeColor, inactiveColor: inactiveColor) {
                        tabRouter.attemptTabSwitch(to: .more)
                    }
                }
                .padding(.horizontal, 12)
            }
            .frame(height: 70)
            .modifier(GlassEffectModifier(shape: .capsule))

            // FAB
            Button {
                let haptic = UIImpactFeedbackGenerator(style: .medium)
                haptic.impactOccurred()
                if showFabMenu {
                    closeFabMenu()
                } else {
                    openFabMenu()
                }
            } label: {
                ZStack {
                    if #unavailable(iOS 26) {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)

                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        .white.opacity(colorScheme == .light ? 0.6 : 0.3),
                                        .white.opacity(colorScheme == .light ? 0.2 : 0.05)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                            .frame(width: 70, height: 70)
                    }

                    Image(systemName: "plus")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(
                            (colorScheme == .light && (themeManager.currentTheme == .mango || themeManager.currentTheme == .matcha))
                            ? LinearGradient(
                                colors: [.black.opacity(0.8), .black.opacity(0.6)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            : LinearGradient(
                                colors: themeManager.currentTheme.buttonGradient(for: colorScheme),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .frame(width: 70, height: 70)
                .contentShape(Circle())
            }
            .modifier(GlassEffectModifier(shape: .circle))
            .buttonStyle(ScaleButtonStyle())
            .tutorialTarget(id: "fabButton")
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
    }

    struct ScaleButtonStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
        }
    }

    // MARK: - Legacy Tab Item

    @ViewBuilder
    private func _buildTabItem(tab: AppTab, activeColor: Color, inactiveColor: Color, action: @escaping () -> Void) -> some View {
        let isSelected = tabRouter.selectedTab == tab
        let glowColor: Color = (colorScheme == .light && themeManager.currentTheme == .mango) ? themeManager.currentTheme.darkPrimaryColor : activeColor

        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                action()
            }
            let haptic = UIImpactFeedbackGenerator(style: .light)
            haptic.impactOccurred()
        }) {
            ZStack {
                if isSelected {
                    Capsule()
                        .fill(glowColor.opacity(0.15))
                        .matchedGeometryEffect(id: "TabBackground", in: tabAnimation)
                }

                VStack(spacing: 4) {
                    Image(systemName: tab.icon)
                        .font(.system(size: 20, weight: isSelected ? .bold : .semibold))
                        .foregroundStyle(isSelected ? activeColor : inactiveColor)
                        .scaleEffect(isSelected ? 1.1 : 1.0)

                    Text(tab.label)
                        .font(.caption2)
                        .fontWeight(isSelected ? .semibold : .regular)
                        .foregroundStyle(isSelected ? activeColor : inactiveColor)
                }
                .padding(.vertical, 10)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 55)
            .contentShape(Rectangle())
        }
        .buttonStyle(ScaleButtonStyle())
    }

    // MARK: - FAB Helpers

    private func openFabMenu() {
        showFabMenuItems = false
        withAnimation(.easeInOut(duration: 0.2)) {
            showFabMenu = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            animateFabMenuIn()
        }
    }

    private func closeFabMenu(completion: (() -> Void)? = nil) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            showFabMenuItems = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.easeInOut(duration: 0.2)) {
                showFabMenu = false
            }
            completion?()
        }
    }

    private func animateFabMenuIn() {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.9)) {
            showFabMenuItems = true
        }
    }
}

// MARK: - FAB Menu Button Component
struct FabMenuButton: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let accent: Color
    let action: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let isLight = colorScheme == .light
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.title.weight(.semibold))
                    .foregroundStyle(isLight ? .white : accent)
                    .frame(width: 60, height: 60)
                    .background(
                        colorScheme == .light
                            ? accent
                            : Color.white.opacity(0.12)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                VStack(spacing: 4) {
                    Text(title)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(isLight ? .black : .white)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(isLight ? .black.opacity(0.6) : .white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .padding(.horizontal, 4)
                }
            }
            .padding(16)
            .frame(width: 165, height: 165)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(isLight ? Color.white : Color(red: 26/255, green: 26/255, blue: 32/255))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(
                                .linearGradient(
                                    colors: [
                                        isLight ? .black.opacity(0.05) : .white.opacity(0.15),
                                        isLight ? .black.opacity(0.02) : .white.opacity(0.05)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
            )
            .shadow(
                color: colorScheme == .light ? Color.black.opacity(0.15) : .black.opacity(0.4),
                radius: 16,
                y: 8
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Legacy Tab Button (kept for compatibility)
struct TabButton: View {
    let icon: String
    let label: String
    let isSelected: Bool
    var activeColor: Color = Color("AppSecondaryAccent")
    var inactiveColor: Color = .gray.opacity(0.6)
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(isSelected ? activeColor : inactiveColor)
                Text(label)
                    .font(.caption2)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundStyle(isSelected ? activeColor : inactiveColor)
            }
            .frame(maxWidth: .infinity)
        }
        .accessibilityLabel(label)
    }
}

// MARK: - Glass Effect Modifier (iOS 26 Liquid Glass, fallback no-op)
enum GlassShape {
    case capsule
    case circle
}

struct GlassEffectModifier: ViewModifier {
    let shape: GlassShape

    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            switch shape {
            case .capsule:
                content.glassEffect(.regular.interactive(), in: .capsule)
            case .circle:
                content.glassEffect(.regular.interactive(), in: .circle)
            }
        } else {
            content
        }
    }
}

// MainTabView.swift

import SwiftUI
import SwiftData

struct MainTabView: View {

    // We get the model context here to inject it into the manager objects.
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var authManager: AuthManager
    @Environment(\.colorScheme) private var colorScheme

    @StateObject private var tabRouter = TabRouter()

    // Simple initialization of FastingManager (NO ARGUMENTS)
    @StateObject private var fastingManager = FastingManager()

    // ADDED: Create the view model for the shopping list
    @StateObject private var shoppingListVM = ShoppingListViewModel()

    @State private var offset1: CGSize = .zero
    @State private var offset2: CGSize = .zero
    @State private var showAICameraView = false
    @State private var showFabMenu = false
    @State private var showFabMenuItems = false

    var body: some View {
        ZStack {
            _buildDynamicBackground()

            ZStack {
                Group {
                    switch tabRouter.selectedTab {
                    case .home:
                        HomeScreen()
                            .environmentObject(shoppingListVM)
                            .environmentObject(fastingManager)
                case .reports:
                    ReportsView()
                    case .settings:
                        SettingsScreen()
                            .environmentObject(fastingManager)
                            .environmentObject(shoppingListVM)
                    }
                }
                .id(tabRouter.selectedTab)
                .transition(.opacity)
            }
            .animation(.easeInOut(duration: 0.25), value: tabRouter.selectedTab)
            
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
                        // Centered Horizontal Row
                        HStack(spacing: 16) {
                            let buttons: [(String, String, String, Color, () -> Void)] = [
                                // Food (Left)
                                ("Food", "Find or log foods", "magnifyingglass", Color("AppPrimaryAccent"), {
                                    let haptic = UIImpactFeedbackGenerator(style: .medium); haptic.impactOccurred()
                                    closeFabMenu {
                                        tabRouter.selectedTab = .home
                                        tabRouter.homePath = NavigationPath()
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                            tabRouter.homePath.append(HomeDestination.search)
                                        }
                                    }
                                }),
                                // Scan (Right)
                                ("Scan", "Camera & Barcodes", "camera.viewfinder", Color("AppSecondaryAccent"), {
                                    let haptic = UIImpactFeedbackGenerator(style: .medium); haptic.impactOccurred()
                                    closeFabMenu { showAICameraView = true }
                                })
                            ]

                            ForEach(Array(buttons.enumerated()), id: \.offset) { idx, item in
                                FabMenuButton(
                                    title: item.0,
                                    subtitle: item.1,
                                    systemImage: item.2,
                                    accent: item.3,
                                    action: item.4
                                )
                                .opacity(showFabMenuItems ? 1 : 0)
                                .scaleEffect(showFabMenuItems ? 1 : 0.8)
                                .animation(.spring(response: 0.35, dampingFraction: 0.75).delay(0.05 + Double(idx) * 0.05), value: showFabMenuItems)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20) // Just above tab bar
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
        .environmentObject(tabRouter)
        .fullScreenCover(isPresented: $showAICameraView) {
            AICameraScanView()
                .environmentObject(authManager)
                .environmentObject(tabRouter)
        }
        .onAppear {
            // Call setup() here with the context
            DatabaseSeeder.seedIfEmpty(context: modelContext)
            fastingManager.setup(context: modelContext)
        }
        // ⭐️ HANDLE WIDGET DEEP LINKS ⭐️
        .onOpenURL { url in
            handleDeepLink(url: url)
        }
    }
    
    // MARK: - Deep Linking
    
    private func handleDeepLink(url: URL) {
        print("🚀 MainTabView Deep Link received: \(url.absoluteString)")

        if url.absoluteString == "yumo://scan" {
            // Open the AI Camera view directly
            showAICameraView = true
        } else if url.absoluteString == "yumo://home" {
            // Just switch to Home and reset stack (for Calorie/Water widgets)
            tabRouter.selectedTab = .home
            tabRouter.homePath = NavigationPath()
        }
        // Note: Password reset deep links are handled in ContentView
    }

    // MARK: - View Builders

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
        .onAppear { animateOrbs() }
    }
    
    private func animateOrbs() {
        withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
            offset1 = CGSize(width: 80, height: 60)
        }
        withAnimation(.easeInOut(duration: 10).repeatForever(autoreverses: true)) {
            offset2 = CGSize(width: -100, height: -70)
        }
    }

    @ViewBuilder
    private func _buildCustomTabBar() -> some View {
        let tabBackground: Color = colorScheme == .dark
            ? Color(red: 28/255, green: 28/255, blue: 32/255)
            : Color(red: 244/255, green: 244/255, blue: 246/255)
        let borderColor: Color = colorScheme == .dark
            ? Color.white.opacity(0.08)
            : Color.black.opacity(0.05)
        let activeColor: Color = colorScheme == .dark
            ? Color.white
            : Color("AppPrimaryAccent")
        let inactiveColor: Color = colorScheme == .dark
            ? Color.white.opacity(0.5)
            : Color.black.opacity(0.45)

        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(tabBackground)
                .frame(height: 70)
                .overlay(
                    RoundedRectangle(cornerRadius: 34)
                        .stroke(borderColor, lineWidth: 1.5)
                )
                .shadow(color: .black.opacity(0.2), radius: 12, y: 4)
                .padding(.horizontal, 22)
                .padding(.bottom, 10)

            HStack(alignment: .center, spacing: 20) {
                TabButton(
                    icon: Tab.home.icon,
                    label: Tab.home.label,
                    isSelected: tabRouter.selectedTab == .home,
                    activeColor: activeColor,
                    inactiveColor: inactiveColor
                ) {
                    let haptic = UIImpactFeedbackGenerator(style: .light)
                    haptic.impactOccurred()
                    if tabRouter.selectedTab == .home {
                        tabRouter.homePath = NavigationPath()
                    } else {
                        tabRouter.selectedTab = .home
                    }
                }

                TabButton(
                    icon: Tab.reports.icon,
                    label: Tab.reports.label,
                    isSelected: tabRouter.selectedTab == .reports,
                    activeColor: activeColor,
                    inactiveColor: inactiveColor
                ) {
                    let haptic = UIImpactFeedbackGenerator(style: .light)
                    haptic.impactOccurred()
                    tabRouter.selectedTab = .reports
                }

                TabButton(
                    icon: Tab.settings.icon,
                    label: Tab.settings.label,
                    isSelected: tabRouter.selectedTab == .settings,
                    activeColor: activeColor,
                    inactiveColor: inactiveColor
                ) {
                    let haptic = UIImpactFeedbackGenerator(style: .light)
                    haptic.impactOccurred()
                    tabRouter.selectedTab = .settings
                }

                // Plus button on the right (prominent)
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
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: colorScheme == .light
                                        ? [Color(red: 0.3, green: 0.7, blue: 0.4), Color(red: 0.2, green: 0.5, blue: 0.9)]
                                        : [Color("AppPrimaryAccent"), Color("AppSecondaryAccent")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 60, height: 60)
                            .shadow(
                                color: colorScheme == .light
                                    ? Color(red: 0.2, green: 0.5, blue: 0.9).opacity(0.4)
                                    : Color("AppPrimaryAccent").opacity(0.35),
                                radius: 10,
                                y: 4
                            )

                        Image(systemName: "plus")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(.plain)
                .offset(y: -2)
            }
            .padding(.horizontal, 26)
            .padding(.vertical, 12)
        }
    }
    
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

// MARK: - Tab Button Component
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
            .frame(width: 165, height: 165) // Square Size
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

// Screens/MoreScreen.swift

import SwiftUI
import SwiftData
import Auth

struct MoreScreen: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var fastingManager: FastingManager
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var tabRouter: TabRouter

    @State private var loadedGoals: UserGoals?
    @Query(sort: \LoggedFood.timestamp, order: .reverse) private var allFoodLogs: [LoggedFood]

    // Sheet states
    @State private var showCoach = false
    @State private var showFasting = false
    @State private var showSleep = false
    @State private var showRecovery = false
    @State private var showRunningPlan = false
    @AppStorage("running_onboarding_banner_dismissed") private var runningBannerDismissed = false

    // Auth States
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var showSignOutAlert = false
    @State private var showEmailSignUp = false
    @State private var showDeleteAlert = false
    @State private var showSignInSheet = false
    
    // Name Edit States
    @State private var showNameEditSheet = false
    @State private var editingName = ""
    private var goals: UserGoals {
        loadedGoals ?? UserGoals()
    }

    // MARK: - Adaptive Colors
    private var primaryTextColor: Color {
        colorScheme == .dark ? .white : Color(red: 32/255, green: 32/255, blue: 38/255)
    }

    private var secondaryTextColor: Color {
        colorScheme == .dark ? .white.opacity(0.7) : Color(red: 120/255, green: 120/255, blue: 130/255)
    }

    private var cardBorderColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.06)
    }

    private var greetingText: String {
        if let name = loadedGoals?.name, !name.isEmpty {
            let firstName = name.components(separatedBy: " ").first ?? name
            return "Hello, \(firstName)"
        }
        return "Hello"
    }

    // Theme-aware accent colors
    private var primaryAccent: Color {
        colorScheme == .dark ? themeManager.currentTheme.darkPrimaryColor : themeManager.currentTheme.primaryColor
    }

    // Determine the sign-in provider from the user's identities
    private var signInProvider: (name: String, icon: String) {
        guard let user = authManager.currentUser,
              let identity = user.identities?.first else {
            return ("Email", "envelope.fill")
        }

        switch identity.provider.lowercased() {
        case "apple":
            return ("Apple", "apple.logo")
        case "google":
            return ("Google", "g.circle.fill")
        case "email":
            return ("Email", "envelope.fill")
        default:
            return ("Email", "envelope.fill")
        }
    }

    private var secondaryAccent: Color {
        colorScheme == .dark ? themeManager.currentTheme.darkSecondaryColor : themeManager.currentTheme.secondaryColor
    }

    // MARK: - Profile Initials
    private var profileInitials: String {
        if let name = loadedGoals?.name, !name.isEmpty {
            let parts = name.components(separatedBy: " ")
            let first = parts.first?.prefix(1) ?? ""
            let last = parts.count > 1 ? parts.last!.prefix(1) : ""
            return "\(first)\(last)".uppercased()
        }
        return "?"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DynamicBackgroundView()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 28) {

                        // MARK: - Profile Header Bubble
                        VStack(spacing: 14) {
                            // Circular avatar bubble
                            Button {
                                editingName = goals.name
                                showNameEditSheet = true
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                colors: themeManager.currentTheme.buttonGradient(for: colorScheme),
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 80, height: 80)
                                        .shadow(color: primaryAccent.opacity(0.3), radius: 12, y: 4)

                                    Text(profileInitials)
                                        .font(.system(size: 28, weight: .bold, design: .rounded))
                                        .foregroundStyle(.white)

                                    // Edit badge
                                    Circle()
                                        .fill(colorScheme == .dark ? Color(UIColor.secondarySystemGroupedBackground) : .white)
                                        .frame(width: 26, height: 26)
                                        .overlay(
                                            Image(systemName: "pencil")
                                                .font(.system(size: 11, weight: .bold))
                                                .foregroundStyle(primaryAccent)
                                        )
                                        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
                                        .offset(x: 28, y: 28)
                                }
                            }
                            .buttonStyle(.plain)

                            Text(greetingText)
                                .font(.title2.weight(.bold))
                                .foregroundStyle(primaryTextColor)

                            // Account status pill + sign out
                            if let user = authManager.currentUser {
                                VStack(spacing: 8) {
                                    HStack(spacing: 6) {
                                        Image(systemName: signInProvider.icon)
                                            .font(.caption2.weight(.semibold))
                                        Text(user.email ?? "Private Relay")
                                            .font(.caption)
                                            .lineLimit(1)
                                    }
                                    .foregroundStyle(secondaryTextColor)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 6)
                                    .background(
                                        Capsule()
                                            .fill(primaryTextColor.opacity(0.06))
                                    )

                                    Button {
                                        showSignOutAlert = true
                                    } label: {
                                        HStack(spacing: 5) {
                                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                                .font(.caption.weight(.semibold))
                                            Text("Sign Out")
                                                .font(.caption.weight(.semibold))
                                        }
                                        .foregroundStyle(.red)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 6)
                                        .background(
                                            Capsule()
                                                .fill(Color.red.opacity(0.1))
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            } else {
                                Button {
                                    showSignInSheet = true
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "person.crop.circle.badge.plus")
                                            .font(.caption.weight(.semibold))
                                        Text("Sign In to Sync")
                                            .font(.caption.weight(.semibold))
                                    }
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(
                                        Capsule()
                                            .fill(
                                                LinearGradient(
                                                    colors: themeManager.currentTheme.buttonGradient(for: colorScheme),
                                                    startPoint: .leading,
                                                    endPoint: .trailing
                                                )
                                            )
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)

                        // MARK: - Settings
                        _listSection("Settings") {
                            NavigationLink {
                                ProfileGoalsView(goals: goals)
                            } label: {
                                _listRow(icon: "person.fill", iconColor: .blue, title: "Profile & Goals")
                            }.buttonStyle(.plain)
                            _rowDivider()
                            NavigationLink {
                                AppearanceSettingsView()
                                    .environmentObject(themeManager)
                            } label: {
                                _listRow(icon: "paintbrush.fill", iconColor: primaryAccent, title: "Appearance & Theme")
                            }.buttonStyle(.plain)
                            _rowDivider()
                            NavigationLink {
                                NotificationSettingsView()
                            } label: {
                                _listRow(icon: "bell.fill", iconColor: .red, title: "Notifications")
                            }.buttonStyle(.plain)
                            _rowDivider()
                            NavigationLink {
                                HealthIntegrationView()
                            } label: {
                                _listRow(icon: "heart.fill", iconColor: .pink, title: "Apple Health")
                            }.buttonStyle(.plain)
                            _rowDivider()
                            NavigationLink {
                                WidgetShowcaseView()
                            } label: {
                                _listRow(icon: "square.grid.2x2.fill", iconColor: .cyan, title: "Widgets")
                            }.buttonStyle(.plain)
                        }

                        // MARK: - Features
                        _listSection("Features") {
                            Button { showCoach = true } label: {
                                _listRow(icon: "brain.head.profile.fill", iconColor: .purple, title: "Mochi AI Coach")
                            }.buttonStyle(.plain)
                            _rowDivider()
                            Button { showFasting = true } label: {
                                _listRow(icon: "timer", iconColor: .orange, title: "Intermittent Fasting")
                            }.buttonStyle(.plain)
                            _rowDivider()
                            Button { showSleep = true } label: {
                                _listRow(icon: "moon.zzz.fill", iconColor: .indigo, title: "Sleep & Recovery")
                            }.buttonStyle(.plain)
                        }

                        // MARK: - About
                        _listSection("About") {
                            _linkRow(icon: "hand.raised.fill", iconColor: .gray, title: "Privacy Policy", url: "https://mochimeter.com.au/privacy/")
                            _rowDivider()
                            _linkRow(icon: "doc.text.fill", iconColor: .gray, title: "Terms of Service", url: "https://mochimeter.com.au/terms/")
                            _rowDivider()
                            _linkRow(icon: "envelope.fill", iconColor: .blue, title: "Contact Support", url: "mailto:support@mochimeter.com.au")
                            _rowDivider()
                            _linkRow(icon: "lightbulb.fill", iconColor: .yellow, title: "Feature Requests", url: "https://mochimeter.canny.io/feature-requests")
                            _rowDivider()
                            _linkRow(icon: "ant.fill", iconColor: .orange, title: "Report a Bug", url: "https://mochimeter.canny.io/bug-reports")
                            _rowDivider()
                            _linkRow(icon: "network", iconColor: .gray, title: "OpenFoodFacts API", url: "https://world.openfoodfacts.org/")
                        }

                        // MARK: - Account
                        if authManager.currentUser != nil {
                            _listSection("Account") {
                                Button(role: .destructive) {
                                    showDeleteAlert = true
                                } label: {
                                    _listRow(icon: "trash.fill", iconColor: .red, title: "Delete Account", isDestructive: true)
                                }.buttonStyle(.plain)
                            }
                        }

                        // App Version
                        Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0") (\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"))")
                            .font(.caption2)
                            .foregroundStyle(secondaryTextColor)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 4)

                        // Bottom padding for tab bar
                        Color.clear.frame(height: 80)
                    }
                    .readableContentColumn(640)
                }
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    EmptyView()
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        // MARK: - Sheet Presentations
        .sheet(isPresented: $showCoach) {
            HealthCoachView(initialContext: buildCoachContext())
        }
        .sheet(isPresented: $showFasting) {
            FastingView()
                .environmentObject(fastingManager)
        }
        .sheet(isPresented: $showRunningPlan) {
            RunningOnboardingScreen {
                showRunningPlan = false
            }
        }
        .sheet(isPresented: $showSleep) {
            SleepTrackingView()
                .environmentObject(themeManager)
        }
        .sheet(isPresented: $showRecovery) {
            SleepTrackingView()
                .environmentObject(themeManager)
        }
        .sheet(isPresented: $showSignInSheet) {
            NavigationStack {
                SettingsScreen() // Reusing SettingsScreen as the Auth sheet since we moved main content out
                    .environmentObject(fastingManager)
                    .environmentObject(themeManager)
            }
            .presentationDetents([.medium, .large])
        }
        .alert("Sign Out?", isPresented: $showSignOutAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Sign Out", role: .destructive) {
                Task {
                    await authManager.signOut()
                    // Reset onboarding to take user back to welcome screen
                    hasCompletedOnboarding = false
                    // Land on Home for the next session instead of the
                    // Settings/More tab the user signed out from.
                    await MainActor.run {
                        tabRouter.selectedTab = .home
                    }
                }
            }
        } message: {
            Text("Are you sure you want to sign out? Your unsynced data might be lost.")
        }
        .alert("Delete Account?", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                Task {
                    do {
                        try await authManager.deleteAccount()
                    } catch {
                        print("Error deleting account: \(error)")
                    }
                }
            }
        } message: {
            Text("This action cannot be undone. All your data will be permanently deleted.")
        }
        .sheet(isPresented: $showNameEditSheet) {
            _buildNameEditSheet()
                .presentationDetents([.medium])
        }
        .task {
            loadedGoals = await UserScopedQuery.fetchUserGoals(context: modelContext)
        }
    }

    // MARK: - Name Edit Logic
    private func saveNameChange() {
        // Save locally
        goals.name = editingName
        try? modelContext.save()
        
        // Sync to cloud if logged in
        if let userId = goals.userId, !userId.isEmpty {
            Task {
                await CloudSyncManager.shared.uploadUserGoalsImmediately(goals, userId: userId)
            }
        }
        
        showNameEditSheet = false
    }

    private func _buildNameEditSheet() -> some View {
        NavigationStack {
            ZStack {
                (colorScheme == .dark ? Color("AppPrimaryDark") : Color(red: 245/255, green: 245/255, blue: 247/255))
                    .ignoresSafeArea()

                VStack(spacing: 24) {
                    Image(systemName: "person.text.rectangle")
                        .font(.system(size: 60))
                        .foregroundStyle(Color.blue) // Using standard blue as accent wasn't reliably available
                        .padding(.top, 40)

                    VStack(spacing: 8) {
                        Text("Edit Your Name")
                            .font(.title).bold()
                            .foregroundStyle(primaryTextColor)

                        Text("This is how we'll greet you in the app.")
                            .font(.subheadline)
                            .foregroundStyle(secondaryTextColor)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Name")
                            .font(.headline)
                            .foregroundStyle(primaryTextColor.opacity(0.8))

                        TextField("Your name", text: $editingName)
                            .textFieldStyle(.plain)
                            .font(.body)
                            .foregroundStyle(primaryTextColor)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(primaryTextColor.opacity(0.05))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(primaryTextColor.opacity(0.1), lineWidth: 1)
                            )
                            .textContentType(.name)
                            .autocorrectionDisabled()
                    }
                    .padding(.horizontal, 24)

                    Button {
                        saveNameChange()
                    } label: {
                        Text("Save")
                            .font(.headline).bold()
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(!editingName.isEmpty ? Color.blue : Color.gray.opacity(0.3))
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(editingName.isEmpty)
                    .padding(.horizontal, 24)

                    Spacer()
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showNameEditSheet = false
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(primaryTextColor)
                    }
                }
            }
        }
    }

    // MARK: - Unified List Row Builders

    @ViewBuilder
    private func _listSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(secondaryTextColor)
                .textCase(.uppercase)
                .tracking(1)

            VStack(spacing: 0) {
                content()
            }
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(colorScheme == .dark ? Color.white.opacity(0.07) : .white)
                    .shadow(color: .black.opacity(colorScheme == .dark ? 0 : 0.04), radius: 6, y: 3)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .padding(.horizontal, 20)
    }

    @ViewBuilder
    private func _listRow(
        icon: String,
        iconColor: Color,
        title: String,
        trailingIcon: String = "chevron.right",
        isDestructive: Bool = false
    ) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(Circle().fill(iconColor.gradient))

            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(isDestructive ? .red : primaryTextColor)

            Spacer()

            Image(systemName: trailingIcon)
                .font(.caption2.weight(.bold))
                .foregroundStyle(secondaryTextColor.opacity(0.5))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func _rowDivider() -> some View {
        Divider().padding(.leading, 56)
    }

    @ViewBuilder
    private func _linkRow(icon: String, iconColor: Color, title: String, url: String) -> some View {
        Link(destination: URL(string: url)!) {
            _listRow(icon: icon, iconColor: iconColor, title: title, trailingIcon: "arrow.up.right")
        }
        .buttonStyle(.plain)
    }

    // MARK: - Coach Context Builder

    private func buildCoachContext() -> CoachContext {
        let startOfDay = Date().startOfDay
        let endOfDay = Date().endOfDay
        let todayLogs = allFoodLogs.filter { $0.timestamp >= startOfDay && $0.timestamp <= endOfDay && $0.recipe == nil }

        let totalCalories = todayLogs.reduce(0) { $0 + $1.totalCalories }
        let totalProtein = todayLogs.reduce(0) { $0 + $1.totalProtein }
        let totalCarbs = todayLogs.reduce(0) { $0 + $1.totalCarbs }
        
        // Build sleep + recovery context
        let hk = HealthKitManager.shared
        var activityParts: [String] = []
        if let sleep = hk.lastNightSleep {
            activityParts.append("Sleep: \(SleepData.formatDuration(sleep.totalSleepSeconds))")
        }
        if let hrv = hk.latestHRV {
            activityParts.append("HRV: \(Int(hrv))ms")
        }
        if let rhr = hk.latestRestingHR {
            activityParts.append("Resting HR: \(Int(rhr))bpm")
        }
        let activityString = activityParts.isEmpty ? "No recent activity data" : activityParts.joined(separator: " | ")
        
        let recoveryString: String
        if let score = hk.recoveryScore {
            recoveryString = "\(hk.recoveryStatus.label) (\(score)/100)"
        } else {
            recoveryString = "No recovery data"
        }

        return CoachContext(
            currentCalories: totalCalories,
            goalCalories: goals.dailyCalories,
            currentProtein: totalProtein,
            goalProtein: goals.dailyProtein,
            currentCarbs: totalCarbs,
            goalCarbs: goals.dailyCarbs,
            recentActivity: activityString,
            readinessStatus: recoveryString
        )
    }

}

// MARK: - Placeholder Sub-Settings Views
// These will link to existing SettingsScreen sections broken out individually

struct AppearanceSettingsView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @State private var loadedGoals: UserGoals?

    private var primaryTextColor: Color {
        colorScheme == .dark ? .white : Color(red: 32/255, green: 32/255, blue: 38/255)
    }

    private var secondaryTextColor: Color {
        colorScheme == .dark ? .white.opacity(0.7) : Color(red: 120/255, green: 120/255, blue: 130/255)
    }

    private var cardBorderColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.06)
    }

    var body: some View {
        Group {
        if let goals = loadedGoals {
            @Bindable var bindableGoals = goals

            ScrollView {
                VStack(spacing: 24) {
                    // Color Scheme
                    FrostedGlassContainer {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Color Scheme")
                                .font(.headline)
                                .foregroundStyle(primaryTextColor)

                            Picker("Appearance", selection: $bindableGoals.appearanceMode) {
                                ForEach(AppearanceMode.allCases, id: \.self) { mode in
                                    Text(mode.rawValue).tag(mode)
                                }
                            }
                            .pickerStyle(.segmented)
                            .onChange(of: bindableGoals.appearanceMode) { _, newMode in
                                applyAppearanceMode(newMode)
                            }

                            Text("Choose how MochiMeter looks. System follows your device settings.")
                                .font(.caption)
                                .foregroundStyle(secondaryTextColor)
                        }
                    }
                    .padding(.horizontal, 24)

                    // Measurement Units
                    FrostedGlassContainer {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Measurement Units")
                                .font(.headline)
                                .foregroundStyle(primaryTextColor)

                            Picker("Units", selection: $bindableGoals.unitSystem) {
                                ForEach(UnitSystem.allCases, id: \.self) { system in
                                    Text(system.displayName).tag(system)
                                }
                            }
                            .pickerStyle(.segmented)
                            .onChange(of: bindableGoals.unitSystem) { _, newSystem in
                                try? modelContext.save()
                            }

                            Text("Choose between \(bindableGoals.unitSystem == .metric ? "kg/cm" : "lbs/ft") for weight and height measurements.")
                                .font(.caption)
                                .foregroundStyle(secondaryTextColor)
                        }
                    }
                    .padding(.horizontal, 24)

                    // Energy Units
                    FrostedGlassContainer {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Energy Units")
                                .font(.headline)
                                .foregroundStyle(primaryTextColor)

                            Picker("Energy Units", selection: $bindableGoals.energyUnit) {
                                ForEach(EnergyUnit.allCases, id: \.self) { unit in
                                    Text(unit.rawValue).tag(unit)
                                }
                            }
                            .pickerStyle(.segmented)
                            .onChange(of: bindableGoals.energyUnit) { _, newUnit in
                                try? modelContext.save()
                            }

                            Text("Choose between Calories (kcal) and Kilojoules (kJ).")
                                .font(.caption)
                                .foregroundStyle(secondaryTextColor)
                        }
                    }
                    .padding(.horizontal, 24)

                    // Theme
                    FrostedGlassContainer {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Mochi Theme")
                                .font(.headline)
                                .foregroundStyle(primaryTextColor)

                            Text("Choose your favorite mochi flavor")
                                .font(.caption)
                                .foregroundStyle(secondaryTextColor)

                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                                ForEach(MochiTheme.allCases, id: \.self) { theme in
                                    MochiThemeButton(
                                        theme: theme,
                                        isSelected: themeManager.currentTheme == theme,
                                        action: {
                                            let haptic = UIImpactFeedbackGenerator(style: .medium)
                                            haptic.impactOccurred()
                                            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                                themeManager.currentTheme = theme
                                            }
                                        }
                                    )
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                }
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
            .navigationTitle("Appearance")
            .navigationBarTitleDisplayMode(.large)
            .background(Color("AppPrimaryDark").ignoresSafeArea())
        } else {
            ProgressView()
                .navigationTitle("Appearance")
        }
        }
        .task {
            loadedGoals = await UserScopedQuery.fetchUserGoals(context: modelContext)
        }
    }

    private func applyAppearanceMode(_ mode: AppearanceMode) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        for window in windowScene.windows {
            switch mode {
            case .light:
                window.overrideUserInterfaceStyle = .light
            case .dark:
                window.overrideUserInterfaceStyle = .dark
            case .system:
                window.overrideUserInterfaceStyle = .unspecified
            }
        }
    }
}

struct NotificationSettingsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @State private var loadedGoals: UserGoals?
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined

    private var primaryTextColor: Color {
        colorScheme == .dark ? .white : Color(red: 32/255, green: 32/255, blue: 38/255)
    }

    private var secondaryTextColor: Color {
        colorScheme == .dark ? .white.opacity(0.7) : Color(red: 120/255, green: 120/255, blue: 130/255)
    }

    private var cardBorderColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.06)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if let goals = loadedGoals {
                    @Bindable var bindableGoals = goals

                    FrostedGlassContainer {
                        VStack(alignment: .leading, spacing: 12) {
                            // Status
                            HStack(spacing: 8) {
                                Image(systemName: notificationStatus == .authorized ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                                    .foregroundStyle(notificationStatus == .authorized ? .green : .orange)

                                Text(notificationStatus == .authorized ? "Notifications enabled" : "Notifications disabled")
                                    .font(.subheadline)
                                    .foregroundStyle(primaryTextColor)

                                Spacer()
                            }
                            .padding(.vertical, 8)

                            Button {
                                Task {
                                    if notificationStatus == .authorized {
                                        if let url = URL(string: UIApplication.openSettingsURLString) {
                                            await UIApplication.shared.open(url)
                                        }
                                    } else {
                                        let center = UNUserNotificationCenter.current()
                                        let granted = try? await center.requestAuthorization(options: [.alert, .badge, .sound])
                                        if granted == true {
                                            notificationStatus = .authorized
                                        }
                                    }
                                }
                            } label: {
                                HStack {
                                    Image(systemName: notificationStatus == .authorized ? "gear" : "bell.badge.fill")
                                    Text(notificationStatus == .authorized ? "Open iOS Settings" : "Enable Notifications")
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                }
                                .font(.headline)
                                .foregroundStyle(primaryTextColor)
                                .padding(.vertical, 10)
                                .padding(.horizontal, 12)
                                .background(
                                    notificationStatus == .authorized
                                        ? primaryTextColor.opacity(colorScheme == .dark ? 0.12 : 0.08)
                                        : Color("AppPrimaryAccent").opacity(colorScheme == .dark ? 0.3 : 0.2)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }

                            if notificationStatus == .authorized {
                                Divider().background(cardBorderColor)

                                // Meal Reminders
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack {
                                            Image(systemName: "fork.knife")
                                                .foregroundStyle(Color("AppSecondaryAccent"))
                                            Text("Meal Reminders")
                                                .font(.headline)
                                                .foregroundStyle(primaryTextColor)
                                        }
                                        Text("Receive reminders every 4 hours (7am-9pm).")
                                            .font(.caption)
                                            .foregroundStyle(secondaryTextColor)
                                    }
                                    Spacer()
                                    Toggle("", isOn: $bindableGoals.mealRemindersEnabled)
                                        .labelsHidden()
                                }

                                Divider().background(cardBorderColor)

                                // Weekly Weight
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack {
                                            Image(systemName: "figure.stand.line.dotted.figure.stand")
                                                .foregroundStyle(Color("AppSecondaryAccent"))
                                            Text("Weekly Weight Check-In")
                                                .font(.headline)
                                                .foregroundStyle(primaryTextColor)
                                        }
                                        Text("Get reminded every Monday at 9 AM.")
                                            .font(.caption)
                                            .foregroundStyle(secondaryTextColor)
                                    }
                                    Spacer()
                                    Toggle("", isOn: $bindableGoals.weeklyWeightReminderEnabled)
                                        .labelsHidden()
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                }
            }
            .padding(.top, 16)
            .padding(.bottom, 40)
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.large)
        .background(Color("AppPrimaryDark").ignoresSafeArea())
        .task {
            loadedGoals = await UserScopedQuery.fetchUserGoals(context: modelContext)
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            notificationStatus = settings.authorizationStatus
        }
    }
}

struct HealthIntegrationView: View {
    @Environment(\.colorScheme) private var colorScheme

    private var primaryTextColor: Color {
        colorScheme == .dark ? .white : Color(red: 32/255, green: 32/255, blue: 38/255)
    }

    private var secondaryTextColor: Color {
        colorScheme == .dark ? .white.opacity(0.7) : Color(red: 120/255, green: 120/255, blue: 130/255)
    }

    private var cardBorderColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.06)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                FrostedGlassContainer {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 12) {
                            Image(systemName: "heart.fill")
                                .font(.title2)
                                .foregroundStyle(.red)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Apple Health")
                                    .font(.headline)
                                    .foregroundStyle(primaryTextColor)
                                Text("Sync steps, weight, and calories burnt")
                                    .font(.caption)
                                    .foregroundStyle(secondaryTextColor)
                            }

                            Spacer()

                            if HealthKitManager.shared.isAuthorized {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                    .font(.title2)
                            }
                        }

                        Divider().background(cardBorderColor)

                        Button {
                            Task {
                                if HealthKitManager.shared.isAuthorized {
                                    if let url = URL(string: "x-apple-health://") {
                                        await UIApplication.shared.open(url)
                                    }
                                } else {
                                    do {
                                        try await HealthKitManager.shared.requestAuthorization()
                                        await HealthKitManager.shared.fetchTodayActivity()
                                    } catch {
                                        print("HealthKit authorization failed: \(error.localizedDescription)")
                                    }
                                }
                            }
                        } label: {
                            HStack {
                                Image(systemName: HealthKitManager.shared.isAuthorized ? "gear" : "heart.text.square.fill")
                                Text(HealthKitManager.shared.isAuthorized ? "Open Health Settings" : "Connect to Apple Health")
                                Spacer()
                                Image(systemName: "chevron.right")
                            }
                            .font(.headline)
                            .foregroundStyle(primaryTextColor)
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 24)
            }
            .padding(.top, 16)
            .padding(.bottom, 40)
        }
        .navigationTitle("Apple Health")
        .navigationBarTitleDisplayMode(.large)
        .background(Color("AppPrimaryDark").ignoresSafeArea())
    }
}

struct WidgetShowcaseView: View {
    @Environment(\.colorScheme) private var colorScheme

    private var secondaryTextColor: Color {
        colorScheme == .dark ? .white.opacity(0.7) : Color(red: 120/255, green: 120/255, blue: 130/255)
    }

    private var primaryTextColor: Color {
        colorScheme == .dark ? .white : Color(red: 32/255, green: 32/255, blue: 38/255)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Home Screen Widgets
                VStack(alignment: .leading, spacing: 16) {
                    Text("Home Screen")
                        .font(.headline)
                        .foregroundStyle(primaryTextColor)
                        .padding(.horizontal, 24)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            VStack(spacing: 8) {
                                CalorieWidgetPreview(colorScheme: colorScheme)
                                Text("Calories")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(secondaryTextColor)
                            }
                            VStack(spacing: 8) {
                                WaterWidgetPreview(colorScheme: colorScheme)
                                Text("Water")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(secondaryTextColor)
                            }
                            VStack(spacing: 8) {
                                ScanWidgetPreview(colorScheme: colorScheme)
                                Text("Quick Scan")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(secondaryTextColor)
                            }
                        }
                        .padding(.horizontal, 24)
                    }

                    FrostedGlassContainer {
                        HStack(spacing: 12) {
                            Image(systemName: "lightbulb.fill")
                                .foregroundStyle(.yellow)
                                .font(.title3)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Add widgets to your Home Screen")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(primaryTextColor)
                                Text("Long press your Home Screen → tap + → search \"MochiMeter\"")
                                    .font(.caption)
                                    .foregroundStyle(secondaryTextColor)
                            }
                            Spacer()
                        }
                    }
                    .padding(.horizontal, 24)
                }

                // Lock Screen Widgets
                VStack(alignment: .leading, spacing: 16) {
                    Text("Lock Screen")
                        .font(.headline)
                        .foregroundStyle(primaryTextColor)
                        .padding(.horizontal, 24)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            VStack(spacing: 8) {
                                LockScreenCircularWidgetPreview()
                                Text("Calories")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(secondaryTextColor)
                            }
                            VStack(spacing: 8) {
                                LockScreenRectangularWidgetPreview()
                                Text("Daily Summary")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(secondaryTextColor)
                            }
                            VStack(spacing: 8) {
                                LockScreenScanWidgetPreview()
                                Text("Quick Scan")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(secondaryTextColor)
                            }
                        }
                        .padding(.horizontal, 24)
                    }

                    FrostedGlassContainer {
                        HStack(spacing: 12) {
                            Image(systemName: "lock.fill")
                                .foregroundStyle(.cyan)
                                .font(.title3)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Add widgets to your Lock Screen")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(primaryTextColor)
                                Text("Long press Lock Screen → Customize → tap widgets area → find \"MochiMeter\"")
                                    .font(.caption)
                                    .foregroundStyle(secondaryTextColor)
                            }
                            Spacer()
                        }
                    }
                    .padding(.horizontal, 24)
                }
            }
            .padding(.top, 16)
            .padding(.bottom, 40)
        }
        .navigationTitle("Widgets")
        .navigationBarTitleDisplayMode(.large)
        .background(Color("AppPrimaryDark").ignoresSafeArea())
    }
}

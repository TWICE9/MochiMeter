// Screens/SettingsScreen.swift

import SwiftUI
import SwiftData
import Combine
import Auth
import AuthenticationServices
import UIKit
import GoogleSignIn

struct SettingsScreen: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var fastingManager: FastingManager

    @EnvironmentObject var superwallManager: SuperwallManager
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme

    // State
    @State private var goals: UserGoals?
    @State private var showProfileSheet = false
    @State private var showFirstResetAlert = false
    @State private var showFinalResetAlert = false
    @State private var showSignOutAlert = false
    @State private var showEmailSignUp = false
    @State private var showNameEditSheet = false
    @State private var showDeleteAccountAlert = false
    @State private var showFinalDeleteAccountAlert = false
    @State private var isDeletingAccount = false
    @State private var showDeleteAccountError = false
    @State private var deleteAccountErrorMessage = ""
    @State private var editingName: String = ""

    @State private var offset1: CGSize = .zero
    @State private var offset2: CGSize = .zero

    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = true

    private var primaryTextColor: Color {
        colorScheme == .dark ? .white : Color(red: 32/255, green: 32/255, blue: 38/255)
    }

    private var secondaryTextColor: Color {
        colorScheme == .dark ? .white.opacity(0.7) : Color(red: 120/255, green: 120/255, blue: 130/255)
    }

    private var cardBorderColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.06)
    }

    private var inputBackgroundColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.1) : Color.white
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

    // Personalized greeting using the user's name from onboarding
    private var greetingText: String {
        if let name = goals?.name, !name.isEmpty {
            let firstName = name.components(separatedBy: " ").first ?? name
            return "Hello, \(firstName)"
        }
        return "Hello"
    }

    private var inputBorderColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.08)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                _buildDynamicBackground()

                ScrollView([.vertical], showsIndicators: false) {
                    VStack(spacing: 24) {

                        // MARK: - HEADER WITH GREETING
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Settings")
                                .font(.title2)
                                .fontWeight(.medium)
                                .foregroundColor(secondaryTextColor)

                            HStack(spacing: 8) {
                                Text(greetingText)
                                    .font(.largeTitle)
                                    .fontWeight(.bold)
                                    .foregroundColor(primaryTextColor)

                                Button {
                                    editingName = goals?.name ?? ""
                                    showNameEditSheet = true
                                } label: {
                                    Image(systemName: "pencil.circle.fill")
                                        .font(.title2)
                                        .foregroundStyle(Color("AppSecondaryAccent"))
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)
                        .padding(.top, 60)

                        // MARK: - PROFILE & ACCOUNT
                        if let goals {
                            @Bindable var bindableGoals = goals
                            
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Profile & Account")
                                    .font(.title3).bold()
                                    .foregroundStyle(primaryTextColor)
                                    .padding(.horizontal, 24)

                                FrostedGlassContainer {
                                    VStack(spacing: 12) {
                                        // Account Status
                                        if let user = authManager.currentUser {
                                            HStack(spacing: 8) {
                                                Image(systemName: signInProvider.icon)
                                                    .font(.headline)
                                                    .foregroundStyle(primaryTextColor)
                                                Text("Signed in with \(signInProvider.name)")
                                                    .font(.headline)
                                                    .foregroundStyle(primaryTextColor)
                                            }

                                            Text(user.email ?? "Private Relay Email")
                                                .font(.subheadline)
                                                .foregroundStyle(secondaryTextColor)

                                            Button {
                                                showSignOutAlert = true
                                            } label: {
                                                HStack(spacing: 6) {
                                                    Image(systemName: "rectangle.portrait.and.arrow.right")
                                                    Text("Sign Out")
                                                }
                                                .foregroundColor(.red)
                                                .padding(.vertical, 8)
                                                .frame(maxWidth: .infinity)
                                            }
                                            .buttonStyle(.plain)
                                            
                                            Divider()
                                                .background(cardBorderColor)

                                        } else {
                                            Text("Not signed in")
                                                .font(.headline)
                                                .foregroundStyle(primaryTextColor)

                                            Text("Sign in to sync your data across devices.")
                                                .font(.footnote)
                                                .foregroundStyle(secondaryTextColor)
                                                .padding(.bottom, 8)

                                            SignInWithAppleButtonView(
                                                onRequest: { request in
                                                    print("🍎 [SettingsScreen] Sign in button tapped - onRequest called")
                                                    authManager.appleSignInNonce = randomNonceString()
                                                    request.nonce = sha256(authManager.appleSignInNonce)
                                                    request.requestedScopes = [.fullName, .email]
                                                    print("🍎 [SettingsScreen] Request configured with nonce and scopes")
                                                },
                                                onCompletion: { authorization in
                                                    print("🍎 [SettingsScreen] onCompletion called - authorization received")
                                                    Task {
                                                        await authManager.handleAppleAuthorization(authorization)

                                                        if let user = authManager.currentUser {
                                                            await authManager.completeSignIn(user: user, modelContext: modelContext)
                                                        }

                                                        await refreshData()
                                                        print("🍎 [SettingsScreen] Sign-in flow completed")
                                                    }
                                                }
                                            )

                                            GoogleSignInButtonView(
                                                onSuccess: { idToken, accessToken, fullName in
                                                    Task {
                                                        do {
                                                            try await authManager.signInWithGoogle(
                                                                idToken: idToken,
                                                                accessToken: accessToken,
                                                                fullName: fullName
                                                            )

                                                            if let user = authManager.currentUser {
                                                                await authManager.completeSignIn(user: user, modelContext: modelContext)

                                                                goals.userId = user.id.uuidString.lowercased()
                                                                try? modelContext.save()
                                                                await authManager.uploadOnboardingToCloud(goals: goals)
                                                            }

                                                            await refreshData()
                                                            print("🔵 [SettingsScreen] Google sign-in completed")
                                                        } catch {
                                                            print("🔵 [SettingsScreen] Google sign-in failed: \(error.localizedDescription)")
                                                        }
                                                    }
                                                },
                                                onError: { error in
                                                    print("🔵 [SettingsScreen] Google sign-in error: \(error.localizedDescription)")
                                                }
                                            )
                                            
                                            Button {
                                                showEmailSignUp = true
                                            } label: {
                                                HStack {
                                                    Image(systemName: "envelope.fill")
                                                        .font(.system(size: 18))
                                                    Text("Sign up with Email")
                                                        .font(.headline)
                                                }
                                                .foregroundColor(primaryTextColor)
                                                .frame(maxWidth: .infinity)
                                                .frame(height: 50)
                                                .background(inputBackgroundColor)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .stroke(cardBorderColor, lineWidth: 1)
                                                )
                                                .cornerRadius(12)
                                            }
                                            
                                            Divider()
                                                .background(cardBorderColor)
                                        }

                                        // Edit Profile
                                        NavigationLink {
                                            ProfileEditView(goals: goals)
                                        } label: {
                                            HStack {
                                                Image(systemName: "person.fill")
                                                Text("Edit My Profile")
                                                Spacer()
                                                Image(systemName: "chevron.right")
                                            }
                                            .font(.headline)
                                            .foregroundStyle(primaryTextColor)
                                            .padding(.vertical, 8)
                                        }
                                        .buttonStyle(.plain)

                                        Divider()
                                            .background(cardBorderColor)

                                        // Nutrition Goals
                                        NavigationLink {
                                            NutritionGoalsView(goals: goals)
                                        } label: {
                                            HStack {
                                                Image(systemName: "chart.bar.fill")
                                                Text("Nutrition Goals")
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


                        // MARK: - APPEARANCE & THEME
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Appearance")
                                .font(.title3).bold()
                                .foregroundStyle(primaryTextColor)
                                .padding(.horizontal, 24)

                            FrostedGlassContainer {
                                VStack(spacing: 20) {
                                    // Light/Dark Mode Picker
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
                                    
                                    Divider()
                                        .background(cardBorderColor)
                                    
                                    // Unit System Picker
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
                                            // Save to SwiftData automatically via @Bindable
                                            try? modelContext.save()
                                            print("📏 Unit system changed to: \(newSystem.displayName)")
                                        }

                                        Text("Choose between \(bindableGoals.unitSystem == .metric ? "kg/cm" : "lbs/ft") for weight and height measurements.")
                                            .font(.caption)
                                            .foregroundStyle(secondaryTextColor)
                                    }
                                    
                                    Divider()
                                        .background(cardBorderColor)
                                    
                                    // Energy Unit Picker
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
                                            print("⚡️ Energy unit changed to: \(newUnit.rawValue)")
                                        }

                                        Text("Choose between Calories (kcal) and Kilojoules (kJ).")
                                            .font(.caption)
                                            .foregroundStyle(secondaryTextColor)
                                    }
                                    
                                    Divider()
                                        .background(cardBorderColor)
                                    
                                    // Mochi Theme Selector
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
                            }
                            .padding(.horizontal, 24)
                        }

                        // MARK: - WIDGETS SHOWCASE
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Home Screen Widgets")
                                .font(.title3).bold()
                                .foregroundStyle(primaryTextColor)
                                .padding(.horizontal, 24)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 16) {
                                    // Calorie Widget Preview
                                    VStack(spacing: 8) {
                                        CalorieWidgetPreview(colorScheme: colorScheme)
                                        Text("Calories")
                                            .font(.caption.weight(.medium))
                                            .foregroundStyle(secondaryTextColor)
                                    }

                                    // Water Widget Preview
                                    VStack(spacing: 8) {
                                        WaterWidgetPreview(colorScheme: colorScheme)
                                        Text("Water")
                                            .font(.caption.weight(.medium))
                                            .foregroundStyle(secondaryTextColor)
                                    }

                                    // Quick Scan Widget Preview
                                    VStack(spacing: 8) {
                                        ScanWidgetPreview(colorScheme: colorScheme)
                                        Text("Quick Scan")
                                            .font(.caption.weight(.medium))
                                            .foregroundStyle(secondaryTextColor)
                                    }
                                }
                                .padding(.horizontal, 24)
                            }

                            // How to add widgets tip
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

                        // MARK: - LOCK SCREEN WIDGETS SHOWCASE
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Lock Screen Widgets")
                                .font(.title3).bold()
                                .foregroundStyle(primaryTextColor)
                                .padding(.horizontal, 24)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 16) {
                                    // Circular Calorie Widget Preview
                                    VStack(spacing: 8) {
                                        LockScreenCircularWidgetPreview()
                                        Text("Calories")
                                            .font(.caption.weight(.medium))
                                            .foregroundStyle(secondaryTextColor)
                                    }

                                    // Rectangular Calorie Widget Preview
                                    VStack(spacing: 8) {
                                        LockScreenRectangularWidgetPreview()
                                        Text("Daily Summary")
                                            .font(.caption.weight(.medium))
                                            .foregroundStyle(secondaryTextColor)
                                    }

                                    // Circular Scan Widget Preview
                                    VStack(spacing: 8) {
                                        LockScreenScanWidgetPreview()
                                        Text("Quick Scan")
                                            .font(.caption.weight(.medium))
                                            .foregroundStyle(secondaryTextColor)
                                    }
                                }
                                .padding(.horizontal, 24)
                            }

                            // How to add lock screen widgets tip
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


                        // MARK: - NOTIFICATIONS
                        FrostedGlassContainer {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Notifications")
                                    .font(.title3).bold()
                                    .foregroundStyle(primaryTextColor)

                                Text("Enable reminders to protect streaks and keep logging on track.")
                                    .font(.footnote)
                                    .foregroundStyle(secondaryTextColor)

                                // Status indicator
                                HStack(spacing: 8) {
                                    Image(systemName: notificationStatus == .authorized ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                                        .foregroundStyle(notificationStatus == .authorized ? .green : .orange)

                                    Text(notificationStatusText)
                                        .font(.subheadline)
                                        .foregroundStyle(primaryTextColor)

                                    Spacer()
                                }
                                .padding(.vertical, 8)

                                // Action button
                                Button {
                                    Task {
                                        await handleNotificationPermission()
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

                                    VStack(alignment: .leading, spacing: 16) {
                                        // Meal Reminders Toggle
                                        HStack {
                                            VStack(alignment: .leading, spacing: 4) {
                                                HStack {
                                                    Image(systemName: "fork.knife")
                                                        .foregroundStyle(Color("AppSecondaryAccent"))
                                                    Text("Meal Reminders")
                                                        .font(.headline)
                                                        .foregroundStyle(primaryTextColor)
                                                }
                                                Text("Receive reminders every 4 hours (7am-9pm) to help you stay on track with logging your meals.")
                                                    .font(.caption)
                                                    .foregroundStyle(secondaryTextColor)
                                            }
                                            Spacer()
                                            Toggle("", isOn: $bindableGoals.mealRemindersEnabled)
                                                .labelsHidden()
                                        }

                                        Divider().background(cardBorderColor)

                                        // Weekly Weight Reminder Toggle
                                        HStack {
                                            VStack(alignment: .leading, spacing: 4) {
                                                HStack {
                                                    Image(systemName: "figure.stand.line.dotted.figure.stand")
                                                        .foregroundStyle(Color("AppSecondaryAccent"))
                                                    Text("Weekly Weight Check-In")
                                                        .font(.headline)
                                                        .foregroundStyle(primaryTextColor)
                                                }
                                                Text("Get reminded every Monday at 9 AM to log your weight for the week.")
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
                        }
                        .padding(.horizontal, 24)

                        } else {
                            // This shows if something went wrong and goals don't exist
                            Text("Loading profile…")
                                .foregroundStyle(secondaryTextColor)
                        }

                        // MARK: - ABOUT SECTION
                        VStack(alignment: .leading, spacing: 16) {
                            Text("About MochiMeter")
                                .font(.title3).bold()
                                .foregroundStyle(primaryTextColor)
                                .padding(.horizontal, 24)

                            FrostedGlassContainer {
                                VStack {
                                    Link(destination: URL(string: "https://mochimeter.com/privacy/")!) {
                                        _buildLinkRow(
                                            title: "Privacy Policy",
                                            icon: "hand.raised.fill"
                                        )
                                    }
                                    Divider().background(cardBorderColor)

                                    Link(destination: URL(string: "https://mochimeter.com/terms/")!) {
                                        _buildLinkRow(
                                            title: "Terms of Service",
                                            icon: "doc.text.fill"
                                        )
                                    }
                                    Divider().background(cardBorderColor)

                                    Link(destination: URL(string: "https://world.openfoodfacts.org/")!) {
                                        _buildLinkRow(
                                            title: "API Usage (OpenFoodFacts)",
                                            icon: "network"
                                        )
                                    }
                                    Divider().background(cardBorderColor)

                                    Link(destination: URL(string: "mailto:support@mochimeter.com")!) {
                                        _buildLinkRow(
                                            title: "Contact Support",
                                            icon: "envelope.fill"
                                        )
                                    }
                                    Divider().background(cardBorderColor)

                                    Link(destination: URL(string: "https://mochimeter.canny.io/feature-requests")!) {
                                        _buildLinkRow(
                                            title: "Feature Requests",
                                            icon: "lightbulb.fill"
                                        )
                                    }
                                    Divider().background(cardBorderColor)

                                    Link(destination: URL(string: "https://mochimeter.canny.io/bug-reports")!) {
                                        _buildLinkRow(
                                            title: "Report a Bug",
                                            icon: "ant.fill"
                                        )
                                    }
                                }
                            }
                            .padding(.horizontal, 24)

                            // App Version
                            HStack {
                                Spacer()
                                Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0") (\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"))")
                                    .font(.caption)
                                    .foregroundStyle(secondaryTextColor)
                                Spacer()
                            }
                            .padding(.top, 8)
                        }

                        // MARK: - DANGER ZONE (RESET)
                        VStack(spacing: 16) {
                            Text("Danger Zone")
                                .font(.title3).bold()
                                .foregroundStyle(.red)
                                .padding(.horizontal, 24)
                            
                            // Delete Account (only for logged-in users)
                            if authManager.currentUser != nil {
                                Button(role: .destructive) {
                                    showDeleteAccountAlert = true
                                } label: {
                                    HStack {
                                        if isDeletingAccount {
                                            ProgressView()
                                                .tint(.red)
                                        } else {
                                            Image(systemName: "person.crop.circle.badge.xmark")
                                        }
                                        Text(isDeletingAccount ? "Deleting Account..." : "Delete Account")
                                            .fontWeight(.semibold)
                                        Spacer()
                                    }
                                    .foregroundColor(.red)
                                    .padding()
                                    .background(.red.opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                                    .padding(.horizontal, 24)
                                }
                                .disabled(isDeletingAccount)
                            }

                            // Reset App (only for guest users)
                            if authManager.currentUser == nil {
                                Button(role: .destructive) {
                                    showFirstResetAlert = true
                                } label: {
                                    HStack {
                                        Image(systemName: "trash.fill")
                                        Text("Reset App")
                                            .fontWeight(.semibold)
                                        Spacer()
                                    }
                                    .foregroundColor(.red)
                                    .padding()
                                    .background(.red.opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                                    .padding(.horizontal, 24)
                                }
                            }
                        }
                        .padding(.bottom, 80)
                    }
                    .containerRelativeFrame(.horizontal)
                }
                .lockVerticalScroll()
                .scrollBounceBehavior(.basedOnSize, axes: .vertical)
                .scrollIndicators(.hidden)
                .scrollContentBackground(.hidden)
                .ignoresSafeArea(edges: .top)
                .dismissKeyboardOnTap()
            }
        }
        .task {
            await refreshData()
            // Apply saved appearance mode on load
            if let goals = goals {
                applyAppearanceMode(goals.appearanceMode)
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task { await refreshData() }
            }
        }
        // First confirmation
        .alert("Reset MochiMeter?", isPresented: $showFirstResetAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Continue", role: .destructive) {
                showFinalResetAlert = true
            }
        } message: {
            Text("This will remove all your data including goals and onboarding progress.")
        }
        // Second confirmation
        .alert("Are you absolutely sure?", isPresented: $showFinalResetAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete Everything", role: .destructive) {
                resetApp()
            }
        } message: {
            Text("This action cannot be undone.")
        }
        // Delete Account - First confirmation
        .alert("Delete Account?", isPresented: $showDeleteAccountAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Continue", role: .destructive) {
                showFinalDeleteAccountAlert = true
            }
        } message: {
            Text("This will permanently delete your account and all associated data from our servers. Your local data will also be cleared.")
        }
        // Delete Account - Second confirmation
        .alert("Are you absolutely sure?", isPresented: $showFinalDeleteAccountAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete My Account", role: .destructive) {
                Task {
                    await deleteAccount()
                }
            }
        } message: {
            Text("This action cannot be undone. Your account and all data will be permanently deleted.")
        }
        // Delete Account - Error alert
        .alert("Deletion Failed", isPresented: $showDeleteAccountError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("We couldn't delete your account. Please try again or contact support. Error: \(deleteAccountErrorMessage)")
        }
        // Sign out confirmation
        .alert("Sign Out?", isPresented: $showSignOutAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Sign Out", role: .destructive) {
                Task {
                    await authManager.signOut()
                    // Reset onboarding to take user back to welcome screen
                    hasCompletedOnboarding = false
                }
            }
        } message: {
            Text("You'll need to sign in again to access your synced data. Any offline data will remain on this device.")
        }
        // Email sign up sheet
        .sheet(isPresented: $showEmailSignUp) {
            EmailAuthView(
                isSignUp: true,
                userName: goals?.name,
                onSuccess: {
                    Task {
                        // Complete sign-in: migrate offline data and set userId
                        if let user = authManager.currentUser {
                            await authManager.completeSignIn(user: user, modelContext: modelContext)

                            // Upload existing goals to cloud
                            if let goals = goals {
                                goals.userId = user.id.uuidString.lowercased()
                                try? modelContext.save()
                                await authManager.uploadOnboardingToCloud(goals: goals)
                            }
                        }

                        // Refresh data to show updated user info
                        await refreshData()
                        print("📧 [SettingsScreen] Email sign-up completed")
                    }
                }
            )
        }
        // Name edit sheet
        .sheet(isPresented: $showNameEditSheet) {
            _buildNameEditSheet()
        }
    }

    // MARK: - Data Refresh

    private func refreshData() async {
        goals = await UserScopedQuery.fetchUserGoals(context: modelContext)
        await checkNotificationStatus()
    }

    private func checkNotificationStatus() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        await MainActor.run {
            notificationStatus = settings.authorizationStatus
        }
    }

    private func applyAppearanceMode(_ mode: AppearanceMode) {
        // Get the first window scene
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }

        let style: UIUserInterfaceStyle
        switch mode {
        case .system:
            style = .unspecified
        case .light:
            style = .light
        case .dark:
            style = .dark
        }
        
        // Notify Superwall Manager
        superwallManager.setAppearance(style)

        // Apply the appearance to all windows in the scene
        for window in windowScene.windows {
            window.overrideUserInterfaceStyle = style
        }
    }

    // MARK: - Reset App

    private func resetApp() {
        // 1. Sign out user
        Task {
            await authManager.signOut()
        }

        // 2. Delete all SwiftData models
        do {
            // Delete all UserGoals
            if let goals = goals {
                modelContext.delete(goals)
            }

            // Delete all LoggedFood
            let foodDescriptor = FetchDescriptor<LoggedFood>()
            if let allFood = try? modelContext.fetch(foodDescriptor) {
                for food in allFood {
                    modelContext.delete(food)
                }
            }

            // Delete all LoggedWater
            let waterDescriptor = FetchDescriptor<LoggedWater>()
            if let allWater = try? modelContext.fetch(waterDescriptor) {
                for water in allWater {
                    modelContext.delete(water)
                }
            }

            // Delete all FastingLog
            let fastingDescriptor = FetchDescriptor<FastingLog>()
            if let allFasting = try? modelContext.fetch(fastingDescriptor) {
                for fasting in allFasting {
                    modelContext.delete(fasting)
                }
            }

            // Delete all Recipes
            let recipeDescriptor = FetchDescriptor<Recipe>()
            if let allRecipes = try? modelContext.fetch(recipeDescriptor) {
                for recipe in allRecipes {
                    modelContext.delete(recipe)
                }
            }

            // Delete all Reminders
            let reminderDescriptor = FetchDescriptor<Reminder>()
            if let allReminders = try? modelContext.fetch(reminderDescriptor) {
                for reminder in allReminders {
                    modelContext.delete(reminder)
                }
            }

            try? modelContext.save()
        }

        // 3. Clear shopping list
        // 3. Clear shopping list
        let shoppingDescriptor = FetchDescriptor<ShoppingItem>()
        if let allShopping = try? modelContext.fetch(shoppingDescriptor) {
            for item in allShopping {
                modelContext.delete(item)
            }
        }

        // 4. Stop any active fasting timer
        if fastingManager.timerRunning {
            fastingManager.endFast()
        }

        // 5. Reset onboarding
        hasCompletedOnboarding = false

        // 6. Clear UserDefaults
        UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")

        print("🧨 App Fully Reset - User signed out, all data cleared")
    }
    
    // MARK: - Delete Account
    
    private func deleteAccount() async {
        guard authManager.currentUser != nil else { return }
        
        isDeletingAccount = true
        
        do {
            // Call the delete-account Edge Function
            try await authManager.deleteAccount()
            
            // Clear local data (similar to reset app but without signing out first)
            await MainActor.run {
                // Delete all SwiftData models
                if let goals = goals {
                    modelContext.delete(goals)
                }
                
                // Delete all LoggedFood
                let foodDescriptor = FetchDescriptor<LoggedFood>()
                if let allFood = try? modelContext.fetch(foodDescriptor) {
                    for food in allFood {
                        modelContext.delete(food)
                    }
                }
                
                // Delete all LoggedWater
                let waterDescriptor = FetchDescriptor<LoggedWater>()
                if let allWater = try? modelContext.fetch(waterDescriptor) {
                    for water in allWater {
                        modelContext.delete(water)
                    }
                }
                
                // Delete all LoggedWeight
                let weightDescriptor = FetchDescriptor<LoggedWeight>()
                if let allWeight = try? modelContext.fetch(weightDescriptor) {
                    for weight in allWeight {
                        modelContext.delete(weight)
                    }
                }
                
                // Delete all FastingLog
                let fastingDescriptor = FetchDescriptor<FastingLog>()
                if let allFasting = try? modelContext.fetch(fastingDescriptor) {
                    for fasting in allFasting {
                        modelContext.delete(fasting)
                    }
                }
                
                // Delete all Recipes
                let recipeDescriptor = FetchDescriptor<Recipe>()
                if let allRecipes = try? modelContext.fetch(recipeDescriptor) {
                    for recipe in allRecipes {
                        modelContext.delete(recipe)
                    }
                }
                
                // Delete all SavedFood
                let savedFoodDescriptor = FetchDescriptor<SavedFood>()
                if let allSavedFood = try? modelContext.fetch(savedFoodDescriptor) {
                    for saved in allSavedFood {
                        modelContext.delete(saved)
                    }
                }
                
                // Delete all ShoppingItems
                let shoppingDescriptor = FetchDescriptor<ShoppingItem>()
                if let allShopping = try? modelContext.fetch(shoppingDescriptor) {
                    for item in allShopping {
                        modelContext.delete(item)
                    }
                }
                
                try? modelContext.save()
                
                // Stop any active fasting timer
                if fastingManager.timerRunning {
                    fastingManager.endFast()
                }
                
                // Reset onboarding
                hasCompletedOnboarding = false
                UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")
                
                isDeletingAccount = false
                
                print("✅ Account deleted successfully")
            }
            
        } catch {
            await MainActor.run {
                isDeletingAccount = false
                deleteAccountErrorMessage = error.localizedDescription
                showDeleteAccountError = true
                print("❌ Error deleting account: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Notification Helpers

    private var notificationStatusText: String {
        switch notificationStatus {
        case .authorized:
            return "Notifications Enabled"
        case .denied:
            return "Notifications Disabled"
        case .notDetermined:
            return "Not Yet Configured"
        case .provisional:
            return "Quietly Enabled"
        case .ephemeral:
            return "Temporarily Enabled"
        @unknown default:
            return "Unknown Status"
        }
    }

    private func handleNotificationPermission() async {
        let center = UNUserNotificationCenter.current()

        if notificationStatus == .notDetermined {
            // Request permission
            do {
                let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
                await checkNotificationStatus()

                if granted {
                    print("✅ Notification permission granted")
                } else {
                    print("❌ Notification permission denied")
                }
            } catch {
                print("❌ Notification auth failed: \(error)")
            }
        } else {
            // Open iOS Settings
            if let url = URL(string: UIApplication.openSettingsURLString) {
                await UIApplication.shared.open(url)
            }
        }
    }

    // MARK: - Helper View Builders

    @ViewBuilder
    private func _buildNameEditSheet() -> some View {
        NavigationStack {
            ZStack {
                (colorScheme == .dark ? Color("AppPrimaryDark") : Color(red: 245/255, green: 245/255, blue: 247/255))
                    .ignoresSafeArea()

                VStack(spacing: 24) {
                    Image(systemName: "person.text.rectangle")
                        .font(.system(size: 60))
                        .foregroundStyle(Color("AppSecondaryAccent"))
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
                                    .fill(primaryTextColor.opacity(0.1))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(primaryTextColor.opacity(0.2), lineWidth: 1)
                            )
                            .textContentType(.oneTimeCode)
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
                            .background(!editingName.isEmpty ? Color("AppSecondaryAccent") : Color.gray.opacity(0.3))
                            .foregroundStyle(!editingName.isEmpty ? .black : primaryTextColor.opacity(0.5))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(editingName.isEmpty)
                    .padding(.horizontal, 24)

                    Spacer()
                }
            }
            .dismissKeyboardOnTap()
            .navigationBarTitleDisplayMode(.inline)
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
        .presentationDetents([.medium])
    }

    private func saveNameChange() {
        guard let goals = goals else { return }

        // Save name locally
        goals.name = editingName
        try? modelContext.save()

        // Sync to cloud
        if let userId = goals.userId {
            Task {
                await CloudSyncManager.shared.uploadUserGoalsImmediately(goals, userId: userId)
            }
        }

        showNameEditSheet = false
    }

    @ViewBuilder
    private func _buildAccountSection() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Account")
                .font(.title3).bold()
                .foregroundStyle(primaryTextColor)
                .padding(.horizontal, 24)

            FrostedGlassContainer {
                VStack(alignment: .leading, spacing: 12) {

                    if let user = authManager.currentUser {
                        HStack(spacing: 8) {
                            Image(systemName: signInProvider.icon)
                                .font(.headline)
                                .foregroundStyle(primaryTextColor)
                            Text("Signed in with \(signInProvider.name)")
                                .font(.headline)
                                .foregroundStyle(primaryTextColor)
                        }

                        Text(user.email ?? "Private Relay Email")
                            .font(.subheadline)
                            .foregroundStyle(secondaryTextColor)

                        Button {
                            showSignOutAlert = true
                        } label: {
                            HStack {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                Text("Sign Out")
                                Spacer()
                            }
                            .foregroundColor(.red)
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)

                    } else {
                        Text("Not signed in")
                            .font(.headline)
                            .foregroundStyle(primaryTextColor)

                        Text("Sign in to sync your data across devices.")
                            .font(.footnote)
                            .foregroundStyle(secondaryTextColor)
                            .padding(.bottom, 8)

                        SignInWithAppleButtonView(
                            onRequest: { request in
                                print("🍎 [SettingsScreen] Sign in button tapped - onRequest called")
                                authManager.appleSignInNonce = randomNonceString()
                                request.nonce = sha256(authManager.appleSignInNonce)
                                request.requestedScopes = [.fullName, .email]
                                print("🍎 [SettingsScreen] Request configured with nonce and scopes")
                            },
                            onCompletion: { authorization in
                                print("🍎 [SettingsScreen] onCompletion called - authorization received")
                                Task {
                                    await authManager.handleAppleAuthorization(authorization)

                                    if let user = authManager.currentUser {
                                        await authManager.completeSignIn(user: user, modelContext: modelContext)
                                    }

                                    await refreshData()
                                    print("🍎 [SettingsScreen] Sign-in flow completed")
                                }
                            }
                        )

                        GoogleSignInButtonView(
                            onSuccess: { idToken, accessToken, fullName in
                                Task {
                                    do {
                                        try await authManager.signInWithGoogle(
                                            idToken: idToken,
                                            accessToken: accessToken,
                                            fullName: fullName
                                        )

                                        if let user = authManager.currentUser {
                                            await authManager.completeSignIn(user: user, modelContext: modelContext)

                                            if let goals = goals {
                                                goals.userId = user.id.uuidString.lowercased()
                                                try? modelContext.save()
                                                await authManager.uploadOnboardingToCloud(goals: goals)
                                            }
                                        }

                                        await refreshData()
                                        print("🔵 [SettingsScreen] Google sign-in completed")
                                    } catch {
                                        print("🔵 [SettingsScreen] Google sign-in failed: \(error.localizedDescription)")
                                    }
                                }
                            },
                            onError: { error in
                                print("🔵 [SettingsScreen] Google sign-in error: \(error.localizedDescription)")
                            }
                        )

                        Button {
                            showEmailSignUp = true
                        } label: {
                            HStack {
                                Image(systemName: "envelope.fill")
                                Text("Sign up with Email")
                            }
                            .font(.subheadline.weight(.semibold))
                            .padding(.vertical, 14)
                            .frame(maxWidth: .infinity)
                            .background(primaryTextColor.opacity(0.1))
                            .foregroundStyle(primaryTextColor)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(primaryTextColor.opacity(0.2), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 8)
            }
            .padding(.horizontal, 24)
        }
    }

    @ViewBuilder
    private func _buildGoalTextField(
        title: String,
        binding: Binding<Double>,
        unit: String
    ) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(primaryTextColor)

            Spacer()

            TextField("", value: binding, format: .number.precision(.fractionLength(0)))
                .font(.body.bold())
                .foregroundStyle(Color("AppSecondaryAccent"))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 80)
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(inputBackgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(inputBorderColor, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .onChange(of: binding.wrappedValue) { _, newValue in
                    // Apply appropriate validation based on the field
                    if title == "Calories" {
                        binding.wrappedValue = InputValidation.capDailyCalories(newValue)
                    } else if unit == "g" {
                        binding.wrappedValue = InputValidation.capDailyMacro(newValue)
                    } else if title == "Daily Goal" && unit == "mL" {
                        binding.wrappedValue = InputValidation.capWater(newValue)
                    } else if title == "Cup Size" && unit == "mL" {
                        binding.wrappedValue = InputValidation.capCupSize(newValue)
                    }
                }

            Text(unit)
                .foregroundStyle(secondaryTextColor)
                .frame(width: 40, alignment: .leading)
        }
    }

    @ViewBuilder
    private func _buildLinkRow(title: String, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(Color("AppSecondaryAccent"))
            Text(title)
                .foregroundStyle(primaryTextColor)
            Spacer()
            Image(systemName: "arrow.up.right")
                .foregroundStyle(secondaryTextColor)
        }
        .padding(.vertical, 8)
    }

    // MARK: - Background

    @ViewBuilder
    private func _buildDynamicBackground() -> some View {
        ZStack {
            Color("AppPrimaryDark", bundle: nil).ignoresSafeArea()
            if colorScheme == .light {
                RadialGradient(
                    gradient: Gradient(colors: [Color("AppSecondaryAccent").opacity(0.3), .clear]),
                    center: .topLeading,
                    startRadius: 50,
                    endRadius: 450
                )
                .offset(offset1)
                .offset(x: -150, y: -150)
                .ignoresSafeArea()

                RadialGradient(
                    gradient: Gradient(colors: [Color("AppPrimaryAccent").opacity(0.4), .clear]),
                    center: .bottomTrailing,
                    startRadius: 100,
                    endRadius: 500
                )
                .offset(offset2)
                .offset(x: 100, y: 150)
                .ignoresSafeArea()
            } else {
                // Subtle Dark Mode Lighting - Matched to Home Screen
                RadialGradient(gradient: Gradient(colors: [Color.white.opacity(0.15), .clear]), center: .topLeading, startRadius: 50, endRadius: 500)
                    .offset(offset1).offset(x: -100, y: -100).ignoresSafeArea()
                
                RadialGradient(gradient: Gradient(colors: [Color.white.opacity(0.08), .clear]), center: .bottomTrailing, startRadius: 50, endRadius: 450)
                    .offset(offset2).offset(x: 100, y: 100).ignoresSafeArea()
                
                RadialGradient(gradient: Gradient(colors: [Color.white.opacity(0.06), .clear]), center: .bottomLeading, startRadius: 60, endRadius: 350)
                    .offset(offset1).offset(x: -50, y: 120).ignoresSafeArea()
            }
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
}

// MARK: - Widget Preview Cards (Realistic Widget Previews)

struct CalorieWidgetPreview: View {
    let colorScheme: ColorScheme

    private var primaryTextColor: Color {
        colorScheme == .dark ? .white : .black
    }

    private var secondaryTextColor: Color {
        colorScheme == .dark ? .white.opacity(0.7) : Color(red: 60/255, green: 60/255, blue: 67/255)
    }

    private var backgroundColor: Color {
        colorScheme == .dark ? Color("AppPrimaryDark") : .white
    }

    private var ringTrackColor: Color {
        colorScheme == .dark ? Color.black.opacity(0.3) : Color.black.opacity(0.15)
    }

    private var macroBackgroundColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.10) : Color.black.opacity(0.08)
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Ring
            ZStack {
                Circle()
                    .stroke(ringTrackColor, lineWidth: 6)

                Circle()
                    .trim(from: 0, to: 0.6)
                    .stroke(
                        Color("AppSecondaryAccent"),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 0) {
                    Text("850")
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundColor(primaryTextColor)

                    Text("left")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(secondaryTextColor)
                }
            }
            .frame(width: 50, height: 50)

            Spacer()

            // Macros
            HStack(spacing: 8) {
                macroLabel("C", 45, .red)
                macroLabel("P", 32, .yellow)
                macroLabel("F", 18, .blue)
            }
            .frame(maxWidth: .infinity)
            .padding(6)
            .background(macroBackgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            Spacer()
        }
        .padding(10)
        .frame(width: 130, height: 130)
        .background(
            Group {
                if colorScheme == .dark {
                    backgroundColor
                } else {
                    ZStack {
                        backgroundColor
                        LinearGradient(
                            colors: [Color("AppSecondaryAccent").opacity(0.25), .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    }
                }
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
    }

    private func macroLabel(_ label: String, _ value: Int, _ color: Color) -> some View {
        VStack(spacing: 1) {
            Text(label)
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(color)
            Text("\(value)")
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(primaryTextColor)
        }
    }
}

struct WaterWidgetPreview: View {
    let colorScheme: ColorScheme

    private var primaryTextColor: Color {
        colorScheme == .dark ? .white : .black
    }

    private var secondaryTextColor: Color {
        colorScheme == .dark ? .white.opacity(0.8) : Color(red: 60/255, green: 60/255, blue: 67/255)
    }

    private var backgroundColor: Color {
        colorScheme == .dark ? Color("AppPrimaryDark") : .white
    }

    private var cupOutlineColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.3) : Color.black.opacity(0.2)
    }

    var body: some View {
        ZStack {
            // Cup
            GeometryReader { geo in
                ZStack(alignment: .bottom) {
                    // Water Level (60% filled)
                    Rectangle()
                        .fill(Color("AppSecondaryAccent"))
                        .frame(height: geo.size.height * 0.6)

                    // Cup Outline
                    WaterCupShape()
                        .stroke(cupOutlineColor, lineWidth: 2)
                }
                .mask(WaterCupShape())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            // Text
            VStack {
                Text("1800")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(primaryTextColor)
                    .shadow(color: colorScheme == .dark ? .black.opacity(0.3) : .clear, radius: 2, x: 0, y: 1)

                Text("of 3000")
                    .font(.system(size: 9))
                    .foregroundStyle(secondaryTextColor)
                    .shadow(color: colorScheme == .dark ? .black.opacity(0.3) : .clear, radius: 2, x: 0, y: 1)

                Spacer()

                // Plus button
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(width: 22, height: 22)
                    .background(Color.white)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                    .padding(.bottom, 4)
            }
            .padding(10)
        }
        .frame(width: 130, height: 130)
        .background(
            Group {
                if colorScheme == .dark {
                    backgroundColor
                } else {
                    ZStack {
                        backgroundColor
                        LinearGradient(
                            colors: [Color("AppSecondaryAccent").opacity(0.25), .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    }
                }
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
    }
}

struct ScanWidgetPreview: View {
    let colorScheme: ColorScheme

    private var primaryTextColor: Color {
        colorScheme == .dark ? .white : .black
    }

    private var backgroundColor: Color {
        colorScheme == .dark ? Color("AppPrimaryDark") : .white
    }

    var body: some View {
        VStack(spacing: 8) {
            Spacer()

            Image(systemName: "barcode.viewfinder")
                .font(.system(size: 36))
                .foregroundStyle(Color("AppSecondaryAccent"))

            Text("Scan")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(primaryTextColor)

            Spacer()
        }
        .frame(width: 130, height: 130)
        .background(
            Group {
                if colorScheme == .dark {
                    backgroundColor
                } else {
                    ZStack {
                        backgroundColor
                        LinearGradient(
                            colors: [Color("AppSecondaryAccent").opacity(0.25), .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    }
                }
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
    }
}

// MARK: - Lock Screen Widget Previews

/// Circular calorie gauge widget preview (mimics iOS lock screen monochrome style)
struct LockScreenCircularWidgetPreview: View {
    @Environment(\.colorScheme) var colorScheme
    
    private var widgetColor: Color {
        colorScheme == .dark ? .white : .black
    }
    
    var body: some View {
        ZStack {
            // Background circle (iOS tinted glass effect)
            Circle()
                .fill(widgetColor.opacity(0.15))
            
            // Track ring
            Circle()
                .stroke(widgetColor.opacity(0.3), lineWidth: 5)
                .padding(6)
            
            // Progress arc
            Circle()
                .trim(from: 0, to: 0.65)
                .stroke(
                    widgetColor,
                    style: StrokeStyle(lineWidth: 5, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .padding(6)
            
            // Center text
            VStack(spacing: 0) {
                Text("735")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(widgetColor)
                Text("left")
                    .font(.system(size: 7, weight: .medium))
                    .foregroundColor(widgetColor.opacity(0.7))
            }
        }
        .frame(width: 56, height: 56)
        .background(
            Circle()
                .fill(colorScheme == .dark ? Color.clear : Color.black.opacity(0.05))
        )
        .overlay(
            Circle()
                .stroke(colorScheme == .dark ? Color.clear : Color.black.opacity(0.1), lineWidth: 1)
        )
    }
}

/// Rectangular calorie widget preview (mimics iOS lock screen monochrome style)
struct LockScreenRectangularWidgetPreview: View {
    @Environment(\.colorScheme) var colorScheme
    
    private var widgetColor: Color {
        colorScheme == .dark ? .white : .black
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Calories row
            HStack {
                Text("Calories:")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(widgetColor)
                Spacer()
                Text("1,365 / 2,100")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(widgetColor)
            }
            
            // Progress bar (monochrome)
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(widgetColor.opacity(0.3))
                        .frame(height: 3)
                    
                    Rectangle()
                        .fill(widgetColor)
                        .frame(width: geometry.size.width * 0.65, height: 3)
                }
            }
            .frame(height: 3)
            
            // Macros row
            HStack(spacing: 10) {
                lockMacro("C", 45)
                lockMacro("P", 32)
                lockMacro("F", 18)
            }
        }
        .padding(10)
        .frame(width: 160, height: 56)
        .background(widgetColor.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(colorScheme == .dark ? Color.clear : Color.black.opacity(0.1), lineWidth: 1)
        )
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(colorScheme == .dark ? Color.clear : Color.black.opacity(0.05))
        )
    }
    
    private func lockMacro(_ label: String, _ value: Int) -> some View {
        HStack(spacing: 2) {
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(widgetColor.opacity(0.7))
            Text("\(value)g")
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(widgetColor)
        }
    }
}

/// Circular scan widget preview (mimics iOS lock screen monochrome style)
struct LockScreenScanWidgetPreview: View {
    @Environment(\.colorScheme) var colorScheme
    
    private var widgetColor: Color {
        colorScheme == .dark ? .white : .black
    }
    
    var body: some View {
        ZStack {
            Circle()
                .fill(widgetColor.opacity(0.15))
            
            Image(systemName: "barcode.viewfinder")
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(widgetColor)
        }
        .frame(width: 56, height: 56)
        .background(
            Circle()
                .fill(colorScheme == .dark ? Color.clear : Color.black.opacity(0.05))
        )
        .overlay(
            Circle()
                .stroke(colorScheme == .dark ? Color.clear : Color.black.opacity(0.1), lineWidth: 1)
        )
    }
}

// MARK: - Vertical Scroll Lock Helper

private struct VerticalScrollLockModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.background(VerticalScrollLockView())
    }
}

private struct VerticalScrollLockView: UIViewRepresentable {
    final class Coordinator {
        weak var scrollView: UIScrollView?
        var widthConstraint: NSLayoutConstraint?
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.isUserInteractionEnabled = false
        DispatchQueue.main.async {
            updateParentScrollView(from: view, coordinator: context.coordinator)
        }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            updateParentScrollView(from: uiView, coordinator: context.coordinator)
        }
    }

    private func updateParentScrollView(from view: UIView, coordinator: Coordinator) {
        guard let scrollView = findParentScrollView(from: view) else { return }

        // Disable all horizontal scrolling behaviors
        scrollView.alwaysBounceHorizontal = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.isDirectionalLockEnabled = true
        scrollView.contentInsetAdjustmentBehavior = .never

        // Reset any horizontal offset
        if scrollView.contentOffset.x != 0 {
            scrollView.contentOffset.x = 0
        }

        if coordinator.scrollView !== scrollView {
            coordinator.widthConstraint?.isActive = false
            coordinator.scrollView = scrollView
            let constraint = scrollView.contentLayoutGuide.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
            constraint.priority = .required
            constraint.isActive = true
            coordinator.widthConstraint = constraint
        }
    }

    private func findParentScrollView(from view: UIView) -> UIScrollView? {
        var current: UIView? = view
        while let superview = current?.superview {
            if let scrollView = superview as? UIScrollView {
                return scrollView
            }
            current = superview
        }
        return nil
    }
}

private extension View {
    func lockVerticalScroll() -> some View {
        modifier(VerticalScrollLockModifier())
    }
}

// MARK: - Mochi Theme Button Component
struct MochiThemeButton: View {
    let theme: MochiTheme
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    // Gradient preview circle
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: theme.buttonGradient,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)
                        .overlay(
                            Circle()
                                .stroke(isSelected ? Color.white : Color.clear, lineWidth: 3)
                        )
                        .shadow(color: theme.primaryColor.opacity(0.3), radius: 8, y: 4)
                    
                    // Emoji
                    Text(theme.icon)
                        .font(.title)
                    
                    // Checkmark for selected state
                    if isSelected {
                        VStack {
                            HStack {
                                Spacer()
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(.white)
                                    .background(
                                        Circle()
                                            .fill(theme.primaryColor)
                                            .frame(width: 24, height: 24)
                                    )
                                    .offset(x: 8, y: -8)
                            }
                            Spacer()
                        }
                    }
                }
                
                Text(theme.displayName)
                    .font(.caption.weight(isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? theme.primaryColor : (colorScheme == .dark ? .white.opacity(0.7) : .black.opacity(0.6)))
            }
            .scaleEffect(isSelected ? 1.05 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        }
        .buttonStyle(.plain)
    }
}

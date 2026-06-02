//
//  NewOnboardingScreen.swift
//  Yumo
//

import SwiftUI
import SwiftData
import AuthenticationServices
import Auth
import GoogleSignIn

struct NewOnboardingScreen: View {
    @State private var flowManager = OnboardingFlowManager()
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var authManager: AuthManager
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme
    @State private var offset1: CGSize = .zero
    @State private var offset2: CGSize = .zero
    
    // Use @AppStorage to persist completion state across view recreations
    // This is the key fix for the "flash to welcome screen" issue
    @AppStorage("onboarding_isCompleting") private var isCompletingOnboarding = false
    @AppStorage("onboarding_lockedPage") private var lockedPage: Int = -1  // -1 means not locked
    @State private var completionMessage = "Finishing setup..."

    var onFinish: () -> Void

    var body: some View {
        ZStack {
            OnboardingTheme.baseBackground(colorScheme).ignoresSafeArea()
            _buildDynamicBackground()

            // Page content based on currentPage
            // NOTE: NamePage moved to AFTER SignInPage to comply with Apple's
            // Sign in with Apple guidelines - we don't ask for name if SIWA provides it
            // 
            // When isCompletingOnboarding is true, we lock the page to prevent
            // any visual glitches from view hierarchy updates
            Group {
                // Use locked page if set, otherwise use current page
                let displayPage = lockedPage >= 0 ? lockedPage : flowManager.currentPage
                switch displayPage {
                case 0: WelcomePage(flowManager: flowManager, onFinish: onFinish)
                case 1: FeatureScreenPage(flowManager: flowManager)
                case 2: EarlyHealthKitPage(flowManager: flowManager)
                case 3: GenderPage(flowManager: flowManager)           // Was 4
                case 4: ActivityLevelPage(flowManager: flowManager)    // Was 5
                case 5: HeightWeightPage(flowManager: flowManager)     // Was 6
                case 6: DateOfBirthPage(flowManager: flowManager)      // Was 7
                case 7: WeightGoalPage(flowManager: flowManager)       // Was 8
                case 8: TargetWeightPage(flowManager: flowManager)     // Was 9
                case 9: WeightLossIntensityPage(flowManager: flowManager)  // Was 10
                case 10: BlockersPage(flowManager: flowManager)        // Was 11
                case 11: DietTypePage(flowManager: flowManager)        // Was 12
                case 12: GoalsToAccomplishPage(flowManager: flowManager)   // Was 13
                case 13:                                                // Was 14
                    ThankYouAnimationView {
                        flowManager.goNext()
                    }
                case 14: DoneScreenPage(flowManager: flowManager)      // Was 15
                case 15:                                                // Was 16
                    LoadingScreenView {
                        flowManager.goNext()
                    }
                case 16: GoalsSummaryPage(flowManager: flowManager)    // Was 17
                case 17: ThemeSelectionPage(flowManager: flowManager)  // Was 18
                case 18: NotificationPermissionPage(flowManager: flowManager)  // Was 19
                case 19: SignInPage(
                    flowManager: flowManager,
                    authManager: authManager,
                    modelContext: modelContext,
                    onFinish: onFinish,
                    onStartCompletion: { message in
                        // Lock the page and show global loading overlay
                        // Using @AppStorage ensures this persists across view recreations
                        lockedPage = 19
                        completionMessage = message
                        isCompletingOnboarding = true
                    },
                    onUpdateMessage: { message in
                        completionMessage = message
                    }
                )
                case 20: FinalNamePage(flowManager: flowManager, authManager: authManager, modelContext: modelContext, onFinish: onFinish)  // MOVED: Was 3, now after sign-in
                default: EmptyView()
                }
            }
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            ))
            .id(lockedPage >= 0 ? lockedPage : flowManager.currentPage)
            
            // Global loading overlay - blocks all interaction and prevents visual glitches
            if isCompletingOnboarding {
                SyncProgressOverlay(message: completionMessage)
            }
        }
        .onAppear {
            animateOrbs()
            
            // CRITICAL: If we reappear while completion was in progress,
            // the sign-in already happened - we need to finish immediately
            if isCompletingOnboarding && authManager.currentUser != nil {
                print("🔄 [NewOnboardingScreen] Detected completion in progress, finishing...")
                // Reset the persisted state
                isCompletingOnboarding = false
                lockedPage = -1
                // Finish immediately
                onFinish()
            } else if isCompletingOnboarding {
                // Completion started but no user yet - reset and try again
                print("⚠️ [NewOnboardingScreen] Completion was in progress but no user, resetting...")
                isCompletingOnboarding = false
                lockedPage = -1
            }
        }
    }

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

// MARK: - Placeholder Pages (to be implemented)

struct FeatureScreenPage: View {
    @Bindable var flowManager: OnboardingFlowManager
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let primaryText = OnboardingTheme.primaryText(colorScheme)
        let secondaryText = OnboardingTheme.secondaryText(colorScheme)

        ZStack(alignment: .topLeading) {
            VStack(spacing: 30) {
                Spacer()

                Image(systemName: "heart.text.square.fill")
                    .font(.system(size: 120))
                    .foregroundStyle(Color("AppSecondaryAccent"))

                Text("We help you maintain healthy long-term results")
                    .font(.title).bold()
                    .foregroundStyle(primaryText)
                    .multilineTextAlignment(.center)

                Text("With personalized nutrition plans and tracking")
                    .font(.headline)
                    .foregroundStyle(secondaryText)
                    .multilineTextAlignment(.center)

                Spacer()

                ContinueButton(title: "Next", isEnabled: !flowManager.isNavigating) {
                    flowManager.goNext()
                }
            }
            .padding(30)
            
            // Back button to return to Welcome screen
            Button {
                flowManager.goBack()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(primaryText)
                    .padding(16)
            }
            .padding(.leading, 8)
            .padding(.top, 8)
        }
    }
}

struct DateOfBirthPage: View {
    @Bindable var flowManager: OnboardingFlowManager
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        OnboardingQuestionView(
            question: "What's your date of birth?",
            subtitle: nil,
            progress: flowManager.progress,
            canGoBack: true,
            onBack: { flowManager.goBack() }
        ) {
            DatePicker("Birthday", selection: $flowManager.birthDate, displayedComponents: .date)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .padding()
                .foregroundStyle(OnboardingTheme.primaryText(colorScheme))

            Spacer().frame(height: 20)

            ContinueButton(title: "Continue", isEnabled: !flowManager.isNavigating) {
                flowManager.goNext()
            }
        }
    }
}

struct TargetWeightPage: View {
    @Bindable var flowManager: OnboardingFlowManager
    @Environment(\.colorScheme) private var colorScheme
    
    // Conversion factor
    private let kgToLbs: Double = 2.20462
    
    private var isImperial: Bool {
        flowManager.unitSystem == .imperial
    }
    
    // For imperial: display in lbs
    private var targetWeightLbs: Int {
        Int(round(flowManager.targetWeight * kgToLbs))
    }
    
    // Picker range in kg
    private let minWeightKg = 30
    private let maxWeightKg = 180
    
    // Picker range in lbs
    private var minWeightLbs: Int { Int(round(Double(minWeightKg) * kgToLbs)) }
    private var maxWeightLbs: Int { Int(round(Double(maxWeightKg) * kgToLbs)) }

    var body: some View {
        OnboardingQuestionView(
            question: "What's your target weight?",
            subtitle: nil,
            progress: flowManager.progress,
            canGoBack: true,
            onBack: { flowManager.goBack() }
        ) {
            if isImperial {
                // Imperial picker (lbs)
                Picker("Target Weight", selection: Binding(
                    get: { targetWeightLbs },
                    set: { newLbs in
                        flowManager.targetWeight = Double(newLbs) / kgToLbs
                    }
                )) {
                    ForEach(minWeightLbs...maxWeightLbs, id: \.self) { lbs in
                        Text("\(lbs) lbs").tag(lbs)
                    }
                }
                .pickerStyle(.wheel)
                .frame(height: 200)
                .foregroundStyle(OnboardingTheme.primaryText(colorScheme))
            } else {
                // Metric picker (kg)
                Picker("Target Weight", selection: $flowManager.targetWeight) {
                    ForEach(minWeightKg...maxWeightKg, id: \.self) { kg in
                        Text("\(kg) kg").tag(Double(kg))
                    }
                }
                .pickerStyle(.wheel)
                .frame(height: 200)
                .foregroundStyle(OnboardingTheme.primaryText(colorScheme))
            }
        } footer: {
            ContinueButton(title: "Continue", isEnabled: flowManager.canProceed() && !flowManager.isNavigating) {
                flowManager.goNext()
            }
        }
    }
}

struct HealthKitPermissionPage: View {
    @Bindable var flowManager: OnboardingFlowManager
    @StateObject private var healthKitManager = HealthKitManager.shared
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        OnboardingQuestionView(
            question: "Connect to HealthKit?",
            subtitle: "We use HealthKit to track your steps for more accurate activity calculations",
            progress: flowManager.progress,
            canGoBack: true,
            onBack: { flowManager.goBack() }
        ) {
            VStack(spacing: 20) {
                Image(systemName: "heart.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(Color("AppSecondaryAccent"))

                Button {
                    guard !flowManager.isNavigating else { return }
                    Task {
                        do {
                            try await healthKitManager.requestAuthorization()
                            await MainActor.run {
                                flowManager.healthKitEnabled = true
                            }
                        } catch {
                            print("HealthKit authorization failed: \(error)")
                            await MainActor.run {
                                flowManager.healthKitEnabled = false
                            }
                        }
                        await MainActor.run {
                            guard !flowManager.isNavigating else { return }
                            flowManager.goNext()
                        }
                    }
                } label: {
                    Text("Allow Access")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color("AppSecondaryAccent"))
                        .cornerRadius(16)
                }
                .disabled(flowManager.isNavigating)

                Button {
                    guard !flowManager.isNavigating else { return }
                    flowManager.healthKitEnabled = false
                    flowManager.goNext()
                } label: {
                    Text("Not Now")
                        .font(.headline)
                        .foregroundColor(OnboardingTheme.secondaryText(colorScheme))
                }
                .disabled(flowManager.isNavigating)
            }
            .padding(.horizontal)
        }
    }
}

struct ReferralCodePage: View {
    @Bindable var flowManager: OnboardingFlowManager
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        OnboardingQuestionView(
            question: "Have a referral code?",
            subtitle: "Optional - you can skip this",
            progress: flowManager.progress,
            canGoBack: true,
            onBack: { flowManager.goBack() }
        ) {
            TextField("Enter code", text: $flowManager.referralCode)
                .textFieldStyle(.plain)
                .font(.title2)
                .foregroundStyle(OnboardingTheme.primaryText(colorScheme))
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(OnboardingTheme.cardBackground(colorScheme))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(OnboardingTheme.cardStroke(colorScheme), lineWidth: 1)
                )
                .autocorrectionDisabled()
                .textInputAutocapitalization(.characters)

            Spacer().frame(height: 20)

            ContinueButton(title: "Continue", isEnabled: !flowManager.isNavigating) {
                flowManager.goNext()
            }

            Button("Skip") {
                guard !flowManager.isNavigating else { return }
                flowManager.referralCode = ""
                flowManager.goNext()
            }
            .disabled(flowManager.isNavigating)
            .foregroundColor(OnboardingTheme.secondaryText(colorScheme))
            .padding()
        }
    }
}

struct DoneScreenPage: View {
    @Bindable var flowManager: OnboardingFlowManager
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let primaryText = OnboardingTheme.primaryText(colorScheme)
        let secondaryText = OnboardingTheme.secondaryText(colorScheme)

        VStack(spacing: 30) {
            Spacer()

            Text("✨")
                .font(.system(size: 80))

            Text("Time to generate your plan")
                .font(.largeTitle).bold()
                .foregroundStyle(primaryText)
                .multilineTextAlignment(.center)

            Text("We're analyzing your profile...")
                .font(.headline)
                .foregroundStyle(secondaryText)
                .multilineTextAlignment(.center)

            Spacer()

            ContinueButton(title: "Let's Go!", isEnabled: !flowManager.isNavigating) {
                flowManager.goNext()
            }
        }
        .padding(30)
    }
}

struct GoalsSummaryPage: View {
    @Bindable var flowManager: OnboardingFlowManager

    var body: some View {
        let goals = flowManager.buildUserGoals()

        VStack(spacing: 0) {
            // Progress bar at top
            OnboardingProgressBar(progress: flowManager.progress)
                .padding(.horizontal, 24)
                .padding(.top, 8)

            ScrollView {
                GoalsSummaryView(
                    dailyCalories: goals.dailyCalories,
                    dailyProtein: goals.dailyProtein,
                    dailyCarbs: goals.dailyCarbs,
                    dailyFat: goals.dailyFat,
                    weightGoal: goals.weightGoal
                )
                .padding()

                ContinueButton(title: "Continue", isEnabled: !flowManager.isNavigating) {
                    flowManager.goNext()
                }
            }
        }
    }
}

struct SignInPage: View {
    @Bindable var flowManager: OnboardingFlowManager
    var authManager: AuthManager
    var modelContext: ModelContext
    var onFinish: () -> Void
    
    // Callbacks to parent for global loading overlay
    var onStartCompletion: ((String) -> Void)?
    var onUpdateMessage: ((String) -> Void)?
    
    @Environment(\.colorScheme) private var colorScheme
    @State private var showEmailSignUp = false
    @State private var isFinishing = false
    
    /// Returns true if we have a valid name (from SIWA, Google, or user input)
    private var hasValidName: Bool {
        let trimmed = flowManager.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed != "User"
    }
    
    /// Notify parent to show global loading overlay
    private func startCompletion(message: String) {
        isFinishing = true
        onStartCompletion?(message)
    }
    
    /// Update the loading message
    private func updateMessage(_ message: String) {
        onUpdateMessage?(message)
    }

    var body: some View {
        let primaryText = OnboardingTheme.primaryText(colorScheme)
        let secondaryText = OnboardingTheme.secondaryText(colorScheme)

        // Always show sign-in options view
        // The parent NewOnboardingScreen handles the global loading overlay
        signInOptionsView(primaryText: primaryText, secondaryText: secondaryText)
            .disabled(isFinishing)
    }

    // MARK: - Sign In Options View
    @ViewBuilder
    private func signInOptionsView(primaryText: Color, secondaryText: Color) -> some View {
        VStack(spacing: 30) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 120))
                .foregroundStyle(.green)

            Text("All Set!")
                .font(.largeTitle).bold()
                .foregroundStyle(primaryText)

            Text("Sign in to sync your data across devices")
                .font(.headline)
                .foregroundStyle(secondaryText)
                .multilineTextAlignment(.center)

            Spacer()

            VStack(spacing: 12) {
                Text("Sign in to save your progress")
                    .foregroundColor(secondaryText)
                    .font(.subheadline)

                SignInWithAppleButtonView(
                    onRequest: { request in
                        let nonce = randomNonceString()
                        authManager.appleSignInNonce = nonce
                        request.requestedScopes = [.fullName, .email]
                        request.nonce = sha256(nonce)
                    },
                    onCompletion: { authorization in
                        Task {
                            // Show global loading overlay immediately
                            await MainActor.run {
                                startCompletion(message: "Signing you in...")
                            }
                            
                            // Extract full name from Apple credential (only provided on first sign-in)
                            // IMPORTANT: Apple only provides name on FIRST EVER sign-in with this app
                            if let credential = authorization.credential as? ASAuthorizationAppleIDCredential {
                                print("🍎 [SignInPage] Got Apple credential")
                                if let fullName = credential.fullName {
                                    let formatter = PersonNameComponentsFormatter()
                                    let name = formatter.string(from: fullName)
                                    print("🍎 [SignInPage] Apple provided name: '\(name)'")
                                    if !name.isEmpty {
                                        await MainActor.run {
                                            flowManager.name = name
                                        }
                                    }
                                } else {
                                    print("⚠️ [SignInPage] Apple did not provide name (subsequent sign-in)")
                                }
                            }
                            
                            await authManager.handleAppleAuthorization(authorization)
                            if let user = authManager.currentUser {
                                await MainActor.run {
                                    updateMessage("Setting up your profile...")
                                }
                                await authManager.completeSignIn(user: user, modelContext: modelContext)
                            }
                            
                            await MainActor.run {
                                updateMessage("Almost done...")
                            }
                            
                            // With SIWA, name is usually provided, so finish directly
                            await finishOnboarding()
                            await MainActor.run {
                                onFinish()
                            }
                        }
                    }
                )
                .frame(height: 50)

                // Sign up with Google
                GoogleSignInButtonView(
                    onSuccess: { idToken, accessToken, fullName in
                        Task {
                            // Show global loading overlay immediately
                            await MainActor.run {
                                startCompletion(message: "Signing you in...")
                            }
                            
                            do {
                                // Set the name from Google
                                if let name = fullName, !name.isEmpty {
                                    print("🔵 [SignInPage] Google provided name: '\(name)'")
                                    await MainActor.run {
                                        flowManager.name = name
                                    }
                                }
                                
                                try await authManager.signInWithGoogle(
                                    idToken: idToken,
                                    accessToken: accessToken,
                                    fullName: fullName
                                )
                                if let user = authManager.currentUser {
                                    await MainActor.run {
                                        updateMessage("Setting up your profile...")
                                    }
                                    await authManager.completeSignIn(user: user, modelContext: modelContext)
                                }
                                
                                await MainActor.run {
                                    updateMessage("Almost done...")
                                }
                                
                                // Google provides name, so finish directly
                                await finishOnboarding()
                                await MainActor.run {
                                    onFinish()
                                }
                            } catch {
                                print("🔵 Google Sign-In failed: \(error.localizedDescription)")
                                // Note: Can't easily reset global overlay state, but at least the error is logged
                            }
                        }
                    },
                    onError: { error in
                        print("🔵 Google Sign-In error: \(error.localizedDescription)")
                    }
                )
                .frame(height: 50)

                // Sign up with Email
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
                    .background(primaryText.opacity(0.1))
                    .foregroundStyle(primaryText)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(primaryText.opacity(0.2), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)

                // "Continue Without Account" - go to NamePage if no name yet
                Button {
                    // No sign-in = no name from auth provider
                    // Check if we have a name from somewhere (device extraction, etc.)
                    if hasValidName {
                        // We already have a name, finish directly with loading overlay
                        startCompletion(message: "Finishing setup...")
                        Task {
                            await finishOnboarding()
                            await MainActor.run {
                                onFinish()
                            }
                        }
                    } else {
                        // No name yet, go to NamePage (page 20)
                        flowManager.goNext()
                    }
                } label: {
                    Text("Continue Without Account")
                        .foregroundColor(secondaryText)
                        .underline()
                }
            }

            Spacer()
        }
        .padding(30)
        .sheet(isPresented: $showEmailSignUp) {
            EmailAuthView(
                isSignUp: true,
                userName: flowManager.name.isEmpty || flowManager.name == "User" ? nil : flowManager.name,
                onSuccess: {
                    Task {
                        await MainActor.run {
                            startCompletion(message: "Setting up your profile...")
                        }
                        // Email signup includes name entry in the form
                        await finishOnboarding()
                        await MainActor.run {
                            onFinish()
                        }
                    }
                }
            )
        }
    }

    private func finishOnboarding() async {
        print("🏁 [SignInPage] finishOnboarding called")
        print("🏁 [SignInPage] flowManager.name = '\(flowManager.name)'")
        let goalsToSave = flowManager.buildUserGoals()

        // Set userId if signed in (name comes from flowManager, not email)
        if let user = authManager.currentUser {
            print("🏁 [SignInPage] User is signed in: \(user.id) (\(user.email ?? "no email"))")
            goalsToSave.userId = user.id.uuidString.lowercased()
        } else {
            print("🏁 [SignInPage] No user signed in, skipping cloud upload")
        }

        modelContext.insert(goalsToSave)
        try? modelContext.save()
        print("🏁 [SignInPage] Goals saved locally")

        // Upload to cloud if signed in
        if authManager.currentUser != nil {
            print("🏁 [SignInPage] Starting cloud upload...")
            await authManager.uploadOnboardingToCloud(goals: goalsToSave)
            print("🏁 [SignInPage] Cloud upload completed")
        }
    }
}

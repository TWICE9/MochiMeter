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
    @Environment(\.colorScheme) private var colorScheme

    var onFinish: () -> Void

    var body: some View {
        ZStack {
            OnboardingTheme.baseBackground(colorScheme).ignoresSafeArea()
            _buildDynamicBackground()

            // Page content based on currentPage
            Group {
                switch flowManager.currentPage {
                case 0: WelcomePage(flowManager: flowManager, onFinish: onFinish)
                case 1: FeatureScreenPage(flowManager: flowManager)
                case 2: NamePage(flowManager: flowManager)
                case 3: GenderPage(flowManager: flowManager)
                case 4: ActivityLevelPage(flowManager: flowManager)
                case 5: HeightWeightPage(flowManager: flowManager)
                case 6: DateOfBirthPage(flowManager: flowManager)
                case 7: WeightGoalPage(flowManager: flowManager)
                case 8: TargetWeightPage(flowManager: flowManager)
                case 9: BlockersPage(flowManager: flowManager)
                case 10: DietTypePage(flowManager: flowManager)
                case 11: GoalsToAccomplishPage(flowManager: flowManager)
                case 12:
                    ThankYouAnimationView {
                        flowManager.goNext()
                    }
                case 13: HealthKitPermissionPage(flowManager: flowManager)
                // Referral code page removed (was case 14)
                case 14: DoneScreenPage(flowManager: flowManager)
                case 15:
                    LoadingScreenView {
                        flowManager.goNext()
                    }
                case 16: GoalsSummaryPage(flowManager: flowManager)
                case 17: SignInPage(flowManager: flowManager, authManager: authManager, modelContext: modelContext, onFinish: onFinish)
                default: EmptyView()
                }
            }
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            ))
            .id(flowManager.currentPage)
        }
    }

    @ViewBuilder
    private func _buildDynamicBackground() -> some View {
        let topGradientColor = colorScheme == .dark
            ? Color("AppSecondaryAccent").opacity(0.3)
            : Color("AppSecondaryAccent").opacity(0.15)
        let bottomGradientColor = colorScheme == .dark
            ? Color("AppPrimaryAccent").opacity(0.4)
            : Color("AppPrimaryAccent").opacity(0.2)

        ZStack {
            RadialGradient(
                gradient: Gradient(colors: [topGradientColor, .clear]),
                center: .topLeading,
                startRadius: 50,
                endRadius: 450
            )
            .offset(x: -150, y: -150)
            .ignoresSafeArea()

            RadialGradient(
                gradient: Gradient(colors: [bottomGradientColor, .clear]),
                center: .bottomTrailing,
                startRadius: 100,
                endRadius: 500
            )
            .offset(x: 100, y: 150)
            .ignoresSafeArea()
        }
        .blur(radius: 60)
    }
}

// MARK: - Placeholder Pages (to be implemented)

struct FeatureScreenPage: View {
    @Bindable var flowManager: OnboardingFlowManager
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let primaryText = OnboardingTheme.primaryText(colorScheme)
        let secondaryText = OnboardingTheme.secondaryText(colorScheme)

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

            ContinueButton(title: "Next", isEnabled: true) {
                flowManager.goNext()
            }
        }
        .padding(30)
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

            ContinueButton(title: "Continue", isEnabled: true) {
                flowManager.goNext()
            }
        }
    }
}

struct TargetWeightPage: View {
    @Bindable var flowManager: OnboardingFlowManager
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        OnboardingQuestionView(
            question: "What's your target weight?",
            subtitle: nil,
            progress: flowManager.progress,
            canGoBack: true,
            onBack: { flowManager.goBack() }
        ) {
            Picker("Target Weight", selection: $flowManager.targetWeight) {
                ForEach(30...180, id: \.self) { kg in
                    Text("\(kg) kg").tag(Double(kg))
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 200)
            .foregroundStyle(OnboardingTheme.primaryText(colorScheme))

            Spacer().frame(height: 20)

            ContinueButton(title: "Continue", isEnabled: flowManager.canProceed(for: 9)) {
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
                    Task {
                        do {
                            try await healthKitManager.requestAuthorization()
                            flowManager.healthKitEnabled = true
                        } catch {
                            print("HealthKit authorization failed: \(error)")
                            flowManager.healthKitEnabled = false
                        }
                        flowManager.goNext()
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

                Button {
                    flowManager.healthKitEnabled = false
                    flowManager.goNext()
                } label: {
                    Text("Not Now")
                        .font(.headline)
                        .foregroundColor(OnboardingTheme.secondaryText(colorScheme))
                }
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

            ContinueButton(title: "Continue", isEnabled: true) {
                flowManager.goNext()
            }

            Button("Skip") {
                flowManager.referralCode = ""
                flowManager.goNext()
            }
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

            ContinueButton(title: "Let's Go!", isEnabled: true) {
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

                ContinueButton(title: "Continue", isEnabled: true) {
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
    @Environment(\.colorScheme) private var colorScheme
    @State private var showEmailSignUp = false
    @State private var isFinishing = false

    var body: some View {
        let primaryText = OnboardingTheme.primaryText(colorScheme)
        let secondaryText = OnboardingTheme.secondaryText(colorScheme)

        // If user is already signed in (from WelcomePage), show completion page
        if authManager.currentUser != nil {
            alreadySignedInView(primaryText: primaryText, secondaryText: secondaryText)
        } else {
            // Show sign-in options for users who haven't signed in yet
            signInOptionsView(primaryText: primaryText, secondaryText: secondaryText)
        }
    }

    // MARK: - Already Signed In View
    @ViewBuilder
    private func alreadySignedInView(primaryText: Color, secondaryText: Color) -> some View {
        VStack(spacing: 30) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 120))
                .foregroundStyle(.green)

            Text("You're All Set!")
                .font(.largeTitle).bold()
                .foregroundStyle(primaryText)

            Text("Your profile has been created and you're signed in")
                .font(.headline)
                .foregroundStyle(secondaryText)
                .multilineTextAlignment(.center)

            Spacer()

            Button {
                isFinishing = true
                Task {
                    await finishOnboarding()
                    await MainActor.run {
                        onFinish()
                    }
                }
            } label: {
                HStack {
                    Text("Take Me Home")
                    Image(systemName: "arrow.right")
                }
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Color("AppSecondaryAccent"))
                .cornerRadius(16)
            }
            .disabled(isFinishing)
            .opacity(isFinishing ? 0.6 : 1)

            Spacer()
        }
        .padding(30)
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
                            await authManager.handleAppleAuthorization(authorization)
                            if let user = authManager.currentUser {
                                await authManager.completeSignIn(user: user, modelContext: modelContext)
                            }
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
                            do {
                                try await authManager.signInWithGoogle(
                                    idToken: idToken,
                                    accessToken: accessToken,
                                    fullName: fullName
                                )
                                if let user = authManager.currentUser {
                                    await authManager.completeSignIn(user: user, modelContext: modelContext)
                                }
                                await finishOnboarding()
                                await MainActor.run {
                                    onFinish()
                                }
                            } catch {
                                print("🔵 Google Sign-In failed: \(error.localizedDescription)")
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

                Button {
                    Task {
                        await finishOnboarding()
                        await MainActor.run {
                            onFinish()
                        }
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
                userName: flowManager.name.isEmpty ? nil : flowManager.name,
                onSuccess: {
                    Task {
                        // Note: completeSignIn is already called in EmailAuthView.submitForm()
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
        let goalsToSave = flowManager.buildUserGoals()

        // Set userId if signed in (name comes from flowManager, not email)
        if let user = authManager.currentUser {
            print("🏁 [SignInPage] User is signed in: \(user.id) (\(user.email ?? "no email"))")
            goalsToSave.userId = user.id.uuidString
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

// Screens/OnboardingScreen.swift

import SwiftUI
import SwiftData
import AuthenticationServices
import Auth

struct OnboardingScreen: View {
    
    // 1. Controls
    var onFinish: () -> Void
    @State private var currentPage: Int = 0

    // 2. Data
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var authManager: AuthManager
    @Environment(\.colorScheme) private var colorScheme

    @State private var goals: UserGoals?
    
    // 3. User Input State
    @State private var name: String = ""
    @State private var birthDate: Date = Calendar.current.date(byAdding: .year, value: -25, to: Date()) ?? Date()
    @State private var gender: Gender = .male
    @State private var height: Double = 170
    @State private var weight: Double = 70
    @State private var activityLevel: ActivityLevel = .moderateActivity
    @State private var weightGoal: GoalType = .maintain
    @State private var targetWeight: Double = 70 // This will be set by the picker
    
    // State for the weight pickers
    @State private var weightWhole: Int = 70
    @State private var weightFractional: Int = 0

    // State for email auth sheet
    @State private var showEmailSignUp: Bool = false
    @State private var showEmailSignIn: Bool = false

    private var baseBackgroundColor: Color {
        colorScheme == .dark
            ? Color("AppPrimaryDark")
            : Color(red: 244 / 255, green: 245 / 255, blue: 247 / 255)
    }
    private var primaryTextColor: Color {
        colorScheme == .dark ? Color("AppTextPrimary") : .black
    }
    private var secondaryTextColor: Color {
        primaryTextColor.opacity(0.8)
    }
    
    var body: some View {
        ZStack {
            baseBackgroundColor.ignoresSafeArea()
            _buildDynamicBackground()
            
            TabView(selection: $currentPage) {
                _buildWelcomePage().tag(0)
                _buildFeaturePage(
                    imageName: "fork.knife.circle.fill",
                    title: "Log Your Meals",
                    description: "Search a massive database of common and branded foods to track your calories and macros."
                ).tag(1)
                _buildFeaturePage(
                    imageName: "drop.fill",
                    title: "Track Water & Fasts",
                    description: "Hit your hydration goals with the water tracker and monitor your fasting zones."
                ).tag(2)
                _buildNamePage().tag(3)
                _buildGenderPage().tag(4)
                _buildMetricsPage().tag(5)
                _buildActivityPage().tag(6)
                _buildGoalPage().tag(7)
                _buildFinishPage().tag(8)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .ignoresSafeArea(edges: .bottom)
        }
    }
    
    // MARK: - Page Builders
    
    @ViewBuilder
    private func _buildWelcomePage() -> some View {
        VStack(spacing: 20) {
            Spacer()

            Text("Welcome to MochiMeter")
                .font(.system(size: 36, weight: .bold))
                .foregroundStyle(primaryTextColor)
                .multilineTextAlignment(.center)

            Text("Your new, personal health and nutrition tracker.")
                .font(.body)
                .foregroundStyle(secondaryTextColor)
                .multilineTextAlignment(.center)

            Spacer()

            // Get Started for new users
            _buildNextButton(title: "Get Started")

            // Divider
            HStack {
                Rectangle()
                    .fill(primaryTextColor.opacity(0.3))
                    .frame(height: 1)
                Text("or")
                    .foregroundColor(primaryTextColor.opacity(0.6))
                    .font(.caption)
                Rectangle()
                    .fill(primaryTextColor.opacity(0.3))
                    .frame(height: 1)
            }

            // Sign in for returning users
            VStack(spacing: 10) {
                Text("Already have an account?")
                    .foregroundColor(primaryTextColor.opacity(0.7))
                    .font(.caption)

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
                                let profileDownloaded = await authManager.downloadAndSyncProfile(modelContext: modelContext)

                                if profileDownloaded {
                                    print("✅ Profile downloaded, skipping onboarding")
                                    let userId = user.id.uuidString.lowercased()
                                    await CloudSyncManager.shared.performFullSync(userId: userId, context: modelContext)
                                } else {
                                    print("⚠️ No profile found, user should complete onboarding")
                                }
                            }

                            await MainActor.run {
                                onFinish()
                            }
                        }
                    }
                )
                .frame(height: 44)

                // Sign in with Email
                Button {
                    showEmailSignIn = true
                } label: {
                    HStack {
                        Image(systemName: "envelope.fill")
                        Text("Sign in with Email")
                    }
                    .font(.subheadline.weight(.semibold))
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                    .background(primaryTextColor.opacity(0.1))
                    .foregroundStyle(primaryTextColor)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(primaryTextColor.opacity(0.2), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 30)
        .padding(.bottom, 60) // Extra padding for page indicators
        .sheet(isPresented: $showEmailSignIn) {
            EmailAuthView(
                isSignUp: false,
                userName: nil,
                onSuccess: {
                    Task {
                        if let user = authManager.currentUser {
                            let profileDownloaded = await authManager.downloadAndSyncProfile(modelContext: modelContext)
                            if profileDownloaded {
                                let userId = user.id.uuidString.lowercased()
                                await CloudSyncManager.shared.performFullSync(userId: userId, context: modelContext)
                            }
                        }
                        await MainActor.run {
                            onFinish()
                        }
                    }
                }
            )
        }
    }
    
    @ViewBuilder
    private func _buildFeaturePage(imageName: String, title: String, description: String) -> some View {
        VStack(spacing: 30) {
            HStack {
                _buildBackButton()
                Spacer()
            }
            .padding(.top, 20)

            Spacer()
            Image(systemName: imageName)
                .font(.system(size: 120))
                .foregroundStyle(Color("AppSecondaryAccent"))

            Text(title)
                .font(.title).bold()
                .foregroundStyle(primaryTextColor)

            Text(description)
                .font(.headline)
                .foregroundStyle(secondaryTextColor)
                .multilineTextAlignment(.center)

            Spacer()
            _buildNextButton()
        }
        .padding(30)
    }

    @ViewBuilder
    private func _buildNamePage() -> some View {
        VStack(spacing: 30) {
            HStack {
                _buildBackButton()
                Spacer()
            }
            .padding(.top, 20)

            Spacer()

            Text("What's your name?")
                .font(.largeTitle).bold()
                .foregroundStyle(primaryTextColor)
                .multilineTextAlignment(.center)

            Text("We'll use this to personalize your experience")
                .font(.headline)
                .foregroundStyle(secondaryTextColor)
                .multilineTextAlignment(.center)

            TextField("Enter your first name", text: $name)
                .textFieldStyle(.plain)
                .font(.title2)
                .foregroundStyle(primaryTextColor)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(primaryTextColor.opacity(0.15))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(primaryTextColor.opacity(0.3), lineWidth: 1)
                )
                .autocorrectionDisabled()
                .textInputAutocapitalization(.words)

            Spacer()
            _buildNextButton()
        }
        .padding(30)
    }

    @ViewBuilder
    private func _buildGenderPage() -> some View {
        VStack(spacing: 20) {
            HStack {
                _buildBackButton()
                Spacer()
            }
            .padding(.top, 20)

            Text("Tell us about you")
                .font(.largeTitle).bold()
                .foregroundStyle(primaryTextColor)
                .padding(.top, 40)

            Text("This helps us calculate your calorie goals.")
                .font(.headline)
                .foregroundStyle(secondaryTextColor)
                .multilineTextAlignment(.center)

            Text("Gender").font(.headline).foregroundStyle(primaryTextColor).padding(.top)
            Picker("Gender", selection: $gender) {
                ForEach(Gender.allCases, id: \.self) {
                    Text($0.rawValue).tag($0)
                }
            }
            .pickerStyle(.segmented)
            .background(primaryTextColor.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            Text("Birthday").font(.headline).foregroundStyle(primaryTextColor).padding(.top)
            DatePicker("Birthday", selection: $birthDate, displayedComponents: .date)
                .datePickerStyle(.wheel)
                .labelsHidden()

            Spacer()
            _buildNextButton()
        }
        .padding(30)
    }
    
    @ViewBuilder
    private func _buildMetricsPage() -> some View {
        VStack(spacing: 20) {
            HStack {
                _buildBackButton()
                Spacer()
            }
            .padding(.top, 20)

            Text("Your Metrics")
                .font(.largeTitle).bold()
                .foregroundStyle(primaryTextColor)
                .padding(.top, 40)

            Text("Height (cm)").font(.headline).foregroundStyle(primaryTextColor).padding(.top)
            Picker("Height (cm)", selection: $height) {
                ForEach(120...220, id: \.self) { cm in
                    Text("\(cm) cm").tag(Double(cm))
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 150)

            Text("Weight (kg)").font(.headline).foregroundStyle(primaryTextColor).padding(.top)
            HStack(spacing: 0) {
                Picker("Kilograms", selection: $weightWhole) {
                    ForEach(30...180, id: \.self) { kg in
                        Text("\(kg)").tag(kg)
                    }
                }
                .pickerStyle(.wheel)
                .frame(width: 100)
                .clipped()

                Picker("Grams", selection: $weightFractional) {
                    ForEach(0...9, id: \.self) { g in
                        Text(".\(g) kg").tag(g)
                    }
                }
                .pickerStyle(.wheel)
                .frame(width: 100)
                .clipped()
            }
            .frame(height: 150)
            .onChange(of: weightWhole) { _, _ in updateWeight() }
            .onChange(of: weightFractional) { _, _ in updateWeight() }

            Spacer()
            _buildNextButton()
        }
        .padding(30)
        .onAppear {
            weightWhole = Int(weight)
            weightFractional = Int((weight.truncatingRemainder(dividingBy: 1)) * 10)
        }
    }
    
    @ViewBuilder
    private func _buildActivityPage() -> some View {
        VStack(spacing: 20) {
            HStack {
                _buildBackButton()
                Spacer()
            }
            .padding(.top, 20)

            Text("Activity Level")
                .font(.largeTitle).bold()
                .foregroundStyle(primaryTextColor)
                .padding(.top, 40)

            Picker("Activity Level", selection: $activityLevel) {
                ForEach(ActivityLevel.allCases, id: \.self) {
                    Text($0.rawValue).tag($0)
                }
            }
            .pickerStyle(.wheel)

            Spacer()
            _buildNextButton(title: "Next")
        }
        .padding(30)
    }
    
    @ViewBuilder
    private func _buildGoalPage() -> some View {
        VStack(spacing: 20) {
            HStack {
                _buildBackButton()
                Spacer()
            }
            .padding(.top, 20)

            Text("Your Goals")
                .font(.largeTitle).bold()
                .foregroundStyle(primaryTextColor)
                .padding(.top, 40)

            Text("What is your primary goal?")
                .font(.headline).foregroundStyle(primaryTextColor)
            Picker("Goal", selection: $weightGoal) {
                ForEach(GoalType.allCases, id: \.self) {
                    Text($0.rawValue).tag($0)
                }
            }
            .pickerStyle(.segmented)
            .background(primaryTextColor.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            Text("Target Weight (kg)")
                .font(.headline).foregroundStyle(primaryTextColor)
                .padding(.top, 30)

            Picker("Target Weight (kg)", selection: $targetWeight) {
                ForEach(30...180, id: \.self) { kg in
                    Text("\(kg) kg").tag(Double(kg)) // Tag as Double
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 150)

            Spacer()
            _buildNextButton(title: "Calculate My Goals")
        }
        .padding(30)
    }
    
    @ViewBuilder
    private func _buildFinishPage() -> some View {
        VStack(spacing: 30) {
            HStack {
                _buildBackButton()
                Spacer()
            }
            .padding(.top, 20)

            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 120))
                .foregroundStyle(.green)

            Text("All Set!")
                .font(.largeTitle).bold()
                .foregroundStyle(primaryTextColor)

            Text("Your personalized goals are ready. Let's start tracking!")
                .font(.headline)
                .foregroundStyle(secondaryTextColor)
                .multilineTextAlignment(.center)

            Spacer()
            
//            // MAIN: Start Using MochiMeter (always works, with or without account)
//            Button {
//                finishOnboarding()
//                onFinish()
//            } label: {
//                Text("Start Using MochiMeter")
//                    .font(.headline).bold()
//                    .padding()
//                    .frame(maxWidth: .infinity)
//                    .background(Color("AppSecondaryAccent"))
//                    .foregroundStyle(.black)
//                    .clipShape(RoundedRectangle(cornerRadius: 14))
//            }
//            .buttonStyle(.plain)
            
            // ─────────── Account Options ───────────
            VStack(spacing: 16) {
                Text("Create an account to sync your data")
                    .foregroundColor(primaryTextColor.opacity(0.7))
                    .font(.subheadline)

                // 🍎 Sign in with Apple
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
                            await MainActor.run {
                                finishOnboarding()
                                onFinish()
                            }
                        }
                    }
                )
                .frame(height: 50)

                // 📧 Sign up with Email
                Button {
                    showEmailSignUp = true
                } label: {
                    HStack {
                        Image(systemName: "envelope.fill")
                        Text("Sign up with Email")
                    }
                    .font(.headline)
                    .padding()
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

                // Skip
                Button {
                    finishOnboarding()
                    onFinish()
                } label: {
                    Text("Continue Without Account")
                        .foregroundColor(secondaryTextColor)
                        .underline()
                }
            }

            Spacer()
        }
        .padding(30)
        .sheet(isPresented: $showEmailSignUp) {
            EmailAuthView(
                isSignUp: true,
                userName: name.isEmpty ? nil : name,
                onSuccess: {
                    finishOnboarding()
                    onFinish()
                }
            )
        }
    }
    
    // MARK: - Helper Views & Functions

    @ViewBuilder
    private func _buildBackButton() -> some View {
        Button {
            withAnimation {
                currentPage -= 1
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                Text("Back")
                    .font(.body)
            }
            .foregroundStyle(primaryTextColor)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(primaryTextColor.opacity(0.15))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func _buildNextButton(title: String = "Next") -> some View {
        Button {
            withAnimation {
                currentPage += 1
            }
        } label: {
            Text(title)
                .font(.headline).bold()
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color("AppSecondaryAccent"))
                .foregroundStyle(.black)
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
    
    private func updateWeight() {
        weight = Double(weightWhole) + (Double(weightFractional) / 10.0)
        
        // Also update the default target weight
        if targetWeight == 0 || targetWeight == Double(weightWhole) {
            targetWeight = weight
        }
    }
    
    private func finishOnboarding() {
        Task {
            // Fetch or create user goals
            let fetchedGoals = await UserScopedQuery.fetchUserGoals(context: modelContext)
            let goalsToUpdate = fetchedGoals ?? UserGoals()

            let age = HealthCalculator.calculateAge(birthDate: birthDate)

            let calculatedMacros = HealthCalculator.calculateDailyGoals(
                gender: gender,
                weightKg: weight,
                heightCm: height,
                age: age,
                activityLevel: activityLevel,
                weightGoal: weightGoal
            )

            // Save profile data
            goalsToUpdate.name = name.isEmpty ? "User" : name
            goalsToUpdate.birthDate = birthDate
            goalsToUpdate.height = height
            goalsToUpdate.weight = weight
            goalsToUpdate.targetWeight = targetWeight
            goalsToUpdate.gender = gender
            goalsToUpdate.activityLevel = activityLevel
            goalsToUpdate.weightGoal = weightGoal

            // Save calculated goals
            goalsToUpdate.dailyCalories = calculatedMacros.targetCalories
            goalsToUpdate.dailyProtein = calculatedMacros.protein
            goalsToUpdate.dailyCarbs = calculatedMacros.carbs
            goalsToUpdate.dailyFat = calculatedMacros.fat

            // Set userId if user is signed in
            if let user = authManager.currentUser {
                goalsToUpdate.userId = user.id.uuidString.lowercased()
            }

            if fetchedGoals == nil {
                modelContext.insert(goalsToUpdate)
            }

            try? modelContext.save()

            // Upload to Supabase if user is signed in
            if authManager.currentUser != nil {
                await authManager.uploadOnboardingToCloud(goals: goalsToUpdate)
            }
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

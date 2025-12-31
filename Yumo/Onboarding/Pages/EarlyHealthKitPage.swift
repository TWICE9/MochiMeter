//
//  EarlyHealthKitPage.swift
//  Yumo
//
//  HealthKit permission page shown early in onboarding to pre-fill user data
//

import SwiftUI
import HealthKit

struct EarlyHealthKitPage: View {
    @Bindable var flowManager: OnboardingFlowManager
    @StateObject private var healthKitManager = HealthKitManager.shared
    @Environment(\.colorScheme) private var colorScheme
    @State private var isLoading = false
    @State private var dataLoaded = false
    @State private var loadedFields: [String] = []

    var body: some View {
        let primaryText = OnboardingTheme.primaryText(colorScheme)
        let secondaryText = OnboardingTheme.secondaryText(colorScheme)

        VStack(spacing: 24) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.15))
                    .frame(width: 120, height: 120)
                
                Image(systemName: "heart.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.red)
            }

            // Title
            Text("Speed Up Your Setup")
                .font(.title).bold()
                .foregroundStyle(primaryText)
                .multilineTextAlignment(.center)

            // Description
            Text("Connect Apple Health to automatically fill in your height, weight, and other details.")
                .font(.body)
                .foregroundStyle(secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            // Benefits list
            VStack(alignment: .leading, spacing: 12) {
                benefitRow(icon: "scalemass.fill", text: "Auto-fill your weight")
                benefitRow(icon: "ruler.fill", text: "Auto-fill your height")
                benefitRow(icon: "calendar", text: "Auto-fill date of birth")
                benefitRow(icon: "figure.stand", text: "Track steps for calorie burn")
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 16)

            // Success message
            if dataLoaded && !loadedFields.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Loaded: \(loadedFields.joined(separator: ", "))")
                        .font(.subheadline)
                        .foregroundStyle(secondaryText)
                }
                .padding(.vertical, 8)
                .transition(.opacity.combined(with: .scale))
            }

            Spacer()

            VStack(spacing: 12) {
                // Connect button
                Button {
                    Task {
                        await connectHealthKit()
                    }
                } label: {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .black))
                        } else {
                            Image(systemName: "heart.fill")
                            Text(dataLoaded ? "Connected ✓" : "Connect Apple Health")
                        }
                    }
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(dataLoaded ? Color.green : Color("AppSecondaryAccent"))
                    .cornerRadius(16)
                }
                .disabled(isLoading || flowManager.isNavigating)
                .padding(.horizontal, 24)

                // Continue/Skip button
                Button {
                    guard !flowManager.isNavigating else { return }
                    flowManager.goNext()
                } label: {
                    Text(dataLoaded ? "Continue" : "Skip for Now")
                        .font(.headline)
                        .foregroundColor(dataLoaded ? .black : secondaryText)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(dataLoaded ? Color("AppSecondaryAccent") : Color.clear)
                        .cornerRadius(16)
                }
                .disabled(flowManager.isNavigating)
                .padding(.horizontal, 24)
            }
            .padding(.bottom, 30)
        }
    }
    
    @ViewBuilder
    private func benefitRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(Color("AppSecondaryAccent"))
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(OnboardingTheme.primaryText(colorScheme))
        }
    }

    private func connectHealthKit() async {
        isLoading = true
        
        do {
            try await healthKitManager.requestAuthorization()
            flowManager.healthKitEnabled = true
            
            // Fetch profile data
            let profile = await healthKitManager.fetchProfileForOnboarding()
            
            // Apply to flow manager
            await MainActor.run {
                var fields: [String] = []
                
                if let weight = profile.weight, weight > 0 {
                    fields.append("Weight")
                }
                if let height = profile.height, height > 0 {
                    fields.append("Height")
                }
                if profile.dob != nil {
                    fields.append("Birthday")
                }
                if let sex = profile.sex, sex != .notSet {
                    fields.append("Gender")
                }
                
                flowManager.applyHealthKitData(
                    weight: profile.weight,
                    height: profile.height,
                    dob: profile.dob,
                    sex: profile.sex?.rawValue
                )
                
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    loadedFields = fields
                    dataLoaded = true
                }
            }
            
            // Small delay to show success state
            try? await Task.sleep(nanoseconds: 800_000_000)
            
            // Auto-advance if data was loaded
            await MainActor.run {
                if !flowManager.isNavigating {
                    flowManager.goNext()
                }
            }
            
        } catch {
            print("HealthKit authorization failed: \(error)")
            await MainActor.run {
                flowManager.healthKitEnabled = false
            }
        }
        
        await MainActor.run {
            isLoading = false
        }
    }
}

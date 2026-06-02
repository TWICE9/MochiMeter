//
//  NotificationPermissionPage.swift
//  Yumo
//
//  Notification permission page shown towards the end of onboarding
//

import SwiftUI
import UserNotifications

struct NotificationPermissionPage: View {
    @Bindable var flowManager: OnboardingFlowManager
    @Environment(\.colorScheme) private var colorScheme
    @State private var isLoading = false
    @State private var permissionGranted = false
    @State private var hasResponded = false

    var body: some View {
        let primaryText = OnboardingTheme.primaryText(colorScheme)
        let secondaryText = OnboardingTheme.secondaryText(colorScheme)

        VStack(spacing: 24) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(Color(colorScheme == .dark ? "AppPrimaryAccent" : "AppSecondaryAccent").opacity(0.15))
                    .frame(width: 120, height: 120)
                
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color("AppPrimaryAccent"), Color("AppSecondaryAccent")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            // Title
            Text("Stay on Track")
                .font(.title).bold()
                .foregroundStyle(primaryText)
                .multilineTextAlignment(.center)

            // Description
            Text("Enable notifications to get reminders for meals, water intake, and celebrate your progress milestones.")
                .font(.body)
                .foregroundStyle(secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            // Benefits list
            VStack(alignment: .leading, spacing: 12) {
                benefitRow(icon: "fork.knife", text: "Meal logging reminders")
                benefitRow(icon: "drop.fill", text: "Hydration reminders")
                benefitRow(icon: "flame.fill", text: "Streak motivation alerts")
                benefitRow(icon: "trophy.fill", text: "Goal achievement celebrations")
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 16)

            // Success message
            if hasResponded {
                HStack(spacing: 8) {
                    Image(systemName: permissionGranted ? "checkmark.circle.fill" : "info.circle.fill")
                        .foregroundColor(permissionGranted ? .green : .orange)
                    Text(permissionGranted ? "Notifications enabled!" : "You can enable later in Settings")
                        .font(.subheadline)
                        .foregroundStyle(secondaryText)
                }
                .padding(.vertical, 8)
                .transition(.opacity.combined(with: .scale))
            }

            Spacer()

            VStack(spacing: 12) {
                // Enable button
                Button {
                    Task {
                        await requestNotificationPermission()
                    }
                } label: {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .black))
                        } else {
                            Image(systemName: "bell.fill")
                            Text(hasResponded ? (permissionGranted ? "Enabled ✓" : "Settings") : "Enable Notifications")
                        }
                    }
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(hasResponded && permissionGranted ? Color.green : Color("AppSecondaryAccent"))
                    .cornerRadius(16)
                }
                .disabled(isLoading || flowManager.isNavigating || (hasResponded && permissionGranted))
                .padding(.horizontal, 24)

                // Continue/Skip button
                Button {
                    guard !flowManager.isNavigating else { return }
                    flowManager.goNext()
                } label: {
                    Text(hasResponded ? "Continue" : "Maybe Later")
                        .font(.headline)
                        .foregroundColor(hasResponded ? .black : secondaryText)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(hasResponded ? Color("AppSecondaryAccent") : Color.clear)
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

    private func requestNotificationPermission() async {
        isLoading = true
        
        let center = UNUserNotificationCenter.current()
        
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            
            await MainActor.run {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    permissionGranted = granted
                    hasResponded = true
                }
                
                if granted {
                    print("🔔 Notification permission granted during onboarding")
                    // Register for remote (push) notifications
                    UIApplication.shared.registerForRemoteNotifications()
                } else {
                    print("🔕 Notification permission denied during onboarding")
                }
            }
            
            // Small delay to show success state
            try? await Task.sleep(nanoseconds: 800_000_000)
            
            // Auto-advance if permission was granted
            if granted {
                await MainActor.run {
                    if !flowManager.isNavigating {
                        flowManager.goNext()
                    }
                }
            }
            
        } catch {
            print("⚠️ Notification permission error: \(error)")
            await MainActor.run {
                hasResponded = true
            }
        }
        
        await MainActor.run {
            isLoading = false
        }
    }
}

#Preview {
    NotificationPermissionPage(flowManager: OnboardingFlowManager())
}

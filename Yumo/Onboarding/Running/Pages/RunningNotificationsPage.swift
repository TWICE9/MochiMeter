//
//  RunningNotificationsPage.swift
//  Yumo
//
//  Captures the user's preference for workout-day reminders. When they
//  enable the toggle we request notification permission inline; if they've
//  previously denied it, we surface a hint to flip it on in Settings rather
//  than failing silently.
//

import SwiftUI
import UserNotifications

struct RunningNotificationsPage: View {
    @Bindable var flowManager: RunningOnboardingFlowManager
    @Environment(\.colorScheme) private var colorScheme

    @State private var authStatus: UNAuthorizationStatus = .notDetermined
    @State private var isRequesting = false

    var body: some View {
        let muted = OnboardingTheme.mutedText(colorScheme)

        OnboardingQuestionView(
            question: "Reminders to keep you going",
            subtitle: "We'll nudge you on training days so you never miss a session.",
            progress: flowManager.progress,
            canGoBack: true,
            onBack: { flowManager.goBack() }
        ) {
            VStack(spacing: 18) {
                heroIcon

                toggleCard

                if flowManager.workoutRemindersEnabled {
                    timePickerCard

                    if authStatus == .denied {
                        deniedHint
                    }
                }

                Text("You can change this any time in Settings.")
                    .font(.caption)
                    .foregroundColor(muted)
                    .multilineTextAlignment(.center)

                Spacer().frame(height: 8)

                ContinueButton(
                    title: "Continue",
                    isEnabled: !flowManager.isNavigating,
                    action: { flowManager.goNext() }
                )
            }
        }
        .task { await refreshAuthStatus() }
    }

    // MARK: - Hero icon

    private var heroIcon: some View {
        ZStack {
            Circle()
                .fill(Color.purple.opacity(0.15))
                .frame(width: 84, height: 84)
            Image(systemName: "bell.badge.fill")
                .font(.system(size: 36, weight: .bold))
                .foregroundColor(.purple)
        }
        .padding(.top, 4)
    }

    // MARK: - Toggle

    private var toggleCard: some View {
        let primary = OnboardingTheme.primaryText(colorScheme)
        let muted = OnboardingTheme.mutedText(colorScheme)
        let background = OnboardingTheme.cardBackground(colorScheme)
        let stroke = OnboardingTheme.cardStroke(colorScheme)

        return HStack(spacing: 14) {
            Image(systemName: "calendar.badge.clock")
                .font(.title3)
                .foregroundColor(.purple)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text("Training-day reminders")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(primary)
                Text("A nudge on every running day")
                    .font(.caption)
                    .foregroundColor(muted)
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { flowManager.workoutRemindersEnabled },
                set: { handleToggle($0) }
            ))
            .labelsHidden()
            .tint(.purple)
            .disabled(isRequesting)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(background)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(stroke, lineWidth: 1)
                )
        )
    }

    // MARK: - Time picker

    private var timePickerCard: some View {
        let primary = OnboardingTheme.primaryText(colorScheme)
        let muted = OnboardingTheme.mutedText(colorScheme)
        let background = OnboardingTheme.cardBackground(colorScheme)
        let stroke = OnboardingTheme.cardStroke(colorScheme)

        return VStack(alignment: .leading, spacing: 10) {
            Text("REMIND ME AT")
                .font(.caption.weight(.bold))
                .foregroundColor(muted)

            HStack {
                DatePicker(
                    "Reminder time",
                    selection: $flowManager.workoutReminderTime,
                    displayedComponents: .hourAndMinute
                )
                .datePickerStyle(.compact)
                .labelsHidden()
                .foregroundColor(primary)

                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(background)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(stroke, lineWidth: 1)
                    )
            )
        }
    }

    // MARK: - Permission denied hint

    private var deniedHint: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundColor(.orange)
            VStack(alignment: .leading, spacing: 4) {
                Text("Notifications are turned off for Yumo")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(OnboardingTheme.primaryText(colorScheme))
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Text("Open Settings")
                        .font(.caption.weight(.bold))
                        .foregroundColor(.purple)
                        .underline()
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.orange.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.orange.opacity(0.4), lineWidth: 1)
                )
        )
    }

    // MARK: - Permission flow

    private func handleToggle(_ newValue: Bool) {
        guard newValue else {
            flowManager.workoutRemindersEnabled = false
            return
        }

        // Turning on — request permission if we haven't yet.
        switch authStatus {
        case .authorized, .provisional, .ephemeral:
            flowManager.workoutRemindersEnabled = true
        case .denied:
            // System won't show the prompt again; the user must flip it in Settings.
            flowManager.workoutRemindersEnabled = true
        case .notDetermined:
            isRequesting = true
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
                Task { @MainActor in
                    isRequesting = false
                    flowManager.workoutRemindersEnabled = granted
                    await refreshAuthStatus()
                }
            }
        @unknown default:
            flowManager.workoutRemindersEnabled = true
        }
    }

    private func refreshAuthStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        await MainActor.run {
            authStatus = settings.authorizationStatus
        }
    }
}

//
//  RunningOnboardingScreen.swift
//  Yumo
//

import SwiftUI
import SwiftData
@preconcurrency import Supabase
import Auth

/// Container view for the running onboarding flow. Presented as a sheet from
/// the activity screen banner. On completion, persists a `RunningProfile`
/// locally and uploads it to Supabase.
struct RunningOnboardingScreen: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @State private var flowManager = RunningOnboardingFlowManager()
    @State private var isFinishing = false
    @State private var finishMessage: String = "Saving your plan…"
    /// Surfaced when a free user re-onboards while already having an active
    /// plan (treated as a regenerate). Profile updates still save; only the
    /// AI generation step is gated.
    @State private var showPaywall = false

    /// Confirmation prompt shown when the user finishes onboarding while
    /// they already have an active plan. Lets them choose between keeping
    /// their existing plan with the new preferences applied, or regenerating
    /// from scratch (premium gate fires from inside the confirmation).
    @State private var showRegenerateConfirm = false

    var onFinish: () -> Void

    var body: some View {
        ZStack {
            OnboardingTheme.baseBackground(colorScheme).ignoresSafeArea()

            // Subtle purple gradient overlay
            LinearGradient(
                colors: [Color.purple.opacity(colorScheme == .dark ? 0.18 : 0.10), Color.clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Group {
                switch flowManager.currentPage {
                case 0: RunningWelcomePage(flowManager: flowManager)
                case 1: RunningGoalPage(flowManager: flowManager)
                case 2: RunningExperiencePage(flowManager: flowManager)
                case 3: RunningBaselinePage(flowManager: flowManager)
                case 4: RunningTargetRacePage(flowManager: flowManager)
                case 5: RunningAvailabilityPage(flowManager: flowManager)
                case 6: RunningCrossTrainingPage(flowManager: flowManager)
                case 7: RunningInjuriesPage(flowManager: flowManager)
                case 8: RunningNotificationsPage(flowManager: flowManager)
                case 9: RunningSummaryPage(flowManager: flowManager, onFinish: finish)
                default: EmptyView()
                }
            }
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            ))
            .id(flowManager.currentPage)

            if isFinishing {
                // Lightweight overlay while we save the profile + kick off
                // generation. The full "Building your plan…" UX lives on the
                // Today tab now (PlanGeneratingCard) so the user can navigate
                // and do other things while the AI works.
                Color.black.opacity(0.25).ignoresSafeArea()
                ProgressView(finishMessage)
                    .progressViewStyle(.circular)
                    .padding(20)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
            }
        }
        .sheet(isPresented: $showPaywall, onDismiss: {
            // Whether they upgraded or not, exit the onboarding flow once
            // the paywall closes — profile updates were already persisted.
            onFinish()
        }) {
            PaywallView(trigger: "running_regenerate_onboarding")
        }
        .sheet(isPresented: $showRegenerateConfirm) {
            RegeneratePlanConfirmSheet(
                onKeepCurrent: handleKeepCurrentPlan,
                onRegenerate: handleRegenerate
            )
            .presentationDetents([.height(380)])
            .presentationDragIndicator(.visible)
            .presentationBackground(.ultraThinMaterial)
        }
        .task {
            // Pre-fill unit preference from UserGoals if available.
            if let goals = await UserScopedQuery.fetchUserGoals(context: modelContext) {
                flowManager.unitSystem = goals.unitSystem
            }
            // Pre-fill from an existing RunningProfile when re-editing.
            if let existing = await UserScopedQuery.fetchRunningProfile(context: modelContext) {
                flowManager.loadFrom(profile: existing)
            }
        }
    }

    // MARK: - Finish

    private func finish() {
        guard !isFinishing else { return }
        isFinishing = true
        finishMessage = "Saving your profile…"

        Task {
            // Live-session check — the cached UserSession value can drift from
            // Supabase's keychain-backed session (expired / not-refreshed /
            // sim reset), so we treat the live session as the source of truth.
            let liveSession = try? await supabase.auth.session
            let liveUserId = liveSession?.user.id.uuidString.lowercased()

            // --- Upsert local RunningProfile ---
            let profile: RunningProfile
            if let existing = await UserScopedQuery.fetchRunningProfile(context: modelContext) {
                profile = existing
            } else {
                let created = RunningProfile()
                created.userId = liveUserId
                modelContext.insert(created)
                profile = created
            }

            flowManager.apply(to: profile)
            try? modelContext.save()

            // Schedule (or clear) workout reminders to match the latest preferences.
            // Pre-generation we'll fall back to weekday-repeating nudges — once
            // the plan generation finishes below we re-run the scheduler so the
            // bodies become session-specific ("Today: Easy 5K"). See the second
            // refresh after `generatePlan` completes.
            await RunningWorkoutReminderScheduler.refresh(context: modelContext)

            // --- Offline / signed-out path: local save only, done ---
            guard let userId = liveUserId else {
                print("ℹ️ Running onboarding finished without a live session — saved locally only.")
                await MainActor.run {
                    isFinishing = false
                    onFinish()
                }
                return
            }

            // --- Cloud upload ---
            await CloudSyncManager.shared.uploadRunningProfileImmediately(
                profile,
                userId: userId
            )

            // If the user already has an active plan, this onboarding pass is
            // semantically a "regenerate." Surface a confirmation sheet so
            // they can choose to keep their existing plan (free, preferences
            // already saved above) or regenerate (premium gate fires from
            // inside the confirmation). Without this prompt, free users hit
            // a surprise paywall and premium users lose their plan without
            // any chance to confirm.
            let plansFetch = FetchDescriptor<RunningPlan>()
            let hasExistingPlan = ((try? modelContext.fetch(plansFetch))?
                .contains { $0.status == .active }) ?? false
            if hasExistingPlan {
                await MainActor.run {
                    UserDefaults.standard.removeObject(forKey: "yumo.planGenerationInProgress")
                    isFinishing = false
                    showRegenerateConfirm = true
                }
                return
            }

            // First-time generation — no existing plan, free for everyone.
            await runGeneration()
        }
    }

    /// Kicks off the AI generation step. Extracted so we can reuse it from
    /// both the first-plan path (called from `finish`) and the regenerate
    /// path (called when the user picks "Regenerate" in the confirmation).
    ///
    /// Dismisses the onboarding sheet immediately and continues generation
    /// in the background — the Today tab's PlanGeneratingCard handles the
    /// "Building…" UI and surfaces errors via `yumo.planGenerationLastError`.
    private func runGeneration() async {
        let startDate = flowManager.plannedStartDate
        let context = modelContext

        // Compute the canonical run-days using the SAME function the preview
        // uses, on the SAME flowManager state the user just confirmed. We
        // send those days to the edge function so the generated plan lands
        // on exactly the days the preview showed — preview ≡ plan, period.
        let allDays: [Weekday] = [.mon, .tue, .wed, .thu, .fri, .sat, .sun]
        let availableSorted = allDays.filter { flowManager.availableDays.contains($0) }
        let crossDays = Set(flowManager.crossTrainingSchedule.values.flatMap { $0 })
        let pickedDays = RunningPlanPreviewBuilder.chooseRunDays(
            from: availableSorted,
            target: max(1, flowManager.weeklyRunDaysTarget),
            longRunDay: flowManager.longRunDay,
            crossTrainingDays: crossDays
        )
        let runDays = pickedDays.map { $0.dayIndex }
        // If chooseRunDays dropped the user's long-run anchor (because it
        // collided with a cross-training day), reflect that in the value
        // we send to the server so it doesn't try to re-anchor on it.
        let resolvedLongRunDay: Weekday? = {
            guard let lr = flowManager.longRunDay else { return nil }
            return pickedDays.contains(lr) ? lr : nil
        }()
        let longRunDayIndex = resolvedLongRunDay?.dayIndex

        await MainActor.run {
            UserDefaults.standard.set(true, forKey: "yumo.planGenerationInProgress")
            UserDefaults.standard.set(startDate.timeIntervalSince1970,
                                      forKey: "yumo.planGenerationStartDate")
            UserDefaults.standard.removeObject(forKey: "yumo.planGenerationLastError")
            // Persist canonical days so the Today-tab "Retry" button can
            // resend the same set after a failed background generation.
            UserDefaults.standard.set(runDays, forKey: "yumo.planGenerationRunDays")
            if let lr = longRunDayIndex {
                UserDefaults.standard.set(lr, forKey: "yumo.planGenerationLongRunDay")
            } else {
                UserDefaults.standard.removeObject(forKey: "yumo.planGenerationLongRunDay")
            }
            isFinishing = false
            onFinish()
        }

        // Unstructured Task — survives the view going away. Errors get
        // written to AppStorage so the Today tab's card can flip into
        // an error state with a Retry button.
        Task {
            do {
                _ = try await RunningPlanService.shared.generatePlan(
                    force: true,
                    startDate: startDate,
                    runDays: runDays,
                    longRunDayIndex: longRunDayIndex,
                    context: context
                )
                // Plan + sessions are now in SwiftData — re-run the scheduler
                // so each upcoming day's nudge gets a session-specific body.
                await RunningWorkoutReminderScheduler.refresh(context: context)
                await MainActor.run {
                    UserDefaults.standard.removeObject(forKey: "yumo.planGenerationInProgress")
                    UserDefaults.standard.removeObject(forKey: "yumo.planGenerationLastError")
                }
            } catch let error as RunningPlanGenerationError {
                await MainActor.run {
                    UserDefaults.standard.removeObject(forKey: "yumo.planGenerationInProgress")
                    // Rate-limit during re-onboarding is benign — user already has a plan from earlier.
                    if case .rateLimited = error {
                        UserDefaults.standard.removeObject(forKey: "yumo.planGenerationLastError")
                    } else {
                        UserDefaults.standard.set(
                            error.errorDescription ?? "Plan generation failed.",
                            forKey: "yumo.planGenerationLastError"
                        )
                    }
                }
            } catch {
                await MainActor.run {
                    UserDefaults.standard.removeObject(forKey: "yumo.planGenerationInProgress")
                    UserDefaults.standard.set(
                        error.localizedDescription,
                        forKey: "yumo.planGenerationLastError"
                    )
                }
            }
        }
    }

    // MARK: - Regenerate confirmation handlers

    private func handleKeepCurrentPlan() {
        showRegenerateConfirm = false
        // Profile updates already saved + uploaded above. Nothing else to do —
        // the existing active plan stays intact.
        onFinish()
    }

    private func handleRegenerate() {
        showRegenerateConfirm = false
        // Premium gate fires here, after the user explicitly chose to
        // regenerate. Free users see the paywall; on dismiss they exit
        // the onboarding flow with their old plan intact.
        if !StoreKitManager.shared.isPremium {
            showPaywall = true
            return
        }
        Task { await runGeneration() }
    }
}

// MARK: - Confirmation sheet

/// Shown when a user finishes onboarding while they already have an active
/// plan. Lets them keep the existing plan with refreshed preferences or
/// regenerate from scratch (premium gate fires inside the regenerate path).
private struct RegeneratePlanConfirmSheet: View {
    var onKeepCurrent: () -> Void
    var onRegenerate: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    private var primaryText: Color { Color("AppTextPrimary") }
    private var secondaryText: Color { Color("AppTextPrimary").opacity(0.7) }
    private var tertiaryText: Color { Color("AppTextPrimary").opacity(0.5) }

    var body: some View {
        VStack(spacing: 18) {
            header

            VStack(spacing: 10) {
                optionCard(
                    icon: "checkmark.circle.fill",
                    accent: .green,
                    title: "Keep my current plan",
                    subtitle: "Your updated preferences are saved. Plan stays the same.",
                    action: onKeepCurrent
                )
                optionCard(
                    icon: "sparkles",
                    accent: .purple,
                    title: "Regenerate my plan",
                    subtitle: "Build a fresh plan from your updated profile",
                    action: onRegenerate
                )
            }
            .padding(.horizontal, 20)

            Spacer(minLength: 0)
        }
        .padding(.top, 44)
    }

    private var header: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(Color.purple.opacity(0.15))
                    .frame(width: 56, height: 56)
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Color.purple)
            }
            Text("You already have a plan")
                .font(.title3.weight(.bold))
                .foregroundStyle(primaryText)
            Text("Want to keep your current plan, or generate a fresh one from your updated profile?")
                .font(.subheadline)
                .foregroundStyle(secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private func optionCard(
        icon: String,
        accent: Color,
        title: String,
        subtitle: String,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            action()
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(accent.opacity(0.18))
                        .frame(width: 40, height: 40)
                    Image(systemName: icon)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(accent)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(primaryText)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(secondaryText)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(tertiaryText)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(colorScheme == .dark
                          ? Color("AppCardBackground")
                          : Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(accent.opacity(0.25), lineWidth: 1)
                    )
                    .shadow(
                        color: .black.opacity(colorScheme == .dark ? 0 : 0.04),
                        radius: 4, y: 2
                    )
            )
        }
        .buttonStyle(RegenerateConfirmPressStyle())
    }
}

private struct RegenerateConfirmPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

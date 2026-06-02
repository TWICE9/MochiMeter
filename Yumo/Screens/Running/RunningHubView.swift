//
//  RunningHubView.swift
//  Yumo
//
//  Self-contained "Running App" presented as a fullScreenCover from the
//  activity screen. Has its own tab bar, navigation, and running-specific
//  context — Today, Plan, Progress, and Profile.
//

import SwiftUI
import SwiftData
import Auth

struct RunningHubView: View {
    let isImperial: Bool
    var onRegenerate: () -> Void
    var onClose: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var authManager: AuthManager
    @EnvironmentObject private var themeManager: ThemeManager

    @Query(sort: \RunningPlan.createdAt, order: .reverse) private var allRunningPlans: [RunningPlan]
    @Query private var allRunningProfiles: [RunningProfile]

    @State private var selectedTab: HubTab = .today
    @State private var sessionToComplete: PlannedSession? = nil
    @State private var selectedRunForDetail: LoggedRun? = nil
    @State private var selectedSessionForDetail: PlannedSession? = nil
    @Namespace private var tabAnimation

    enum HubTab: String, CaseIterable {
        case today    = "Today"
        case plan     = "Plan"
        case progress = "Progress"
        case profile  = "Profile"

        var icon: String {
            switch self {
            case .today:    return "house.fill"
            case .plan:     return "calendar"
            case .progress: return "chart.bar.fill"
            case .profile:  return "figure.run"
            }
        }
    }

    private var activeRunningPlan: RunningPlan? {
        let userId = authManager.currentUser?.id.uuidString.lowercased()
        return allRunningPlans.first { $0.status == .active && ($0.userId == userId || $0.userId == nil) }
    }

    private var runningProfile: RunningProfile? {
        let userId = authManager.currentUser?.id.uuidString.lowercased()
        return allRunningProfiles.first { $0.userId == userId || $0.userId == nil }
    }

    private var ambientBackground: some View {
        ZStack {
            Color("AppPrimaryDark", bundle: nil).ignoresSafeArea()

            RadialGradient(
                gradient: Gradient(colors: [
                    colorScheme == .light
                        ? themeManager.currentTheme.primaryColor.opacity(0.25)
                        : themeManager.currentTheme.darkPrimaryColor.opacity(0.12),
                    .clear
                ]),
                center: .topLeading,
                startRadius: 50,
                endRadius: 550
            )
            .offset(x: -80, y: -100)
            .ignoresSafeArea()

            RadialGradient(
                gradient: Gradient(colors: [
                    themeManager.currentTheme.complementaryColor.opacity(colorScheme == .light ? 0.2 : 0.1),
                    .clear
                ]),
                center: .bottomTrailing,
                startRadius: 100,
                endRadius: 500
            )
            .offset(x: 50, y: 80)
            .ignoresSafeArea()
        }
    }

    var body: some View {
        ZStack {
            ambientBackground

            VStack(spacing: 0) {
                topBar

                // Tab content
                Group {
                    switch selectedTab {
                    case .today:
                        RunningTodayView(
                            plan: activeRunningPlan,
                            isImperial: isImperial,
                            onMarkComplete: { sessionToComplete = $0 },
                            onSwitchToTab: { selectedTab = $0 },
                            onRunSelected: { selectedRunForDetail = $0 },
                            onSessionTapped: { selectedSessionForDetail = $0 },
                            onClearPlan: { clearActivePlan() }
                        )
                    case .plan:
                        RunningPlanBrowserView(
                            plan: activeRunningPlan,
                            isImperial: isImperial,
                            onMarkComplete: { sessionToComplete = $0 }
                        )
                    case .progress:
                        RunningProgressView(
                            plan: activeRunningPlan,
                            isImperial: isImperial
                        )
                    case .profile:
                        RunningProfileHubView(
                            profile: runningProfile,
                            plan: activeRunningPlan,
                            isImperial: isImperial,
                            onRegenerate: onRegenerate
                        )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .safeAreaInset(edge: .bottom) { hubTabBar }
        .ignoresSafeArea(edges: .bottom)
        .sheet(item: $sessionToComplete) { session in
            SessionCompleteSheet(
                session: session,
                isImperial: isImperial,
                onComplete: { distKm, durMins, source in
                    applyCompletion(session, distanceKm: distKm, durationMinutes: durMins, source: source)
                },
                onSkip: { markSkipped(session) },
                onUnmark: { unmark(session) }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $selectedRunForDetail) { run in
            RunDetailView(run: run)
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $selectedSessionForDetail) { session in
            NavigationStack {
                SessionDetailView(
                    session: session,
                    isImperial: isImperial,
                    onMarkComplete: { sessionToComplete = $0 }
                )
            }
            .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Colors

    private var primaryText: Color { Color("AppTextPrimary") }
    private var tertiaryText: Color { Color("AppTextPrimary").opacity(0.5) }

    // MARK: - Top bar

    private var topBar: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Running")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(Color("AppTextPrimary").opacity(0.8))
                
                Text(selectedTab.rawValue)
                    .font(.headline)
                    .foregroundStyle(tertiaryText)
            }

            Spacer()

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(tertiaryText)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color("AppTextPrimary").opacity(0.08)))
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 8)
    }

    // MARK: - Tab bar

    private var hubTabBar: some View {
        HStack(spacing: 0) {
            ZStack {
                if #unavailable(iOS 26) {
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)

                    Capsule()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    .white.opacity(colorScheme == .light ? 0.6 : 0.3),
                                    .white.opacity(colorScheme == .light ? 0.2 : 0.05)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                }

                HStack(alignment: .center, spacing: 0) {
                    ForEach(HubTab.allCases, id: \.self) { tab in
                        hubTabItem(tab)
                    }
                }
                .padding(.horizontal, 12)
            }
            .frame(height: 70)
            .modifier(GlassEffectModifier(shape: .capsule))
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
    }

    @ViewBuilder
    private func hubTabItem(_ tab: HubTab) -> some View {
        let isSelected = selectedTab == tab
        let activeColor = themeManager.currentTheme.primaryColor

        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { selectedTab = tab }
        } label: {
            ZStack {
                if isSelected {
                    Capsule()
                        .fill(activeColor.opacity(0.15))
                        .matchedGeometryEffect(id: "HubTabBackground", in: tabAnimation)
                }

                VStack(spacing: 4) {
                    Image(systemName: tab.icon)
                        .font(.system(size: 20, weight: isSelected ? .bold : .semibold))
                        .foregroundStyle(isSelected ? activeColor : tertiaryText)
                        .scaleEffect(isSelected ? 1.1 : 1.0)

                    Text(tab.rawValue)
                        .font(.caption2)
                        .fontWeight(isSelected ? .semibold : .regular)
                        .foregroundStyle(isSelected ? activeColor : tertiaryText)
                }
                .padding(.vertical, 10)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 55)
            .contentShape(Rectangle())
        }
        .buttonStyle(MainTabView.ScaleButtonStyle())
    }

    // MARK: - Session actions

    private func applyCompletion(_ session: PlannedSession, distanceKm: Double?, durationMinutes: Int?, source: String) {
        let now = Date()
        session.completedAt = now
        session.completedDistanceKm = distanceKm
        session.completedDurationMinutes = durationMinutes
        session.completedSource = source
        session.skipped = false
        session.updatedAt = now
        try? modelContext.save()
        Task.detached(priority: .background) {
            await CloudSyncManager.shared.uploadPlannedSessionImmediately(session)
        }
    }

    private func markSkipped(_ session: PlannedSession) {
        let now = Date()
        session.skipped = true
        session.completedAt = nil
        session.completedDistanceKm = nil
        session.completedDurationMinutes = nil
        session.completedSource = nil
        session.updatedAt = now
        try? modelContext.save()
        Task.detached(priority: .background) {
            await CloudSyncManager.shared.uploadPlannedSessionImmediately(session)
        }
    }

    private func unmark(_ session: PlannedSession) {
        let now = Date()
        session.completedAt = nil
        session.completedDistanceKm = nil
        session.completedDurationMinutes = nil
        session.completedSource = nil
        session.skipped = false
        session.updatedAt = now
        try? modelContext.save()
        Task.detached(priority: .background) {
            await CloudSyncManager.shared.uploadPlannedSessionImmediately(session)
        }
    }

    private func clearActivePlan() {
        guard let plan = activeRunningPlan else { return }
        let planId = plan.id

        // Delete from Supabase first — if we delete locally and the cloud copy
        // survives, the next syncRunningPlans run will see "missing locally /
        // present in cloud" and resurrect the plan.
        Task { @MainActor in
            let cloudOK = await CloudSyncManager.shared.deleteRunningPlanFromCloud(planId)
            // We still want the local delete to apply offline / signed-out, so
            // proceed even if the cloud call failed (it'll be re-attempted on
            // a future sync once the sync logic learns to push deletions).
            withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                if let plan = activeRunningPlan, plan.id == planId {
                    modelContext.delete(plan)
                    try? modelContext.save()
                }
                // Land the user on Today regardless of where the delete fired
                // from, so they see the empty-state CTA rather than a blank
                // Plan/Progress tab.
                selectedTab = .today
            }
            // Plan is gone — refresh reminders so we don't keep firing
            // session-specific nudges that point to deleted PlannedSessions.
            await RunningWorkoutReminderScheduler.refresh(context: modelContext)
            if !cloudOK {
                print("⚠️ Plan deleted locally but cloud delete failed — sync may resurrect it.")
            }
        }
    }
}

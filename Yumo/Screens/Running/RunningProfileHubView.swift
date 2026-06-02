//
//  RunningProfileHubView.swift
//  Yumo
//

import SwiftUI

struct RunningProfileHubView: View {
    let profile: RunningProfile?
    let plan: RunningPlan?
    let isImperial: Bool
    var onRegenerate: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var showRegenerateConfirm = false

    private var primaryText: Color { Color("AppTextPrimary") }
    private var secondaryText: Color { Color("AppTextPrimary").opacity(0.8) }
    private var tertiaryText: Color { Color("AppTextPrimary").opacity(0.5) }

    private var unitLabel: String { isImperial ? "mi" : "km" }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                if let profile { profileCard(profile) } else { noProfileCard }
                if plan != nil { planActionsCard }

                Spacer().frame(height: 100)
            }
            .padding(.top, 20)
        }
        .confirmationDialog("Regenerate Plan", isPresented: $showRegenerateConfirm, titleVisibility: .visible) {
            Button("Regenerate", role: .destructive) { onRegenerate() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will replace your current plan with a new AI-generated one.")
        }
    }

    // MARK: - Profile card

    private func profileCard(_ p: RunningProfile) -> some View {
        FrostedGlassContainer {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    Image(systemName: "person.fill").foregroundStyle(Color.purple)
                    Text("Running Profile").font(.headline).foregroundStyle(primaryText)
                }

                Divider().opacity(0.3)

                VStack(spacing: 0) {
                    profileRow(icon: "figure.run", label: "Experience",
                               value: p.experience.rawValue, color: .purple)
                    profileRow(icon: "target", label: "Goal",
                               value: p.primaryGoal.rawValue, color: .blue)
                    profileRow(icon: "calendar", label: "Runs per week",
                               value: "\(p.weeklyRunDaysTarget) days", color: .orange)

                    if let days = p.availableDays as? [Weekday], !days.isEmpty {
                        let sorted = [Weekday.mon, .tue, .wed, .thu, .fri, .sat, .sun]
                            .filter { days.contains($0) }
                        profileRow(icon: "clock", label: "Available days",
                                   value: sorted.map(\.shortLabel).joined(separator: " · "), color: .teal)
                    }

                    if let km = p.currentLongestRunKm {
                        let d = isImperial ? km * 0.621371 : km
                        profileRow(icon: "arrow.up.right.circle", label: "Longest run",
                                   value: String(format: "%.1f %@", d, unitLabel), color: .green)
                    }

                    if let km = p.currentWeeklyKm {
                        let d = isImperial ? km * 0.621371 : km
                        profileRow(icon: "chart.bar", label: "Weekly volume",
                                   value: String(format: "%.0f %@", d, unitLabel), color: .green)
                    }

                    let benchmarks = benchmarkTimesString(p)
                    if !benchmarks.isEmpty {
                        profileRow(icon: "stopwatch", label: "Recent times",
                                   value: benchmarks, color: .purple)
                    }

                    if let dist = p.targetRaceDistance {
                        Divider().opacity(0.2).padding(.vertical, 4)
                        profileRow(icon: "flag.checkered", label: "Race",
                                   value: dist.rawValue, color: .red)
                        if let date = p.targetRaceDate {
                            profileRow(icon: "calendar.badge.clock", label: "Race date",
                                       value: date.formatted(date: .abbreviated, time: .omitted), color: .red)
                        }
                        if let secs = p.targetRaceGoalTimeSeconds {
                            profileRow(icon: "clock.badge.checkmark", label: "Goal time",
                                       value: formatSeconds(secs), color: .red)
                        }
                    }

                    if let injuries = p.injuriesOrLimitations, !injuries.isEmpty {
                        Divider().opacity(0.2).padding(.vertical, 4)
                        profileRow(icon: "bandage", label: "Limitations",
                                   value: injuries, color: .gray)
                    }
                }
            }
        }
        .padding(.horizontal, 24)
    }

    private func profileRow(icon: String, label: String, value: String, color: Color) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(color.opacity(0.12)).frame(width: 34, height: 34)
                Image(systemName: icon).font(.subheadline.weight(.semibold)).foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(label).font(.caption.weight(.semibold)).foregroundStyle(tertiaryText)
                Text(value).font(.subheadline.weight(.semibold)).foregroundStyle(primaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(.vertical, 6)
    }

    // MARK: - Plan actions

    private var planActionsCard: some View {
        FrostedGlassContainer {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    Image(systemName: "gearshape.fill").foregroundStyle(Color.purple)
                    Text("Plan Actions").font(.headline).foregroundStyle(primaryText)
                }

                Divider().opacity(0.3)

                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    showRegenerateConfirm = true
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle().fill(Color.orange.opacity(0.12)).frame(width: 36, height: 36)
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.subheadline.weight(.semibold)).foregroundStyle(.orange)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Regenerate Plan")
                                .font(.subheadline.weight(.semibold)).foregroundStyle(primaryText)
                            Text("Build a new AI plan from your current profile")
                                .font(.caption).foregroundStyle(secondaryText)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold)).foregroundStyle(tertiaryText)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 24)
    }

    // MARK: - No profile

    private var noProfileCard: some View {
        FrostedGlassContainer {
            VStack(spacing: 14) {
                Image(systemName: "person.crop.circle.badge.questionmark")
                    .font(.system(size: 48)).foregroundStyle(Color.purple.opacity(0.4))
                Text("No profile found").font(.headline).foregroundStyle(primaryText)
                Text("Complete the running onboarding to set up your profile.")
                    .font(.subheadline).foregroundStyle(secondaryText).multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 20)
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Helpers

    private func benchmarkTimesString(_ p: RunningProfile) -> String {
        [("1K", p.recent1kmSeconds), ("5K", p.recent5kmSeconds), ("10K", p.recent10kmSeconds),
         ("HM", p.recentHalfMarathonSeconds), ("FM", p.recentMarathonSeconds)]
            .compactMap { label, secs in secs.map { "\(label) \(formatSeconds($0))" } }
            .joined(separator: " · ")
    }

    private func formatSeconds(_ t: Int) -> String {
        let h = t / 3600; let m = (t % 3600) / 60; let s = t % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }
}

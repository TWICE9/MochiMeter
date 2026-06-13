//
//  WeeklyCheckinSheet.swift
//  Yumo
//
//  Phase 3 of plan adaptation: the Sunday check-in. A local notification
//  fires Sunday evening; tapping it (or just opening the app within the
//  show window) surfaces this sheet over the running plan view, asking
//  how the week felt. The 3-button choice routes to `adapt-running-plan`
//  with a `weekly_*` reason — the AI tunes the plan from there.
//
//  "Felt easy"  → weeklyTooEasy   → AI adds intensity / volume to next week
//  "Just right" → weeklyJustRight → AI returns no changes (silent)
//  "Too hard"   → weeklyTooHard   → AI reduces volume + intensity
//

import SwiftUI
import SwiftData

// MARK: - Sheet

/// Sunday evening check-in sheet. Same visual language as FineTunePlanSheet
/// (sparkles header, themed cards, ultra-thin material backdrop).
struct WeeklyCheckinSheet: View {
    var onChoose: (AdaptationReason) -> Void
    var onCancel: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    private var primaryText: Color { Color("AppTextPrimary") }
    private var secondaryText: Color { Color("AppTextPrimary").opacity(0.7) }
    private var tertiaryText: Color { Color("AppTextPrimary").opacity(0.5) }

    var body: some View {
        VStack(spacing: 18) {
            header

            VStack(spacing: 10) {
                optionCard(
                    reason: .weeklyTooEasy,
                    icon: "bolt.fill",
                    accent: .runOrange,
                    title: "Felt easy",
                    subtitle: "Add some intensity to next week"
                )
                optionCard(
                    reason: .weeklyJustRight,
                    icon: "checkmark.seal.fill",
                    accent: .runDone,
                    title: "Just right",
                    subtitle: "Keep the plan as it is"
                )
                optionCard(
                    reason: .weeklyTooHard,
                    icon: "leaf.fill",
                    accent: .runBlue,
                    title: "Too hard",
                    subtitle: "Ease back the volume and intensity"
                )
            }
            .padding(.horizontal, 20)

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onCancel()
            } label: {
                Text("Skip this week")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(tertiaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)

            Spacer(minLength: 0)
        }
        .padding(.top, 44)
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(Color.runAccent.opacity(0.15))
                    .frame(width: 56, height: 56)
                Image(systemName: "calendar.badge.checkmark")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Color.runAccent)
            }
            Text("How did this week feel?")
                .font(.title3.weight(.bold))
                .foregroundStyle(primaryText)
            Text("Your honest take helps us tune next week's plan.")
                .font(.subheadline)
                .foregroundStyle(secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Option card

    @ViewBuilder
    private func optionCard(
        reason: AdaptationReason,
        icon: String,
        accent: Color,
        title: String,
        subtitle: String
    ) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            onChoose(reason)
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
        .buttonStyle(WeeklyCheckinPressStyle())
    }
}

/// Mirrors the press-down feel used by the Fine-tune sheet's option cards
/// so both check-in surfaces feel like they belong to the same family.
private struct WeeklyCheckinPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Should-show controller

/// Owns the "is now a good time to surface the weekly check-in?" decision so
/// the sheet only fires inside the Sun-evening → Wed window and at most once
/// per week. Tracks the last-prompted timestamp in UserDefaults to avoid
/// re-showing if the user dismissed without choosing.
@MainActor
enum WeeklyCheckinController {

    /// UserDefaults key. Updated whenever the sheet is shown (responded or
    /// skipped) so a 5-day cooldown gates re-display.
    private static let lastPromptedKey = "yumo.lastWeeklyCheckinPromptedAt"

    /// Cooldown after a prompt. 5 days lets us miss one Sunday without
    /// re-prompting on the next, while not forever-suppressing if the user
    /// closes the app right after dismissing.
    private static let cooldownDays = 5

    /// True when:
    ///   - There's an active running plan
    ///   - Workout reminders are enabled (gates the whole feature)
    ///   - It's the show window (Sun ≥6 PM through Wed end-of-day)
    ///   - We haven't prompted in the last `cooldownDays`
    static func shouldShow(context: ModelContext) -> Bool {
        // Active plan?
        let plansFetch = FetchDescriptor<RunningPlan>()
        guard ((try? context.fetch(plansFetch))?.first { $0.status == .active }) != nil else {
            return false
        }

        // Reminders on?
        let profileFetch = FetchDescriptor<RunningProfile>()
        guard let profile = (try? context.fetch(profileFetch))?.first,
              profile.workoutRemindersEnabled
        else { return false }

        // Show window?
        let cal = Calendar.current
        let now = Date()
        let weekday = cal.component(.weekday, from: now)   // 1=Sun..7=Sat
        switch weekday {
        case 1:   // Sunday — only after 6 PM
            if cal.component(.hour, from: now) < 18 { return false }
        case 2, 3, 4:   // Mon, Tue, Wed — any time
            break
        default:   // Thu/Fri/Sat — too late, wait for next Sunday
            return false
        }

        // Cooldown?
        let lastPrompted = UserDefaults.standard.double(forKey: lastPromptedKey)
        if lastPrompted > 0 {
            let lastDate = Date(timeIntervalSince1970: lastPrompted)
            let elapsed = now.timeIntervalSince(lastDate)
            if elapsed < TimeInterval(cooldownDays) * 24 * 3600 {
                return false
            }
        }

        return true
    }

    /// Records a prompt so the cooldown kicks in regardless of whether the
    /// user chose an option or dismissed.
    static func markPrompted() {
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: lastPromptedKey)
    }
}

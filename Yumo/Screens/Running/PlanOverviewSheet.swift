//
//  PlanOverviewSheet.swift
//  Yumo

import SwiftUI
import SwiftData

struct PlanOverviewSheet: View {
    let plan: RunningPlan
    let isImperial: Bool

    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    @State private var isEditing = false
    @State private var editName: String = ""
    @State private var editRaceName: String = ""
    @State private var editRaceDate: Date = Date()
    @State private var editHasRaceDate: Bool = false
    @State private var editGoalHours: Int = 0
    @State private var editGoalMinutes: Int = 0
    @State private var editGoalSeconds: Int = 0
    @State private var editHasGoalTime: Bool = false

    private var primaryText: Color { Color("AppTextPrimary") }
    private var secondaryText: Color { Color("AppTextPrimary").opacity(0.8) }
    private var tertiaryText: Color { Color("AppTextPrimary").opacity(0.5) }

    private var unitLabel: String { isImperial ? "mi" : "km" }
    private var today: Date { Calendar.current.startOfDay(for: Date()) }

    private var runs: [PlannedSession] { plan.sessions.filter { $0.sessionType.isRun } }
    private var done: Int { runs.filter(\.isCompleted).count }
    private var totalPlannedKm: Double { runs.compactMap(\.targetDistanceKm).reduce(0, +) }
    private var endDate: Date {
        Calendar.current.date(byAdding: .weekOfYear, value: plan.totalWeeks, to: plan.startDate) ?? plan.startDate
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    heroSection
                    detailsSection
                    statsSection
                    Spacer().frame(height: 40)
                }
                .padding(.top, 24)
            }
            .navigationTitle(isEditing ? "Edit Plan" : "Plan Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if isEditing {
                        Button("Cancel") {
                            isEditing = false
                        }
                        .foregroundStyle(tertiaryText)
                    } else {
                        Button("Done") { dismiss() }
                            .foregroundStyle(Color.purple)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isEditing {
                        Button("Save") { saveEdits() }
                            .font(.headline)
                            .foregroundStyle(Color.purple)
                    } else {
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            loadEditState()
                            isEditing = true
                        } label: {
                            Label("Edit", systemImage: "pencil")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.purple)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if isEditing {
                VStack(alignment: .leading, spacing: 8) {
                    fieldLabel("PLAN NAME")
                    TextField("Plan name", text: $editName)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(primaryText)
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.purple.opacity(0.07)))

                    fieldLabel("RACE / EVENT NAME (OPTIONAL)")
                    TextField("e.g. London Marathon 2025", text: $editRaceName)
                        .font(.subheadline)
                        .foregroundStyle(primaryText)
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.purple.opacity(0.07)))
                }
                .padding(.horizontal, 24)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 10) {
                        ZStack {
                            Circle().fill(Color.purple.opacity(0.12)).frame(width: 48, height: 48)
                            Image(systemName: "figure.run")
                                .font(.title3.weight(.bold))
                                .foregroundStyle(Color.purple)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text(plan.name)
                                .font(.title2.weight(.bold))
                                .foregroundStyle(primaryText)
                            if let raceName = plan.targetRaceName, !raceName.isEmpty {
                                Label(raceName, systemImage: "flag.checkered")
                                    .font(.subheadline)
                                    .foregroundStyle(secondaryText)
                            }
                        }
                        Spacer()
                    }

                    HStack(spacing: 8) {
                        if let dist = plan.targetRaceDistance {
                            pill(dist.rawValue, color: .purple)
                        }
                        pill(plan.goalType.rawValue, color: .blue)
                        if plan.generationSource == .ai {
                            pill("AI Generated", color: .indigo)
                        }
                    }
                }
                .padding(.horizontal, 24)
            }
        }
    }

    // MARK: - Details

    private var detailsSection: some View {
        FrostedGlassContainer {
            VStack(alignment: .leading, spacing: 0) {
                sectionHeader("Plan Details", icon: "calendar")
                Divider().opacity(0.3).padding(.bottom, 8)

                detailRow(icon: "play.fill", label: "Start date",
                          value: plan.startDate.formatted(date: .abbreviated, time: .omitted),
                          color: .green)
                detailRow(icon: "checkered.flag", label: "End date",
                          value: endDate.formatted(date: .abbreviated, time: .omitted),
                          color: .red)
                detailRow(icon: "calendar.badge.clock", label: "Duration",
                          value: "\(plan.totalWeeks) weeks",
                          color: .purple)

                if let raceDate = plan.targetRaceDate {
                    Divider().opacity(0.2).padding(.vertical, 6)

                    if isEditing {
                        VStack(alignment: .leading, spacing: 6) {
                            Toggle(isOn: $editHasRaceDate) {
                                Label("Race date", systemImage: "flag.checkered")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(primaryText)
                            }
                            .tint(.purple)
                            if editHasRaceDate {
                                DatePicker("", selection: $editRaceDate, displayedComponents: .date)
                                    .datePickerStyle(.compact)
                                    .labelsHidden()
                                    .padding(.leading, 46)
                            }
                        }
                        .padding(.vertical, 4)
                    } else {
                        let daysLeft = Calendar.current.dateComponents([.day], from: today, to: raceDate).day ?? 0
                        detailRow(icon: "flag.checkered", label: "Race date",
                                  value: "\(raceDate.formatted(date: .abbreviated, time: .omitted)) · \(max(0, daysLeft)) days away",
                                  color: .orange)
                    }
                } else if isEditing {
                    Divider().opacity(0.2).padding(.vertical, 6)
                    Toggle(isOn: $editHasRaceDate) {
                        Label("Add race date", systemImage: "flag.checkered")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(primaryText)
                    }
                    .tint(.purple)
                    .padding(.vertical, 4)
                    if editHasRaceDate {
                        DatePicker("", selection: $editRaceDate, displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .labelsHidden()
                            .padding(.leading, 46)
                    }
                }

                if plan.targetRaceGoalTimeSeconds != nil || isEditing {
                    Divider().opacity(0.2).padding(.vertical, 6)
                    if isEditing {
                        VStack(alignment: .leading, spacing: 6) {
                            Toggle(isOn: $editHasGoalTime) {
                                Label("Goal time", systemImage: "clock.badge.checkmark")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(primaryText)
                            }
                            .tint(.purple)
                            if editHasGoalTime {
                                HStack(spacing: 0) {
                                    Picker("", selection: $editGoalHours) {
                                        ForEach(0..<24) { Text("\($0)h").tag($0) }
                                    }
                                    .pickerStyle(.wheel).frame(width: 80).clipped()
                                    Picker("", selection: $editGoalMinutes) {
                                        ForEach(0..<60) { Text("\($0)m").tag($0) }
                                    }
                                    .pickerStyle(.wheel).frame(width: 80).clipped()
                                    Picker("", selection: $editGoalSeconds) {
                                        ForEach(0..<60) { Text("\($0)s").tag($0) }
                                    }
                                    .pickerStyle(.wheel).frame(width: 80).clipped()
                                }
                                .frame(height: 120)
                            }
                        }
                        .padding(.vertical, 4)
                    } else if let secs = plan.targetRaceGoalTimeSeconds {
                        detailRow(icon: "clock.badge.checkmark", label: "Goal time",
                                  value: formatSeconds(secs), color: .purple)
                    }
                }
            }
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Stats

    private var statsSection: some View {
        FrostedGlassContainer {
            VStack(alignment: .leading, spacing: 0) {
                sectionHeader("Progress", icon: "chart.bar.fill")
                Divider().opacity(0.3).padding(.bottom, 8)

                HStack(spacing: 12) {
                    statBox(value: "\(done)", unit: "/\(runs.count)", label: "Sessions done", color: .green)
                    let displayKm = isImperial ? totalPlannedKm * 0.621371 : totalPlannedKm
                    statBox(value: String(format: "%.0f", displayKm), unit: unitLabel,
                            label: "Total planned", color: .purple)
                    let pct = runs.isEmpty ? 0 : Int(Double(done) / Double(runs.count) * 100)
                    statBox(value: "\(pct)%", unit: "", label: "Complete", color: pct >= 80 ? .green : pct >= 50 ? .orange : .purple)
                }

                if !runs.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        ProgressView(value: Double(done), total: Double(runs.count)).tint(.purple)
                        Text("\(done) of \(runs.count) sessions complete")
                            .font(.caption).foregroundStyle(tertiaryText)
                    }
                    .padding(.top, 12)
                }
            }
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundStyle(Color.purple)
            Text(title).font(.headline).foregroundStyle(primaryText)
        }
        .padding(.bottom, 10)
    }

    private func detailRow(icon: String, label: String, value: String, color: Color) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(color.opacity(0.12)).frame(width: 34, height: 34)
                Image(systemName: icon).font(.subheadline.weight(.semibold)).foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(label).font(.caption.weight(.semibold)).foregroundStyle(tertiaryText)
                Text(value).font(.subheadline.weight(.semibold)).foregroundStyle(primaryText)
            }
            Spacer()
        }
        .padding(.vertical, 5)
    }

    private func statBox(value: String, unit: String, label: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value).font(.title2.weight(.bold)).foregroundStyle(color)
                if !unit.isEmpty {
                    Text(unit).font(.caption.weight(.semibold)).foregroundStyle(color.opacity(0.7))
                }
            }
            Text(label).font(.caption).foregroundStyle(tertiaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(color.opacity(0.08)))
    }

    private func pill(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(Capsule().fill(color.opacity(0.1)))
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption2.weight(.bold))
            .foregroundStyle(tertiaryText)
            .padding(.bottom, 2)
    }

    private func formatSeconds(_ t: Int) -> String {
        let h = t / 3600; let m = (t % 3600) / 60; let s = t % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }

    // MARK: - Edit state

    private func loadEditState() {
        editName = plan.name
        editRaceName = plan.targetRaceName ?? ""
        editHasRaceDate = plan.targetRaceDate != nil
        editRaceDate = plan.targetRaceDate ?? Calendar.current.date(byAdding: .month, value: 3, to: Date()) ?? Date()
        editHasGoalTime = plan.targetRaceGoalTimeSeconds != nil
        let secs = plan.targetRaceGoalTimeSeconds ?? 0
        editGoalHours = secs / 3600
        editGoalMinutes = (secs % 3600) / 60
        editGoalSeconds = secs % 60
    }

    private func saveEdits() {
        let trimmedName = editName.trimmingCharacters(in: .whitespaces)
        if !trimmedName.isEmpty { plan.name = trimmedName }
        plan.targetRaceName = editRaceName.trimmingCharacters(in: .whitespaces).isEmpty ? nil : editRaceName.trimmingCharacters(in: .whitespaces)
        plan.targetRaceDate = editHasRaceDate ? editRaceDate : nil
        plan.targetRaceGoalTimeSeconds = editHasGoalTime
            ? (editGoalHours * 3600 + editGoalMinutes * 60 + editGoalSeconds)
            : nil
        plan.updatedAt = Date()
        try? modelContext.save()
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        isEditing = false
    }
}

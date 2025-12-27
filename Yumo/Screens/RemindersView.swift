// Screens/RemindersView.swift

import SwiftUI
import SwiftData
import Combine


struct RemindersView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var colorScheme

    // 1. State to hold user-scoped reminders
    @State private var reminders: [Reminder] = []

    @State private var isShowingCreateSheet = false

    // Background animation state
    @State private var offset1: CGSize = .zero
    @State private var offset2: CGSize = .zero

    // Adaptive colors for light/dark mode
    private var adaptiveTextColor: Color {
        colorScheme == .light ? Color(red: 0.1, green: 0.1, blue: 0.1) : .white
    }

    private var adaptiveSecondaryTextColor: Color {
        colorScheme == .light ? Color(red: 0.3, green: 0.3, blue: 0.3) : .white.opacity(0.7)
    }

    var body: some View {
        ZStack {
            _buildDynamicBackground()
            
            if reminders.isEmpty {
                // Placeholder if list is empty
                VStack(spacing: 16) {
                    Image(systemName: "bell.slash")
                        .font(.system(size: 50))
                        .foregroundStyle(adaptiveSecondaryTextColor)
                    Text("No reminders yet")
                        .font(.headline)
                        .foregroundStyle(adaptiveSecondaryTextColor)
                }
            } else {
                // 2. List all the reminders
                List {
                    ForEach(reminders) { reminder in
                        // @Bindable allows the toggle to directly save changes
                        @Bindable var reminder = reminder
                        
                        HStack {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(reminder.title)
                                    .font(.headline)
                                    .foregroundStyle(reminder.isEnabled ? adaptiveTextColor : .gray)
                                    .strikethrough(!reminder.isEnabled) // Cross out if disabled

                                // Detailed time row
                                HStack(spacing: 4) {
                                    Image(systemName: "clock")
                                        .font(.caption)
                                    Text("Daily at")
                                        .font(.caption)
                                    Text(reminder.time, style: .time)
                                        .font(.subheadline).bold()
                                }
                                .foregroundStyle(reminder.isEnabled ? Color("AppSecondaryAccent") : .gray.opacity(0.7))
                            }

                            Spacer()

                            Toggle("", isOn: $reminder.isEnabled)
                                .tint(Color("AppSecondaryAccent"))
                                .onChange(of: reminder.isEnabled) { _, isEnabled in
                                    // 3. Schedule or cancel when toggled
                                    if isEnabled {
                                        ReminderScheduler.scheduleReminder(reminder)
                                    } else {
                                        ReminderScheduler.cancelReminder(reminder)
                                    }
                                }
                        }
                        // ⭐️ FIX: Styling applied to CONTENT, not the row
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        
                        // ⭐️ FIX: Make the system row transparent
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16)) // Adds spacing between pills
                        
                        .swipeActions {
                            Button(role: .destructive) {
                                deleteReminder(reminder)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(.plain) // ⭐️ FIX: Use plain style to respect our custom spacing
                .scrollContentBackground(.hidden) // Make the list transparent
            }
        }
        .navigationTitle("Reminders")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isShowingCreateSheet = true
                } label: {
                    Image(systemName: "plus")
                        .font(.headline).bold()
                        .foregroundStyle(Color("AppSecondaryAccent"))
                }
            }
        }
        .sheet(isPresented: $isShowingCreateSheet, onDismiss: {
            Task { await refreshData() }
        }) {
            CreateReminderView()
        }
        .task {
            await refreshData()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task { await refreshData() }
            }
        }
    }

    // MARK: - Data Refresh

    private func refreshData() async {
        reminders = await UserScopedQuery.fetchReminders(context: modelContext)
    }

    private func deleteReminder(_ reminder: Reminder) {
        let reminderId = reminder.id.uuidString
        let userId = reminder.userId

        // 1. Cancel the notification
        ReminderScheduler.cancelReminder(reminder)
        // 2. Delete from database
        modelContext.delete(reminder)

        // 3. Delete from cloud if user is signed in
        if let userId = userId {
            Task {
                await CloudSyncManager.shared.deleteReminderFromCloud(reminderId: reminderId, userId: userId)
            }
        }

        // 4. Refresh data
        Task { await refreshData() }
    }
    
    // MARK: - Background Functions
    
    @ViewBuilder
    private func _buildDynamicBackground() -> some View {
        ZStack {
            Color("AppPrimaryDark", bundle: nil).ignoresSafeArea()
            if colorScheme == .light {
                RadialGradient(gradient: Gradient(colors: [Color("AppSecondaryAccent").opacity(0.3), .clear]), center: .topLeading, startRadius: 50, endRadius: 450)
                    .offset(offset1).offset(x: -150, y: -150).ignoresSafeArea()
                RadialGradient(gradient: Gradient(colors: [Color("AppPrimaryAccent").opacity(0.4), .clear]), center: .bottomTrailing, startRadius: 100, endRadius: 500)
                    .offset(offset2).offset(x: 100, y: 150).ignoresSafeArea()
            } else {
                RadialGradient(gradient: Gradient(colors: [Color.white.opacity(0.08), .clear]), center: .topLeading, startRadius: 50, endRadius: 500)
                    .offset(offset1).offset(x: -100, y: -100).ignoresSafeArea()
                RadialGradient(gradient: Gradient(colors: [Color.white.opacity(0.05), .clear]), center: .bottomTrailing, startRadius: 50, endRadius: 500)
                    .offset(offset2).offset(x: 100, y: 100).ignoresSafeArea()
            }
        }
        .blur(radius: 60)
        .onAppear { animateOrbs() }
    }
    
    private func animateOrbs() {
        withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
            offset1 = CGSize(width: 80, height: 60)
        }
        withAnimation(.easeInOut(duration: 10).repeatForever(autoreverses: true)) {
            offset2 = CGSize(width: -100, height: -70)
        }
    }
}

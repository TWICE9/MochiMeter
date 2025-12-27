// Screens/CreateReminderView.swift

import SwiftUI
import SwiftData

struct CreateReminderView: View {
    
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    // State for the form
    @State private var title: String = ""
    @State private var notes: String = ""
    @State private var time: Date = Date()
    
    // 1 = Sun, 7 = Sat. Default to all selected.
    @State private var selectedDays: Set<Int> = [1, 2, 3, 4, 5, 6, 7]
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color("AppPrimaryDark").ignoresSafeArea()
                _buildDynamicBackground()
                
                ScrollView {
                    VStack(spacing: 24) {
                        
                        // --- Title & Notes ---
                        FrostedGlassContainer {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Details")
                                    .font(.headline)
                                    .foregroundStyle(Color("AppTextPrimary").opacity(0.8))

                                TextField("Title (e.g. Take Creatine)", text: $title)
                                    .font(.title3)
                                    .padding()
                                    .background(Color("AppTextPrimary").opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .foregroundStyle(Color("AppTextPrimary"))

                                TextField("Notes (Optional)", text: $notes)
                                    .padding()
                                    .background(Color("AppTextPrimary").opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .foregroundStyle(Color("AppTextPrimary"))
                            }
                        }
                        
                        // --- Time Picker ---
                        FrostedGlassContainer {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Time")
                                    .font(.headline)
                                    .foregroundStyle(Color("AppTextPrimary").opacity(0.8))

                                DatePicker("", selection: $time, displayedComponents: .hourAndMinute)
                                    .datePickerStyle(.wheel)
                                    .labelsHidden()
                            }
                        }
                        
                        // --- Day Selector ---
                        FrostedGlassContainer {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("Repeat")
                                        .font(.headline)
                                        .foregroundStyle(Color("AppTextPrimary").opacity(0.8))
                                    Spacer()
                                    // Quick toggle for Every Day vs Weekdays
                                    if selectedDays.count == 7 {
                                        Text("Every Day").font(.caption).foregroundStyle(Color("AppTextPrimary").opacity(0.6))
                                    } else if selectedDays.isEmpty {
                                        Text("Never").font(.caption).foregroundStyle(Color("AppTextPrimary").opacity(0.6))
                                    }
                                }
                                
                                // 7 Day Buttons
                                HStack(spacing: 8) {
                                    ForEach(1...7, id: \.self) { day in
                                        DayButton(day: day, isSelected: selectedDays.contains(day)) {
                                            toggleDay(day)
                                        }
                                    }
                                }
                            }
                        }
                        
                        // --- Save Button ---
                        Button {
                            saveReminder()
                        } label: {
                            Text("Save Reminder")
                                .font(.headline).bold()
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(isValid ? Color("AppSecondaryAccent") : Color.gray.opacity(0.3))
                                .foregroundStyle(isValid ? .black : Color("AppTextPrimary").opacity(0.5))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .disabled(!isValid)
                        .padding(.top, 20)
                        
                        Spacer()
                    }
                    .padding(24)
                }
            }
            .dismissKeyboardOnTap()
            .navigationTitle("New Reminder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color("AppTextPrimary").opacity(0.8))
                }
            }
        }
    }
    
    private var isValid: Bool {
        !title.isEmpty && !selectedDays.isEmpty
    }
    
    private func toggleDay(_ day: Int) {
        if selectedDays.contains(day) {
            selectedDays.remove(day)
        } else {
            selectedDays.insert(day)
        }
    }
    
    private func saveReminder() {
        Task {
            let userId = await UserSession.shared.getCurrentUserId()

            // Convert Set to Array for storage
            let daysArray = Array(selectedDays).sorted()

            let newReminder = Reminder(
                title: title,
                notes: notes,
                time: time,
                weekdays: daysArray
            )
            newReminder.userId = userId

            modelContext.insert(newReminder)
            ReminderScheduler.scheduleReminder(newReminder)
            dismiss()
        }
    }
    
    // MARK: - Background
    @ViewBuilder
    private func _buildDynamicBackground() -> some View {
        ZStack {
            if colorScheme == .light {
                RadialGradient(gradient: Gradient(colors: [Color("AppSecondaryAccent").opacity(0.3), .clear]), center: .topLeading, startRadius: 50, endRadius: 450)
                    .offset(x: -150, y: -150).ignoresSafeArea()
                RadialGradient(gradient: Gradient(colors: [Color("AppPrimaryAccent").opacity(0.4), .clear]), center: .bottomTrailing, startRadius: 100, endRadius: 500)
                    .offset(x: 100, y: 150).ignoresSafeArea()
            } else {
                RadialGradient(gradient: Gradient(colors: [Color.white.opacity(0.08), .clear]), center: .topLeading, startRadius: 50, endRadius: 500)
                    .offset(x: -150, y: -150).ignoresSafeArea()
                RadialGradient(gradient: Gradient(colors: [Color.white.opacity(0.05), .clear]), center: .bottomTrailing, startRadius: 50, endRadius: 500)
                    .offset(x: 100, y: 150).ignoresSafeArea()
            }
        }
        .blur(radius: 60)
    }
}

// Helper View for the Day Circles
struct DayButton: View {
    let day: Int
    let isSelected: Bool
    let action: () -> Void
    
    var label: String {
        let formatter = DateFormatter()
        // DateFormatter indexes days starting at 0 or 1 depending on locale,
        // but usually weekdaySymbols are 0-indexed (0=Sun).
        // We passed 1...7. Let's map 1->Sun (index 0).
        return formatter.veryShortWeekdaySymbols[day - 1]
    }
    
    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.subheadline).bold()
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(isSelected ? Color("AppSecondaryAccent") : Color("AppTextPrimary").opacity(0.1))
                .foregroundStyle(isSelected ? .black : Color("AppTextPrimary"))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }
}

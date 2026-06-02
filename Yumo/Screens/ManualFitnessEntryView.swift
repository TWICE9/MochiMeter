// Screens/ManualFitnessEntryView.swift

import SwiftUI
import SwiftData
import Auth

struct ManualFitnessEntryView: View {
    
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var authManager: AuthManager
    
    @Query private var allFitnessLogs: [LoggedFitness]
    
    // State for the form
    @State private var selectedDate: Date = Date()
    @State private var stepsText: String = ""
    @State private var caloriesText: String = ""
    
    // Editing mode
    private var existingLog: LoggedFitness? {
        let startOfDay = Calendar.current.startOfDay(for: selectedDate)
        return allFitnessLogs.first(where: { Calendar.current.isDate($0.date, inSameDayAs: startOfDay) })
    }
    
    private var isEditing: Bool {
        existingLog != nil
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color("AppPrimaryDark").ignoresSafeArea()
                _buildDynamicBackground()
                
                ScrollView {
                    VStack(spacing: 24) {
                        
                        // Info Banner
                        FrostedGlassContainer {
                            HStack(spacing: 12) {
                                Image(systemName: "info.circle.fill")
                                    .foregroundStyle(Color("AppSecondaryAccent"))
                                    .font(.title2)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Manual Entry")
                                        .font(.headline)
                                        .foregroundStyle(Color("AppTextPrimary"))
                                    Text("Add fitness data from your other devices")
                                        .font(.caption)
                                        .foregroundStyle(Color("AppTextPrimary").opacity(0.7))
                                }
                                Spacer()
                            }
                        }
                        
                        // --- Date Picker ---
                        FrostedGlassContainer {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Date")
                                    .font(.headline)
                                    .foregroundStyle(Color("AppTextPrimary").opacity(0.8))
                                
                                DatePicker("", selection: $selectedDate, in: ...Date(), displayedComponents: .date)
                                    .datePickerStyle(.graphical)
                                    .labelsHidden()
                                    .onChange(of: selectedDate) { _, newDate in
                                        loadExistingData()
                                    }
                            }
                        }
                        
                        // --- Steps Input ---
                        FrostedGlassContainer {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Circle()
                                        .fill(Color(red: 0.63, green: 0.98, blue: 0.27))
                                        .frame(width: 10, height: 10)
                                    Text("Steps")
                                        .font(.headline)
                                        .foregroundStyle(Color("AppTextPrimary").opacity(0.8))
                                    Spacer()
                                    Text("Optional")
                                        .font(.caption)
                                        .foregroundStyle(Color("AppTextPrimary").opacity(0.5))
                                }
                                
                                TextField("Enter steps (e.g. 8000)", text: $stepsText)
                                    .keyboardType(.numberPad)
                                    .font(.title3)
                                    .padding()
                                    .background(Color("AppTextPrimary").opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .foregroundStyle(Color("AppTextPrimary"))
                            }
                        }
                        
                        // --- Calories Input ---
                        FrostedGlassContainer {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Circle()
                                        .fill(Color(red: 0.98, green: 0.24, blue: 0.45))
                                        .frame(width: 10, height: 10)
                                    Text("Calories Burned")
                                        .font(.headline)
                                        .foregroundStyle(Color("AppTextPrimary").opacity(0.8))
                                    Spacer()
                                    Text("Optional")
                                        .font(.caption)
                                        .foregroundStyle(Color("AppTextPrimary").opacity(0.5))
                                }
                                
                                TextField("Enter calories (e.g. 450)", text: $caloriesText)
                                    .keyboardType(.decimalPad)
                                    .font(.title3)
                                    .padding()
                                    .background(Color("AppTextPrimary").opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .foregroundStyle(Color("AppTextPrimary"))
                            }
                        }
                        
                        // --- Save/Update Button ---
                        Button {
                            saveFitnessLog()
                        } label: {
                            Text(isEditing ? "Update Entry" : "Save Entry")
                                .font(.headline).bold()
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(isValid ? Color("AppSecondaryAccent") : Color.gray.opacity(0.3))
                                .foregroundStyle(isValid ? .black : Color("AppTextPrimary").opacity(0.5))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .disabled(!isValid)
                        .padding(.top, 8)
                        
                        // --- Delete Button (if editing) ---
                        if isEditing {
                            Button {
                                deleteEntry()
                            } label: {
                                Text("Delete Entry")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.red.opacity(0.2))
                                    .foregroundStyle(.red)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                        }
                        
                        Spacer()
                    }
                    .padding(24)
                }
            }
            .dismissKeyboardOnTap()
            .navigationTitle("Manual Fitness")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color("AppTextPrimary").opacity(0.8))
                }
            }
            .onAppear {
                loadExistingData()
            }
        }
    }
    
    private var isValid: Bool {
        // At least one field must have a value
        let hasSteps = Int(stepsText) != nil && !stepsText.isEmpty
        let hasCalories = Double(caloriesText) != nil && !caloriesText.isEmpty
        return hasSteps || hasCalories
    }
    
    private func loadExistingData() {
        if let existing = existingLog {
            stepsText = existing.steps.map { String($0) } ?? ""
            caloriesText = existing.caloriesBurned.map { String(format: "%.0f", $0) } ?? ""
        } else {
            stepsText = ""
            caloriesText = ""
        }
    }
    
    private func saveFitnessLog() {
        Task {
            let userId = await UserSession.shared.getCurrentUserId()
            
            let steps = Int(stepsText)
            let calories = Double(caloriesText)
            
            if let existing = existingLog {
                // Update existing entry
                existing.steps = steps
                existing.caloriesBurned = calories
                
                // Upload to cloud
                if let userId = userId {
                    await CloudSyncManager.shared.uploadFitnessLogImmediately(existing, userId: userId)
                }
            } else {
                // Create new entry
                let newLog = LoggedFitness(
                    date: selectedDate,
                    steps: steps,
                    caloriesBurned: calories
                )
                newLog.userId = userId
                
                modelContext.insert(newLog)
                
                // Upload to cloud
                if let userId = userId {
                    await CloudSyncManager.shared.uploadFitnessLogImmediately(newLog, userId: userId)
                }
            }
            
            try? modelContext.save()
            
            await MainActor.run {
                dismiss()
            }
        }
    }
    
    private func deleteEntry() {
        Task {
            guard let existing = existingLog else { return }
            
            let userId = await UserSession.shared.getCurrentUserId()
            
            // Delete from cloud first
            if let userId = userId {
                await CloudSyncManager.shared.deleteFitnessLogFromCloud(
                    logId: existing.id.uuidString,
                    userId: userId
                )
            }
            
            // Delete locally
            await MainActor.run {
                modelContext.delete(existing)
                try? modelContext.save()
                dismiss()
            }
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

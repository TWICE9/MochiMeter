// Screens/EditFoodLogView.swift

import SwiftUI
import SwiftData

struct EditFoodLogView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @Bindable var log: LoggedFood

    @EnvironmentObject var themeManager: ThemeManager
    @State private var offset1: CGSize = .zero
    @State private var offset2: CGSize = .zero
    @State private var servingAmountText: String = ""
    @State private var showDatePicker: Bool = false

    // MARK: - Adaptive Colors (High Contrast for Light Mode)
    private var adaptiveTextColor: Color {
        colorScheme == .dark ? .white : .black
    }

    private var adaptiveSecondaryTextColor: Color {
        colorScheme == .dark ? .white.opacity(0.7) : Color(red: 60/255, green: 60/255, blue: 67/255)
    }

    private var backgroundColor: Color {
        colorScheme == .dark
            ? Color("AppPrimaryDark")
            : Color(red: 244 / 255, green: 245 / 255, blue: 247 / 255)
    }

    private var toolbarBackgroundColor: Color {
        colorScheme == .dark ? Color(red: 0.1, green: 0.1, blue: 0.1).opacity(0.95) : Color.white.opacity(0.95)
    }

    // ⭐️ FIX: Removed 'onDelete' property.
    // ⭐️ FIX: Removed 'showingDeleteConfirmation' state.

    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()
            _buildDynamicBackground()

            ScrollView {
                VStack(spacing: 24) {

                    // -- Name & Serving Card --
                    VStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Food Name")
                                .font(.headline)
                                .foregroundStyle(Color("AppTextPrimary").opacity(0.8))

                            TextField("Food Name", text: $log.name)
                                .padding()
                                .background(Color("AppTextPrimary").opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .foregroundStyle(Color("AppTextPrimary"))
                        }
                        
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Amount")
                                .font(.headline)
                                .foregroundStyle(Color("AppTextPrimary").opacity(0.8))

                            HStack(spacing: 12) {
                                TextField("Servings", text: $servingAmountText)
                                    .keyboardType(.decimalPad)
                                    .padding()
                                    .background(Color("AppTextPrimary").opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .foregroundStyle(Color("AppTextPrimary"))
                                
                                Text(log.servingSizeDescription)
                                    .font(.headline)
                                    .foregroundStyle(Color("AppTextPrimary"))
                            }
                        }
                    }
                    .padding()
                    .background(Color("AppTextPrimary").opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color("AppTextPrimary").opacity(0.1), lineWidth: 1)
                    )
                    .cornerRadius(20)

                    // -- Date & Time Card --
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Log Date & Time")
                            .font(.headline)
                            .foregroundStyle(Color("AppTextPrimary").opacity(0.8))

                        Button {
                            withAnimation(.easeInOut) {
                                showDatePicker.toggle()
                            }
                        } label: {
                            HStack {
                                Image(systemName: "calendar")
                                    .foregroundStyle(Color("AppSecondaryAccent"))
                                Text(log.timestamp, style: .date)
                                    .font(.body)
                                    .foregroundStyle(Color("AppTextPrimary"))
                                Text("•")
                                    .foregroundStyle(Color("AppTextPrimary").opacity(0.6))
                                Text(log.timestamp, style: .time)
                                    .font(.body)
                                    .foregroundStyle(Color("AppTextPrimary"))
                                Spacer()
                                Image(systemName: showDatePicker ? "chevron.up" : "chevron.down")
                                    .foregroundStyle(Color("AppTextPrimary").opacity(0.6))
                                    .font(.caption)
                            }
                            .padding()
                            .background(Color("AppTextPrimary").opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)

                        if showDatePicker {
                            DatePicker("", selection: $log.timestamp, displayedComponents: [.date, .hourAndMinute])
                                .datePickerStyle(.graphical)
                                .tint(Color("AppSecondaryAccent"))
                                .padding()
                                .background(Color("AppTextPrimary").opacity(0.05))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .padding()
                    .background(Color("AppTextPrimary").opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color("AppTextPrimary").opacity(0.1), lineWidth: 1)
                    )
                    .cornerRadius(20)

                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 60)
                .readableContentColumn(600)
            }
        }
        .onAppear {
            // Initialize the text field with the current serving amount
            let currentAmount = log.servingAmount
            if currentAmount == currentAmount.rounded() {
                servingAmountText = String(format: "%.0f", currentAmount)
            } else {
                servingAmountText = String(currentAmount)
            }
            animateOrbs()
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") {
                    if modelContext.hasChanges {
                        modelContext.rollback()
                    }
                    dismiss()
                }
                .foregroundStyle(adaptiveSecondaryTextColor)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") {
                    // Validate serving amount on save
                    if let parsed = Double(servingAmountText), parsed > 0 {
                        log.servingAmount = InputValidation.capServingAmount(parsed)
                    } else {
                        // Default to minimum if empty or invalid
                        log.servingAmount = 0.1
                    }

                    // Save locally
                    try? modelContext.save()

                    // Sync to cloud in background
                    let userId = log.userId
                    Task {
                        if let userId = userId {
                            await CloudSyncManager.shared.uploadFoodLogImmediately(log, userId: userId)
                            print("✅ Edited food log synced to cloud")
                        }
                    }

                    dismiss()
                }
                .font(.headline).bold()
                .foregroundStyle(Color("AppSecondaryAccent"))
            }
        }
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(toolbarBackgroundColor, for: .navigationBar)
    }

    // MARK: - Helper Views

    @ViewBuilder
    private func _buildDynamicBackground() -> some View {
        ZStack {
            // Orb 1: Primary Theme Color (Top Left)
            RadialGradient(
                gradient: Gradient(colors: [
                    colorScheme == .light 
                        ? themeManager.currentTheme.primaryColor.opacity(0.4) 
                        : themeManager.currentTheme.darkPrimaryColor.opacity(0.2),
                    .clear
                ]),
                center: .topLeading,
                startRadius: 50,
                endRadius: 450
            )
            .offset(offset1)
            .offset(x: -150, y: -150)
            .ignoresSafeArea()

            // Orb 2: Complementary Color (Bottom Right)
            RadialGradient(
                gradient: Gradient(colors: [
                    themeManager.currentTheme.complementaryColor.opacity(colorScheme == .light ? 0.35 : 0.2),
                    .clear
                ]),
                center: .bottomTrailing,
                startRadius: 100,
                endRadius: 500
            )
            .offset(offset2)
            .offset(x: 100, y: 150)
            .ignoresSafeArea()
        }
        .blur(radius: 60)
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

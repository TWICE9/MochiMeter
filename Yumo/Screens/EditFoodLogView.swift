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

    // MARK: - Adaptive Colors (High Contrast for Light Mode)
    private var adaptiveTextColor: Color {
        colorScheme == .dark ? .white : .black
    }

    private var adaptiveSecondaryTextColor: Color {
        colorScheme == .dark ? .white.opacity(0.7) : Color(red: 60/255, green: 60/255, blue: 67/255)
    }

    private var backgroundColor: Color {
        colorScheme == .dark ? Color("AppPrimaryDark") : .white
    }

    private var inputBackgroundColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.06)
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
                VStack(spacing: 20) {

                    // Hero-style header matching detail view
                    FrostedGlassContainer {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Edit Log")
                                .font(.title2).bold()
                                .foregroundStyle(adaptiveTextColor)

                            _simpleRow(title: "Name") {
                                TextField("Food Name", text: $log.name)
                                    .foregroundStyle(adaptiveTextColor)
                                    .padding(.vertical, 10)
                                    .padding(.horizontal, 12)
                                    .background(inputBackgroundColor)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }

                            _simpleRow(title: "Amount") {
                                HStack(spacing: 12) {
                                    TextField("Servings", value: $log.servingAmount, format: .number)
                                        .keyboardType(.decimalPad)
                                        .padding(.vertical, 10)
                                        .padding(.horizontal, 12)
                                        .background(inputBackgroundColor)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                        .foregroundStyle(adaptiveTextColor)
                                        .onChange(of: log.servingAmount) { _, newValue in
                                            log.servingAmount = InputValidation.capServingAmount(newValue)
                                        }
                                    Text(log.servingSizeDescription)
                                        .foregroundStyle(adaptiveSecondaryTextColor)
                                }
                            }

                            _simpleRow(title: "Date & Time") {
                                DatePicker("", selection: $log.timestamp, displayedComponents: [.date, .hourAndMinute])
                                    .datePickerStyle(.compact)
                                    .colorScheme(colorScheme)
                                    .labelsHidden()
                                    .tint(Color("AppSecondaryAccent"))
                                    .padding(.vertical, 6)
                            }
                        }
                    }
                    .padding(.horizontal)

                }
                .padding(.top, 40)
                .padding(.bottom, 60)
            }
        }
        .onAppear {
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
    private func _simpleRow<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .foregroundStyle(adaptiveSecondaryTextColor)
                .font(.subheadline)
            content()
        }
    }

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

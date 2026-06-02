//
//  FixAIResultSheet.swift
//  Yumo
//
//  Sheet for applying AI-powered corrections to food analysis results.
//

import SwiftUI

// MARK: - Fix AI Result Sheet

struct FixAIResultSheet: View {
    let current: FoodAnalysisResult
    @Binding var isFixing: Bool
    @Binding var errorMessage: String?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var correction: String = ""

    var onApply: (String, FoodAnalysisResult) -> Void

    @FocusState private var isTextEditorFocused: Bool

    // MARK: - Adaptive Colors (High Contrast for Light Mode)
    private var primaryTextColor: Color {
        colorScheme == .dark ? .white : .black
    }

    private var secondaryTextColor: Color {
        colorScheme == .dark ? .white.opacity(0.7) : Color(red: 60/255, green: 60/255, blue: 67/255)
    }

    private var backgroundColor: Color {
        colorScheme == .dark ? Color("AppPrimaryDark") : .white
    }

    private var inputBackgroundColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.06)
    }

    @State private var offset1: CGSize = .zero
    @State private var offset2: CGSize = .zero
    @State private var showHelp = false
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        NavigationStack {
            ZStack {
                _buildDynamicBackground()
                
                ScrollView {
                    VStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Improve Result")
                                    .font(.title3.bold())
                                    .foregroundStyle(primaryTextColor)
                                
                                Spacer()
                                
                                Button {
                                    showHelp = true
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "questionmark.circle")
                                        Text("Help")
                                    }
                                    .font(.subheadline)
                                    .foregroundStyle(Color("AppSecondaryAccent"))
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .onTapGesture {
                            isTextEditorFocused = false
                        }

                        TextField("Describe what needs to be fixed...", text: $correction, axis: .vertical)
                            .lineLimit(1...5)
                            .padding(16)
                            .background(inputBackgroundColor)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .foregroundStyle(primaryTextColor)
                            .focused($isTextEditorFocused)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(colorScheme == .dark ? .white.opacity(0.1) : .black.opacity(0.1), lineWidth: 1)
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                isTextEditorFocused = true
                            }

                        if let errorMessage {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                                Text(errorMessage)
                                    .foregroundStyle(.red)
                                    .font(.subheadline)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 4)
                        }

                        Button {
                            applyFix()
                        } label: {
                            Text("Apply Correction")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundStyle(colorScheme == .dark ? .black : .white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color("AppSecondaryAccent"))
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .shadow(color: Color("AppSecondaryAccent").opacity(0.3), radius: 8, y: 4)
                        }
                        .disabled(correction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .opacity(correction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.6 : 1.0)
                    }
                    .padding(24)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            // Background is now handled by ZStack + _buildDynamicBackground
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(secondaryTextColor)
                }
            }
            .onAppear {
                animateOrbs()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isTextEditorFocused = true
                }
            }
            .alert("How to fix results", isPresented: $showHelp) {
                Button("Got it", role: .cancel) { }
            } message: {
                Text("You can tell the AI to correct specific details. Examples:\n\n• \"It's actually Grilled Chicken\"\n• \"Portion is half\"\n• \"Remove the rice\"\n• \"Calories should be 500\"\n• \"Add a banana\"")
            }
        }
    }
    
    @ViewBuilder
    private func _buildDynamicBackground() -> some View {
        ZStack {
            backgroundColor.ignoresSafeArea()
            
            // Orb 1: Primary Theme Color (Top Left)
            RadialGradient(
                gradient: Gradient(colors: [
                    colorScheme == .dark ? themeManager.currentTheme.darkPrimaryColor.opacity(0.3) : themeManager.currentTheme.primaryColor.opacity(0.2),
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
                    themeManager.currentTheme.complementaryColor.opacity(colorScheme == .dark ? 0.25 : 0.2),
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

    private func applyFix() {
        let trimmed = correction.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Just pass the correction text, parent will handle the async processing
        onApply(trimmed, current)
        dismiss()
    }
    
    private func diffRow(title: String, current: String, updated: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
            HStack {
                Text(current)
                    .foregroundStyle(.white.opacity(0.7))
                Spacer()
                Image(systemName: "arrow.right")
                    .foregroundStyle(.white.opacity(0.4))
                Text(updated)
                    .foregroundStyle(.white)
            }
            .font(.subheadline)
        }
    }
    
    private func macroDiff(_ title: String, current: Double, updated: Double, suffix: String) -> some View {
        diffRow(title: title,
                current: "\(Int(current)) \(suffix)",
                updated: "\(Int(updated)) \(suffix)")
    }
}

//
//  AIFoodScanView.swift
//  Yumo
//
//  Example view showing how to use AI Food Scanner

import SwiftUI
import SwiftData
import PhotosUI

struct AIFoodScanView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var selectedImage: UIImage?
    @State private var selectedItem: PhotosPickerItem?
    @State private var isAnalyzing = false
    @State private var analysisResult: FoodAnalysisResult?
    @State private var errorMessage: String?
    @State private var showFixSheet = false
    @State private var isFixing = false
    @State private var fixError: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Color("AppPrimaryDark").ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {

                        // Image Preview
                        if let image = selectedImage {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(height: 300)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color("AppSecondaryAccent"), lineWidth: 2)
                                )
                        } else {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(.white.opacity(0.1))
                                .frame(height: 300)
                                .overlay(
                                    VStack(spacing: 12) {
                                        Image(systemName: "photo.on.rectangle")
                                            .font(.system(size: 60))
                                            .foregroundColor(.white.opacity(0.5))
                                        Text("Select a food photo")
                                            .foregroundColor(.white.opacity(0.7))
                                    }
                                )
                        }

                        // Photo Picker
                        PhotosPicker(
                            selection: $selectedItem,
                            matching: .images
                        ) {
                            Label("Choose Photo", systemImage: "photo.on.rectangle.angled")
                                .font(.headline)
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(Color("AppSecondaryAccent"))
                                .cornerRadius(16)
                        }
                        .onChange(of: selectedItem) { _, newItem in
                            Task {
                                if let data = try? await newItem?.loadTransferable(type: Data.self),
                                   let image = UIImage(data: data) {
                                    selectedImage = image
                                    errorMessage = nil
                                }
                            }
                        }

                        // Analyze Button
                        if selectedImage != nil {
                            Button {
                                analyzeFood()
                            } label: {
                                HStack {
                                    if isAnalyzing {
                                        ProgressView()
                                            .tint(.black)
                                        Text("Analyzing...")
                                    } else {
                                        Image(systemName: "sparkles")
                                        Text("Analyze with AI")
                                    }
                                }
                                .font(.headline)
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(Color("AppPrimaryAccent"))
                                .cornerRadius(16)
                            }
                            .disabled(isAnalyzing)
                        }

                        // Error Message
                        if let error = errorMessage {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                Text(error)
                            }
                            .font(.subheadline)
                            .foregroundColor(.red)
                            .padding()
                            .background(.red.opacity(0.1))
                            .cornerRadius(12)
                        }

                        // Results
                        if let result = analysisResult {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Analysis Results")
                                    .font(.title2).bold()
                                    .foregroundColor(.white)

                                VStack(alignment: .leading, spacing: 12) {
                                    ResultRow(label: "Food", value: result.name)
                                    ResultRow(label: "Serving Size", value: result.servingSize)
                                    ResultRow(label: "Calories", value: "\(Int(result.calories)) cal")
                                    ResultRow(label: "Protein", value: "\(Int(result.protein))g")
                                    ResultRow(label: "Carbs", value: "\(Int(result.carbs))g")
                                    ResultRow(label: "Fat", value: "\(Int(result.fat))g")
                                    ResultRow(label: "Fiber", value: "\(Int(result.fiber))g")

                                    if let confidence = result.confidence {
                                        HStack {
                                            Text("Confidence:")
                                                .foregroundColor(.white.opacity(0.7))
                                            Text(confidence.capitalized)
                                                .foregroundColor(
                                                    confidence == "high" ? .green :
                                                    confidence == "medium" ? .orange : .yellow
                                                )
                                                .fontWeight(.semibold)
                                        }
                                        .font(.subheadline)
                                    }
                                }
                                .padding()
                                .background(.white.opacity(0.1))
                                .cornerRadius(12)

                                // Save Button
                                Button {
                                    showFixSheet = true
                                } label: {
                                    Label("Fix with AI", systemImage: "wand.and.stars")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 52)
                                        .background(Color.white.opacity(0.12))
                                        .cornerRadius(16)
                                }

                                Button {
                                    saveFood(result)
                                } label: {
                                    Label("Save to Food Log", systemImage: "checkmark.circle.fill")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 56)
                                        .background(.green)
                                        .cornerRadius(16)
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("AI Food Scanner")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("🔵 AIFoodScanView (Photo Picker)")
                        .font(.headline)
                        .foregroundColor(.cyan)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.white)
                }
            }
            .sheet(isPresented: $showFixSheet) {
                if let result = analysisResult {
                    FixAIResultSheet(
                        current: result,
                        isFixing: $isFixing,
                        errorMessage: $fixError,
                        onApply: { _, fixed in
                            analysisResult = fixed
                        }
                    )
                } else {
                    Color.clear
                }
            }
        }
    }

    // MARK: - Actions
    private func analyzeFood() {
        guard let image = selectedImage else { return }

        isAnalyzing = true
        errorMessage = nil
        analysisResult = nil

        Task {
            do {
                let result = try await AIFoodScanner.shared.analyzeFood(image: image)
                await MainActor.run {
                    analysisResult = result
                    isAnalyzing = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isAnalyzing = false
                }
            }
        }
    }

    private func saveFood(_ result: FoodAnalysisResult) {
        let food = result.toLoggedFood()
        modelContext.insert(food)
        try? modelContext.save()
        
        // Request review after first food log
        ReviewRequestManager.shared.checkAndRequestReview()

        dismiss()
    }
}

// MARK: - Result Row Component
struct ResultRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.white.opacity(0.7))
            Spacer()
            Text(value)
                .foregroundColor(.white)
                .fontWeight(.semibold)
        }
        .font(.subheadline)
    }
}

#Preview {
    AIFoodScanView()
        .preferredColorScheme(.dark)
}

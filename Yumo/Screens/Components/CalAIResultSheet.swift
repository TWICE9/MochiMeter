//
//  CalAIResultSheet.swift
//  Yumo
//
//  Bottom sheet displaying AI food analysis results with editable macros.
//

import SwiftUI

// MARK: - Cal AI Result Sheet

struct CalAIResultSheet: View {
    @Binding var result: FoodAnalysisResult
    let onSave: (Double, Double, Double, Double, Double) -> Void  // servingAmount, calories, carbs, protein, fat
    let onRetry: () -> Void

    @State private var servingAmount: Double = 1.0
    @State private var showServingInput: Bool = false
    @State private var servingInputText: String = ""

    // Editable macro values
    @State private var editableCalories: Double
    @State private var editableCarbs: Double
    @State private var editableProtein: Double
    @State private var editableFat: Double

    // Edit dialog state
    @State private var showEditDialog = false
    @State private var editingMacro: MacroType?
    @State private var editValue: String = ""
    
    // Fix with AI state
    @State private var showFixSheet = false
    @State private var fixText: String = ""
    @State private var isFixing = false
    @State private var fixError: String?

    init(result: Binding<FoodAnalysisResult>, onSave: @escaping (Double, Double, Double, Double, Double) -> Void, onRetry: @escaping () -> Void) {
        self._result = result
        self.onSave = onSave
        self.onRetry = onRetry

        // Initialize editable values
        _editableCalories = State(initialValue: result.wrappedValue.calories)
        _editableCarbs = State(initialValue: result.wrappedValue.carbs)
        _editableProtein = State(initialValue: result.wrappedValue.protein)
        _editableFat = State(initialValue: result.wrappedValue.fat)
    }

    enum MacroType {
        case calories, carbs, protein, fat

        var title: String {
            switch self {
            case .calories: return "Calories"
            case .carbs: return "Carbs"
            case .protein: return "Protein"
            case .fat: return "Fat"
            }
        }

        var unit: String {
            switch self {
            case .calories: return ""
            case .carbs, .protein, .fat: return "g"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Meta Row (Timestamp & Share)
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.6))
                    Text(Date().formatted(date: .omitted, time: .shortened))
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.6))
                }

                Spacer()

                Button {
                    // Share action
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 18))
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)

            // Title Row (Food Name & Quantity Stepper)
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(result.name)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    Text(result.servingSize)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))

                    // AI Confidence Badge
                    if let confidence = result.confidence {
                        HStack(spacing: 4) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 10))
                                .foregroundColor(Color("AppSecondaryAccent"))
                            Text("AI Confidence: \(confidence)")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                    }
                }

                Spacer()

                // Quantity Stepper
                HStack(spacing: 0) {
                    Button {
                        if servingAmount > 0.5 {
                            servingAmount -= 0.5
                        }
                    } label: {
                        Image(systemName: "minus")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 32, height: 32)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }

                    Button {
                        servingInputText = servingAmount.truncatingRemainder(dividingBy: 1) == 0
                            ? String(format: "%.0f", servingAmount)
                            : String(format: "%.1f", servingAmount)
                        showServingInput = true
                    } label: {
                        Text("\(servingAmount, specifier: "%.1f")")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(minWidth: 40)
                            .padding(.vertical, 4)
                            .padding(.horizontal, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)

                    Button {
                        servingAmount += 0.5
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 32, height: 32)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)

            // Quick-select serving chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach([0.25, 0.5, 1.0, 1.5, 2.0], id: \.self) { amount in
                        Button {
                            servingAmount = amount
                        } label: {
                            Text(amount.truncatingRemainder(dividingBy: 1) == 0
                                 ? String(format: "%.0f", amount)
                                 : String(format: "%.1f", amount))
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(servingAmount == amount ? .black : .white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(
                                    Capsule()
                                        .fill(servingAmount == amount
                                              ? Color.white.opacity(0.9)
                                              : Color.white.opacity(0.1))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.bottom, 20)

            // 2x2 Macro Grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                // Calories
                MacroGridCard(
                    icon: "flame.fill",
                    iconColor: .orange,
                    backgroundColor: Color.orange.opacity(0.15),
                    label: "Calories",
                    value: Int(editableCalories * servingAmount),
                    unit: "",
                    onEdit: {
                        startEditing(.calories)
                    }
                )

                // Carbs
                MacroGridCard(
                    icon: "leaf.fill",
                    iconColor: Color(red: 0.85, green: 0.65, blue: 0.4),
                    backgroundColor: Color(red: 0.95, green: 0.9, blue: 0.8),
                    label: "Carbs",
                    value: Int(editableCarbs * servingAmount),
                    unit: "g",
                    onEdit: {
                        startEditing(.carbs)
                    }
                )

                // Protein
                MacroGridCard(
                    icon: "fork.knife",
                    iconColor: Color(red: 0.9, green: 0.3, blue: 0.4),
                    backgroundColor: Color(red: 1.0, green: 0.9, blue: 0.9),
                    label: "Protein",
                    value: Int(editableProtein * servingAmount),
                    unit: "g",
                    onEdit: {
                        startEditing(.protein)
                    }
                )

                // Fat
                MacroGridCard(
                    icon: "drop.fill",
                    iconColor: Color(red: 0.3, green: 0.7, blue: 0.6),
                    backgroundColor: Color(red: 0.85, green: 0.95, blue: 0.93),
                    label: "Fat",
                    value: Int(editableFat * servingAmount),
                    unit: "g",
                    onEdit: {
                        startEditing(.fat)
                    }
                )
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)

            if let ingredients = result.ingredients, !ingredients.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Ingredients (AI Detected)")
                        .font(.headline)
                        .foregroundColor(.white)
                    Text(ingredients.joined(separator: ", "))
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
                .cornerRadius(16)
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }

            // Footer Buttons
            HStack(spacing: 12) {
                // Fix Results Button
                Button {
                    showFixSheet = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Fix with AI")
                            .font(.headline)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.white.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 26)
                            .stroke(Color.white.opacity(0.3), lineWidth: 1.5)
                    )
                    .cornerRadius(26)
                }

                // Save Button
                Button {
                    onSave(servingAmount, editableCalories, editableCarbs, editableProtein, editableFat)
                } label: {
                    Text("Save")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color("AppPrimaryAccent"))
                        .cornerRadius(26)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 30)
        }
        .frame(maxWidth: .infinity)
        .background(Color("AppPrimaryDark"))
        .clipShape(RoundedRectangle(cornerRadius: 30))
        .shadow(color: .black.opacity(0.3), radius: 20, y: -10)
        .alert("Servings", isPresented: $showServingInput, actions: {
            TextField("Amount", text: $servingInputText)
                .keyboardType(.decimalPad)

            Button("Cancel", role: .cancel) { }

            Button("Done") {
                if let value = Double(servingInputText), value > 0 {
                    servingAmount = InputValidation.capServingAmount(value)
                }
            }
        }, message: {
            Text("Enter serving amount")
        })
        .alert(editingMacro?.title ?? "Edit", isPresented: $showEditDialog, actions: {
            TextField("Value", text: $editValue)
                .keyboardType(.decimalPad)

            Button("Cancel", role: .cancel) {
                editValue = ""
                editingMacro = nil
            }

            Button("Save") {
                saveEditedValue()
            }
        }, message: {
            Text("Enter new value for \(editingMacro?.title ?? "") \(editingMacro?.unit ?? "")")
        })
        .sheet(isPresented: $showFixSheet) {
            FixAIResultSheet(
                current: result,
                isFixing: $isFixing,
                errorMessage: $fixError,
                onApply: { correction, fixed in
                    fixText = correction
                    result = fixed
                    servingAmount = 1.0
                    editableCalories = fixed.calories
                    editableProtein = fixed.protein
                    editableCarbs = fixed.carbs
                    editableFat = fixed.fat
                }
            )
        }
    }

    // MARK: - Edit Functions

    private func startEditing(_ macro: MacroType) {
        editingMacro = macro

        // Set current value divided by serving amount (base value)
        let currentValue: Double
        switch macro {
        case .calories:
            currentValue = editableCalories
        case .carbs:
            currentValue = editableCarbs
        case .protein:
            currentValue = editableProtein
        case .fat:
            currentValue = editableFat
        }

        editValue = String(format: "%.0f", currentValue)
        showEditDialog = true
    }

    private func saveEditedValue() {
        guard let macro = editingMacro,
              let newValue = Double(editValue) else {
            return
        }

        // Update the appropriate value (base value, not multiplied by serving)
        switch macro {
        case .calories:
            editableCalories = newValue
        case .carbs:
            editableCarbs = newValue
        case .protein:
            editableProtein = newValue
        case .fat:
            editableFat = newValue
        }

        editValue = ""
        editingMacro = nil
    }
}

// MARK: - Macro Grid Card Component

struct MacroGridCard: View {
    let icon: String
    let iconColor: Color
    let backgroundColor: Color
    let label: String
    let value: Int
    let unit: String
    let onEdit: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let textColor = colorScheme == .dark ? Color.white : Color("AppTextPrimary")
        let subtitleColor = textColor.opacity(0.6)
        let cardBackground = colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.04)
        let strokeColor = colorScheme == .dark ? Color.white.opacity(0.15) : Color.black.opacity(0.05)

        HStack(spacing: 12) {
            // Icon Circle
            ZStack {
                Circle()
                    .fill(backgroundColor)
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(iconColor)
            }

            // Label & Value
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundColor(subtitleColor)

                Text("\(value)\(unit)")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(textColor)
            }

            Spacer()

            // Edit Icon
            Button {
                onEdit()
            } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 14))
                    .foregroundColor(subtitleColor)
            }
        }
        .padding(12)
        .background(cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(strokeColor, lineWidth: 1)
        )
        .cornerRadius(16)
    }
}

// MARK: - Nutrient Row Component

struct NutrientRow: View {
    let label: String
    let value: Double
    let unit: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.white.opacity(0.8))
            Spacer()
            Text("\(value, specifier: "%.1f") \(unit)")
                .font(.headline)
                .foregroundStyle(.white)
        }
    }
}

// MARK: - Compact Macro View Component

struct CompactMacroView: View {
    let label: String
    let value: Int
    let unit: String

    var body: some View {
        VStack(spacing: 6) {
            Text("\(value)\(unit)")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.white)
            Text(label)
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.white.opacity(0.1))
        .cornerRadius(10)
    }
}

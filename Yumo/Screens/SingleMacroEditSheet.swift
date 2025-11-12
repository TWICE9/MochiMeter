import SwiftUI
import SwiftData

struct SingleMacroEditSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Bindable var log: LoggedFood
    let macro: MacroType
    let goals: UserGoals
    var onClose: () -> Void

    @State private var value: Double

    init(log: LoggedFood, macro: MacroType, goals: UserGoals, onClose: @escaping () -> Void) {
        self.log = log
        self.macro = macro
        self.goals = goals
        self.onClose = onClose
        switch macro {
        case .calories:
            _value = State(initialValue: log.caloriesPerServing)
        case .carbs:
            _value = State(initialValue: log.carbsPerServing)
        case .protein:
            _value = State(initialValue: log.proteinPerServing)
        case .fat:
            _value = State(initialValue: log.fatPerServing)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundColor.ignoresSafeArea()
                VStack(spacing: 20) {
                    Text("Edit \(macro.title)")
                        .font(.largeTitle).bold()
                        .foregroundStyle(primaryTextColor)

                    VStack(spacing: 16) {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(iconColor.opacity(colorScheme == .dark ? 0.2 : 0.15))
                                    .frame(width: 48, height: 48)
                                Image(systemName: iconName)
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(iconColor)
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                Text(macro.title)
                                    .font(.headline)
                                    .foregroundStyle(primaryTextColor)
                                Text("Per serving")
                                    .font(.caption)
                                    .foregroundStyle(secondaryTextColor)
                            }
                            Spacer()
                            Text("\(value, specifier: "%.1f")\(macro.unit)")
                                .font(.title3.bold())
                                .foregroundStyle(primaryTextColor)
                        }
                        .padding()
                        .background(cardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(cardBorderColor, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16))

                        VStack(alignment: .leading, spacing: 8) {
                            Text("\(macro.title) per serving")
                                .font(.headline)
                                .foregroundStyle(primaryTextColor.opacity(0.9))

                            HStack {
                                TextField("0", value: $value, format: .number)
                                    .keyboardType(.decimalPad)
                                    .font(.title.bold())
                                    .foregroundStyle(primaryTextColor)
                                    .onChange(of: value) { _, newValue in
                                        value = macro == .calories ? InputValidation.capCalories(newValue) : InputValidation.capMacro(newValue)
                                    }
                                Text(macro.unit)
                                    .foregroundStyle(secondaryTextColor)
                            }
                            .padding()
                            .background(cardBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(cardBorderColor, lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                    }
                    .padding(.horizontal, 20)

                    Spacer()

                    Button {
                        save()
                        onClose()
                    } label: {
                        Text("Save")
                            .font(.headline).bold()
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color("AppSecondaryAccent"))
                            .foregroundStyle(.black)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { onClose() }
                        .foregroundStyle(primaryTextColor)
                }
            }
        }
    }

    private func save() {
        switch macro {
        case .calories: log.caloriesPerServing = value
        case .carbs: log.carbsPerServing = value
        case .protein: log.proteinPerServing = value
        case .fat: log.fatPerServing = value
        }
        try? modelContext.save()

        // Sync to cloud in background
        let userId = log.userId
        Task {
            if let userId = userId {
                await CloudSyncManager.shared.uploadFoodLogImmediately(log, userId: userId)
                print("✅ Macro edit synced to cloud")
            }
        }
    }

    private var iconName: String {
        switch macro {
        case .calories: return "flame.fill"
        case .carbs: return "leaf.fill"
        case .protein: return "fork.knife"
        case .fat: return "drop.fill"
        }
    }

    private var iconColor: Color {
        switch macro {
        case .calories: return .orange
        case .carbs: return Color("AppSecondaryAccent")
        case .protein: return .pink
        case .fat: return .orange.opacity(0.8)
        }
    }

    private var backgroundColor: Color {
        colorScheme == .dark
            ? Color("AppPrimaryDark")
            : Color(red: 248/255, green: 248/255, blue: 250/255)
    }

    private var primaryTextColor: Color {
        colorScheme == .dark
            ? .white
            : Color(red: 32/255, green: 32/255, blue: 38/255)
    }

    private var secondaryTextColor: Color {
        colorScheme == .dark
            ? .white.opacity(0.7)
            : Color(red: 120/255, green: 120/255, blue: 128/255)
    }

    private var cardBackground: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.08)
            : Color.white
    }

    private var cardBorderColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.04)
            : Color.black.opacity(0.05)
    }
}

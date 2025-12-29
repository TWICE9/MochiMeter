import SwiftUI
import SwiftData
import WidgetKit

struct LogScannedFoodView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var tabRouter: TabRouter

    @State private var goals: UserGoals = UserGoals()

    let product: OFFProduct
    var onLogComplete: (() -> Void)? = nil

    @State private var servingAmount: Double = 1.0
    @State private var selectedDate: Date = Date()
    @State private var showDatePicker: Bool = false
    @State private var editableCalories: Double = 0
    @State private var editableProtein: Double = 0
    @State private var editableCarbs: Double = 0
    @State private var editableFat: Double = 0
    @State private var didInitializeMacros = false
    @State private var showEditDialog = false
    @State private var editingMacro: MacroType?
    @State private var editValue: String = ""
    @State private var isLogging = false  // Prevent multiple taps

    private var nutriments: OFFNutriments {
        product.nutriments ?? OFFNutriments.empty
    }
    
    private var servingDescription: String {
        product.servingSize ?? "1 serving"
    }
    
    // MARK: - Computed totals
    private var totalCalories: Double { editableCalories * servingAmount }
    private var totalProtein: Double { editableProtein * servingAmount }
    private var totalCarbs: Double { editableCarbs * servingAmount }
    private var totalFat: Double { editableFat * servingAmount }
    private var totalFiber: Double { nutriments.servingFiber * servingAmount }
    private var totalSugar: Double { nutriments.servingSugars * servingAmount }
    private var totalSalt: Double { nutriments.servingSalt * servingAmount }
    private var totalPotassium: Double { nutriments.servingPotassium * servingAmount }
    
    // Helper to get a non-empty display name for the food
    private var foodDisplayName: String {
        // Try product name first
        if let name = product.productName?.trimmingCharacters(in: .whitespacesAndNewlines),
           !name.isEmpty {
            return name
        }
        
        // Fallback to brand if product name is empty or nil
        if let brand = product.brands?.trimmingCharacters(in: .whitespacesAndNewlines),
           !brand.isEmpty {
            return brand
        }
        
        // Last resort fallback
        return "Scanned Item"
    }
    
    private var baseBackgroundColor: Color {
        colorScheme == .dark
            ? Color("AppPrimaryDark")
            : Color(red: 244 / 255, green: 245 / 255, blue: 247 / 255)
    }

    var body: some View {
        ZStack {
            baseBackgroundColor.ignoresSafeArea()
            _buildDynamicBackground()

            ScrollView {
                VStack(spacing: 0) {
                    _buildTopBar()

                    // Meta row
                    HStack {
                        HStack(spacing: 6) {
                            Image(systemName: "clock")
                                .font(.system(size: 14))
                                .foregroundColor(Color("AppTextPrimary").opacity(0.6))
                            Text(Date().formatted(date: .omitted, time: .shortened))
                                .font(.subheadline)
                                .foregroundColor(Color("AppTextPrimary").opacity(0.6))
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 16)

                    // Title + serving stepper
                    HStack(alignment: .center, spacing: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(foodDisplayName)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(Color("AppTextPrimary"))

                            // Only show brand if it's different from the title
                            if let brand = product.brands?.trimmingCharacters(in: .whitespacesAndNewlines),
                               !brand.isEmpty,
                               brand != foodDisplayName {
                                Text(brand)
                                    .font(.subheadline)
                                    .foregroundColor(Color("AppTextPrimary").opacity(0.7))
                            }

                            Text(servingDescription)
                                .font(.caption)
                                .foregroundColor(Color("AppTextPrimary").opacity(0.6))
                        }

                        Spacer()

                        HStack(spacing: 0) {
                            Button {
                                if servingAmount > 0.5 {
                                    servingAmount -= 0.5
                                }
                            } label: {
                                Image(systemName: "minus")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(Color("AppTextPrimary"))
                                    .frame(width: 32, height: 32)
                                    .background(Color("AppTextPrimary").opacity(0.1))
                                    .clipShape(Circle())
                            }

                            Text("\(servingAmount, specifier: "%.1f")")
                                .font(.headline)
                                .foregroundColor(Color("AppTextPrimary"))
                                .frame(minWidth: 40)

                            Button {
                                servingAmount = InputValidation.capServingAmount(servingAmount + 0.5)
                            } label: {
                                Image(systemName: "plus")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(Color("AppTextPrimary"))
                                    .frame(width: 32, height: 32)
                                    .background(Color("AppTextPrimary").opacity(0.1))
                                    .clipShape(Circle())
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)

                    // Macro grid
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        MacroGridCard(
                            icon: "flame.fill",
                            iconColor: .orange,
                            backgroundColor: Color.orange.opacity(0.15),
                            label: "Calories",
                            value: Int(editableCalories * servingAmount),
                            unit: "",
                            onEdit: { startEditing(.calories) }
                        )

                        MacroGridCard(
                            icon: "leaf.fill",
                            iconColor: Color(red: 0.85, green: 0.65, blue: 0.4),
                            backgroundColor: Color(red: 0.95, green: 0.9, blue: 0.8),
                            label: "Carbs",
                            value: Int(editableCarbs * servingAmount),
                            unit: "g",
                            onEdit: { startEditing(.carbs) }
                        )

                        MacroGridCard(
                            icon: "fork.knife",
                            iconColor: Color(red: 0.9, green: 0.3, blue: 0.4),
                            backgroundColor: Color(red: 1.0, green: 0.9, blue: 0.9),
                            label: "Protein",
                            value: Int(editableProtein * servingAmount),
                            unit: "g",
                            onEdit: { startEditing(.protein) }
                        )

                        MacroGridCard(
                            icon: "drop.fill",
                            iconColor: Color(red: 0.3, green: 0.7, blue: 0.6),
                            backgroundColor: Color(red: 0.85, green: 0.95, blue: 0.93),
                            label: "Fat",
                            value: Int(editableFat * servingAmount),
                            unit: "g",
                            onEdit: { startEditing(.fat) }
                        )
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)

                    // Nutrients
                    VStack(spacing: 8) {
                        _nutrientRow(label: "Fiber", value: totalFiber, unit: "g")
                        _nutrientRow(label: "Sugar", value: totalSugar, unit: "g")
                        _nutrientRow(label: "Salt", value: totalSalt, unit: "g")
                        _nutrientRow(label: "Potassium", value: totalPotassium, unit: "mg")
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color("AppTextPrimary").opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color("AppTextPrimary").opacity(0.1), lineWidth: 1)
                    )
                    .cornerRadius(20)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)

                    // Date picker card
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
                                Text(selectedDate, style: .date)
                                    .font(.body)
                                    .foregroundStyle(Color("AppTextPrimary"))
                                Text("•")
                                    .foregroundStyle(Color("AppTextPrimary").opacity(0.6))
                                Text(selectedDate, style: .time)
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
                            DatePicker("", selection: $selectedDate, displayedComponents: [.date, .hourAndMinute])
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
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)

                    // Log button
                    HStack(spacing: 12) {
                        Button {
                            logItem()
                        } label: {
                            Text(isLogging ? "Logging..." : "Log Item")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(isLogging ? Color("AppPrimaryAccent").opacity(0.5) : Color("AppPrimaryAccent"))
                                .cornerRadius(26)
                        }
                        .disabled(isLogging)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
        }
        .navigationBarHidden(true)
        .task {
            await refreshData()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task { await refreshData() }
            }
        }
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
    }

    // MARK: - Data Refresh

    private func refreshData() async {
        if let fetchedGoals = await UserScopedQuery.fetchUserGoals(context: modelContext) {
            goals = fetchedGoals
        }
        if !didInitializeMacros {
            editableCalories = nutriments.servingCalories
            editableProtein = nutriments.servingProtein
            editableCarbs = nutriments.servingCarbs
            editableFat = nutriments.servingFat
            didInitializeMacros = true
        }
    }

    
    // MARK: - Logging

    private func logItem() {
        // Prevent multiple taps
        guard !isLogging else { return }
        isLogging = true

        // Create the food log item synchronously
        let newItem = LoggedFood(
            name: foodDisplayName,
            timestamp: selectedDate,
            servingSizeDescription: servingDescription,
            servingAmount: servingAmount,
            caloriesPerServing: editableCalories,
            proteinPerServing: editableProtein,
            carbsPerServing: editableCarbs,
            fatPerServing: editableFat,
            fiberPerServing: nutriments.servingFiber,
            sugarPerServing: nutriments.servingSugars,
            saltPerServing: nutriments.servingSalt,
            potassiumPerServing: nutriments.servingPotassium,
            barcode: product.id,
            brand: product.brands,
            isHalal: product.isHalal
        )

        // Save locally immediately
        modelContext.insert(newItem)
        try? modelContext.save()

        // Reload widgets immediately
        WidgetCenter.shared.reloadAllTimelines()
        NotificationCenter.default.post(name: Notification.Name("FoodLogCreated"), object: nil)

        // Haptic feedback
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        
        // Track analytics
        AnalyticsManager.shared.trackFoodLogged(name: foodDisplayName, calories: totalCalories, source: .barcode)
        
        // Request review after first food log
        ReviewRequestManager.shared.checkAndRequestReview()

        // Dismiss immediately
        if let onLogComplete {
            onLogComplete()
        } else {
            tabRouter.selectedTab = .home
            tabRouter.homePath = NavigationPath()
            tabRouter.scrollHomeToTop()
            dismiss()
        }

        // Do all cloud operations in background (non-blocking)
        let barcode = product.id
        let name = foodDisplayName
        let brand = product.brands
        let calories = editableCalories
        let protein = editableProtein
        let carbs = editableCarbs
        let fat = editableFat
        let fiber = nutriments.servingFiber
        let sugar = nutriments.servingSugars
        let salt = nutriments.servingSalt
        let potassium = nutriments.servingPotassium
        let amount = servingAmount
        let context = modelContext

        Task.detached(priority: .background) {
            // Get userId
            let userId = await UserSession.shared.getCurrentUserId()

            // Upload food log to cloud
            if let userId = userId {
                await MainActor.run {
                    newItem.userId = userId
                }
                await CloudSyncManager.shared.uploadFoodLogImmediately(newItem, userId: userId)
            }

            // Check local DB for cached entry
            let hasLocalEntry = await MainActor.run {
                CloudFoodSyncManager.shared.findFoodInLocalDB(
                    barcode: barcode,
                    context: context
                ) != nil
            }

            if hasLocalEntry {
                print("📦 DB HIT — using cached entry, no API call needed.")
            } else {
                print("🌐 DB MISS — uploading + syncing...")

                // Upload scan to scan_history
                await CloudScanUploader.shared.uploadScan(
                    barcode: barcode,
                    name: name,
                    caloriesPerServing: calories,
                    proteinPerServing: protein,
                    carbsPerServing: carbs,
                    fatPerServing: fat,
                    fiberPerServing: fiber,
                    sugarPerServing: sugar,
                    saltPerServing: salt,
                    potassiumPerServing: potassium,
                    servingAmount: amount
                )

                // Upsert master_foods (increment scan_count)
                await CloudScanUploader.shared.incrementScanCount(
                    for: barcode,
                    name: name,
                    brand: brand,
                    caloriesPerServing: calories,
                    proteinPerServing: protein,
                    carbsPerServing: carbs,
                    fatPerServing: fat,
                    fiberPerServing: fiber,
                    sugarPerServing: sugar,
                    saltPerServing: salt,
                    potassiumPerServing: potassium,
                    servingAmount: amount
                )

                // Pull updated cloud → local
                let cloudRows = await CloudFoodSyncManager.shared.fetchFoodsFromCloud(deltaSince: nil)
                await CloudFoodSyncManager.shared.syncFoods(cloudRows, context: context)
            }
        }
    }
    
    @ViewBuilder
    private func _buildTopBar() -> some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.title2)
                    .foregroundColor(Color("AppTextPrimary"))
                    .frame(width: 44, height: 44)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }

            Spacer()
        }
        .padding(.top, 16)
        .padding(.leading, 12)
    }

    @ViewBuilder
    private func _buildHeroCard() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(foodDisplayName)
                        .font(.title2).bold()
                        .foregroundStyle(Color("AppTextPrimary"))
                    if let brand = product.brands?.trimmingCharacters(in: .whitespacesAndNewlines),
                       !brand.isEmpty,
                       brand != foodDisplayName {
                        Text(brand)
                            .font(.subheadline)
                            .foregroundStyle(Color("AppTextPrimary").opacity(0.7))
                    }
                    Text(servingDescription)
                        .font(.caption)
                        .foregroundStyle(Color("AppTextPrimary").opacity(0.7))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(Int(totalCalories))")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundStyle(Color("AppTextPrimary"))
                    Text("kcal")
                        .font(.headline)
                        .foregroundStyle(Color("AppSecondaryAccent"))
                }
            }

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
                        Text(selectedDate, style: .date)
                            .font(.body)
                            .foregroundStyle(Color("AppTextPrimary"))
                        Text("•")
                            .foregroundStyle(Color("AppTextPrimary").opacity(0.6))
                        Text(selectedDate, style: .time)
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
                    DatePicker("", selection: $selectedDate, displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(.graphical)
                        .tint(Color("AppSecondaryAccent"))
                        .padding()
                        .background(Color("AppTextPrimary").opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
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
    }

    @ViewBuilder
    private func _buildMacrosCard() -> some View {
        VStack(spacing: 16) {
            macroEditRow(title: "Calories", value: $editableCalories, unit: "kcal")
            macroEditRow(title: "Protein", value: $editableProtein, unit: "g")
            macroEditRow(title: "Carbs", value: $editableCarbs, unit: "g")
            macroEditRow(title: "Fat", value: $editableFat, unit: "g")

            Divider().background(Color("AppTextPrimary").opacity(0.15)).padding(.vertical, 4)

            VStack(spacing: 8) {
                _nutrientRow(label: "Fiber", value: totalFiber, unit: "g")
                _nutrientRow(label: "Sugar", value: totalSugar, unit: "g")
                _nutrientRow(label: "Salt", value: totalSalt, unit: "g")
                _nutrientRow(label: "Potassium", value: totalPotassium, unit: "mg")
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

    @ViewBuilder
    private func _buildActionsCard() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Serving amount (\(servingDescription))")
                .font(.headline)
                .foregroundStyle(Color("AppTextPrimary").opacity(0.8))

            HStack(spacing: 12) {
                Button {
                    withAnimation { servingAmount = max(0.1, servingAmount - 0.5) }
                } label: {
                    Image(systemName: "minus")
                        .font(.headline)
                        .frame(width: 44, height: 44)
                        .foregroundStyle(Color("AppTextPrimary"))
                        .background(Color("AppTextPrimary").opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Text("\(servingAmount, specifier: "%.1f")")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(Color("AppTextPrimary"))
                    .frame(maxWidth: .infinity)

                Button {
                    withAnimation { servingAmount += 0.5 }
                } label: {
                    Image(systemName: "plus")
                        .font(.headline)
                        .frame(width: 44, height: 44)
                        .foregroundStyle(Color("AppTextPrimary"))
                        .background(Color("AppTextPrimary").opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }

            Button {
                logItem()
            } label: {
                Text(isLogging ? "Logging..." : "Log Item")
                    .font(.headline).bold()
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(isLogging ? Color("AppSecondaryAccent").opacity(0.5) : Color("AppSecondaryAccent"))
                    .foregroundStyle(.black)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(isLogging)
        }
        .padding()
        .background(Color("AppTextPrimary").opacity(0.05))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color("AppTextPrimary").opacity(0.1), lineWidth: 1)
        )
        .cornerRadius(20)
    }

    private func _macroPill(title: String, value: Double, unit: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Text("\(value, specifier: "%.1f")\(unit)")
                .font(.title3).bold()
                .foregroundStyle(Color("AppTextPrimary"))
            Text(title.uppercased())
                .font(.caption2)
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color("AppTextPrimary").opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func _nutrientRow(label: String, value: Double, unit: String) -> some View {
        HStack {
            Text(label).foregroundStyle(Color("AppTextPrimary").opacity(0.8))
            Spacer()
            Text("\(value, specifier: "%.1f") \(unit)")
                .font(.headline)
                .foregroundStyle(Color("AppTextPrimary"))
        }
    }

    private func macroEditRow(title: String, value: Binding<Double>, unit: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(Color("AppTextPrimary"))
                Text("per serving")
                    .font(.caption)
                    .foregroundStyle(Color("AppTextPrimary").opacity(0.6))
            }
            Spacer()
            TextField("0", value: value, format: .number)
                .keyboardType(.decimalPad)
                .font(.title3.weight(.bold))
                .multilineTextAlignment(.trailing)
                .foregroundStyle(Color("AppTextPrimary"))
                .frame(width: 90)
                .padding(10)
                .background(Color("AppTextPrimary").opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .onChange(of: value.wrappedValue) { _, newValue in
                    value.wrappedValue = title == "Calories" ? InputValidation.capCalories(newValue) : InputValidation.capMacro(newValue)
                }
            Text(unit)
                .foregroundStyle(Color("AppTextPrimary").opacity(0.7))
                .font(.subheadline)
        }
    }

    
    // MARK: - UI Builders
    
    @ViewBuilder
    private func _buildHeader() -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(foodDisplayName)
                .font(.largeTitle).bold()
                .foregroundStyle(Color("AppTextPrimary"))
                .lineLimit(2)
                .minimumScaleFactor(0.8)

            if let brand = product.brands?.trimmingCharacters(in: .whitespacesAndNewlines),
               !brand.isEmpty,
               brand != foodDisplayName {
                Text(brand)
                    .font(.title3).fontWeight(.medium)
                    .foregroundStyle(Color("AppTextPrimary").opacity(0.6))
            }

            if product.isHalal {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color("AppTextPrimary"))
                    Text("Halal Certified")
                        .font(.callout).fontWeight(.medium)
                        .foregroundStyle(Color("AppTextPrimary"))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.green.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    
    // MARK: - Edit Helpers
    private func startEditing(_ macro: MacroType) {
        editingMacro = macro
        switch macro {
        case .calories: editValue = String(format: "%.0f", editableCalories)
        case .carbs: editValue = String(format: "%.1f", editableCarbs)
        case .protein: editValue = String(format: "%.1f", editableProtein)
        case .fat: editValue = String(format: "%.1f", editableFat)
        }
        showEditDialog = true
    }

    private func saveEditedValue() {
        guard let macro = editingMacro,
              let newValue = Double(editValue) else {
            showEditDialog = false
            editValue = ""
            editingMacro = nil
            return
        }

        switch macro {
        case .calories: editableCalories = InputValidation.capCalories(newValue)
        case .carbs: editableCarbs = InputValidation.capMacro(newValue)
        case .protein: editableProtein = InputValidation.capMacro(newValue)
        case .fat: editableFat = InputValidation.capMacro(newValue)
        }

        showEditDialog = false
        editValue = ""
        editingMacro = nil
    }

    @ViewBuilder
    private func _buildDynamicBackground() -> some View {
        let topGradientColor = colorScheme == .dark
            ? Color("AppSecondaryAccent").opacity(0.35)
            : Color("AppSecondaryAccent").opacity(0.2)
        let bottomGradientColor = colorScheme == .dark
            ? Color("AppPrimaryAccent").opacity(0.4)
            : Color("AppPrimaryAccent").opacity(0.25)

        ZStack {
            RadialGradient(
                gradient: Gradient(colors: [
                    topGradientColor,
                    .clear
                ]),
                center: .topLeading,
                startRadius: 50, endRadius: 450
            )
            .offset(x: -150, y: -150)

            RadialGradient(
                gradient: Gradient(colors: [
                    bottomGradientColor,
                    .clear
                ]),
                center: .bottomTrailing,
                startRadius: 100,
                endRadius: 500
            )
            .offset(x: 100, y: 150)
        }
        .blur(radius: 60)
        .ignoresSafeArea()
    }
}

extension LogScannedFoodView {
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
}

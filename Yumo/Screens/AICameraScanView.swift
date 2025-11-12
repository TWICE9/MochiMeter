//
//  AICameraScanView.swift
//  Yumo
//
//  Live camera view for AI food scanning with immediate analysis
//

import SwiftUI
import SwiftData
@preconcurrency import AVFoundation
import PhotosUI
import Combine
import Auth

struct AICameraScanView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authManager: AuthManager
    @EnvironmentObject private var tabRouter: TabRouter

    @StateObject private var camera = CameraManager()

    // AI Food Scanning
    @State private var capturedImage: UIImage?
    @State private var isAnalyzing = false
    @State private var analysisResult: FoodAnalysisResult?
    @State private var errorMessage: String?
    @State private var showPhotoPicker = false

    // Barcode Scanning
    @State private var detectedBarcode: String?
    @State private var isFetchingProduct = false
    @State private var barcodeProduct: OFFProduct?
    @State private var showBarcodeResult = false

    private let apiService = OpenFoodFactsService()
    @State private var selectedItem: PhotosPickerItem?
    @ObservedObject private var superwallManager = SuperwallManager.shared

    var body: some View {
        NavigationStack {
            ZStack {
                Color("AppPrimaryDark").ignoresSafeArea()

                if let image = capturedImage {
                    // Cal AI Style - Full screen image with bottom sheet
                    ZStack(alignment: .bottom) {
                        // Full-screen background image (keeps center, no push/offset to avoid jump)
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
                            .clipped()
                            .background(Color.black)
                            .ignoresSafeArea()

                        // Top navigation overlay
                        VStack {
                            HStack {
                                // Back button (glassmorphism)
                                Button {
                                    dismiss()
                                } label: {
                                    Image(systemName: "arrow.left")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundColor(.white)
                                        .frame(width: 44, height: 44)
                                        .background(.ultraThinMaterial)
                                        .clipShape(Circle())
                                }

                                Spacer()

                                // Menu button (glassmorphism) - optional
                                Button {
                                    // Menu action
                                } label: {
                                    Image(systemName: "ellipsis")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundColor(.white)
                                        .frame(width: 44, height: 44)
                                        .background(.ultraThinMaterial)
                                        .clipShape(Circle())
                                }
                            }
                            .padding(.horizontal)
                            .padding(.top, 60)
                            .padding(.bottom)
                            Spacer()
                        }

                        // Bottom Sheet Card
                        if isAnalyzing {
                            // Loading State with animated messages
                            FoodAnalysisLoadingView()
                                .frame(maxWidth: .infinity)
                                .frame(height: UIScreen.main.bounds.height * 0.5)
                                .background(Color("AppPrimaryDark"))
                                .clipShape(RoundedRectangle(cornerRadius: 30))
                                .shadow(color: .black.opacity(0.3), radius: 20, y: -10)

                        } else if let error = errorMessage {
                            // Error State
                            VStack(spacing: 20) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 50))
                                    .foregroundColor(.red)

                                Text(error)
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)

                                Button {
                                    analyzeFood(image: image)
                                } label: {
                                    Text("Try Again")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 50)
                                        .background(.black)
                                        .cornerRadius(25)
                                }
                                .padding(.horizontal, 30)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: UIScreen.main.bounds.height * 0.5)
                            .background(Color("AppPrimaryDark"))
                            .clipShape(RoundedRectangle(cornerRadius: 30))
                            .shadow(color: .black.opacity(0.3), radius: 20, y: -10)

                        } else if let result = analysisResult {
                        CalAIResultSheet(
                            result: Binding(
                                get: { result },
                                set: { newVal in
                                    analysisResult = newVal
                                }
                            ),
                            onSave: { servingAmount, calories, carbs, protein, fat in
                                saveFood(
                                    result: result,
                                    servingAmount: servingAmount,
                                    editedCalories: calories,
                                    editedCarbs: carbs,
                                        editedProtein: protein,
                                        editedFat: fat
                                    )
                                },
                                onRetry: {
                                    resetForNewScan()
                                }
                            )
                        }
                    }
                    .ignoresSafeArea()

                } else {
                    // Camera View - Initial capture screen
                    ZStack {
                        CameraPreview(camera: camera)
                            .ignoresSafeArea()

                        VStack {
                            // Top bar with close and photo library buttons
                            HStack {
                                Button {
                                    dismiss()
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.title2)
                                        .foregroundColor(.white)
                                        .frame(width: 44, height: 44)
                                        .background(.ultraThinMaterial)
                                        .clipShape(Circle())
                                }

                                Spacer()

                                PhotosPicker(
                                    selection: $selectedItem,
                                    matching: .images
                                ) {
                                    Image(systemName: "photo.on.rectangle")
                                        .font(.title2)
                                        .foregroundColor(.white)
                                        .frame(width: 44, height: 44)
                                        .background(.ultraThinMaterial)
                                        .clipShape(Circle())
                                }
                            }
                            .padding()

                            // Status indicator at top
                            VStack(spacing: 12) {
                                if isFetchingProduct {
                                    ProgressView()
                                        .tint(.white)
                                    Text("Looking up product...")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                } else {
                                    HStack(spacing: 8) {
                                        Image(systemName: "barcode.viewfinder")
                                            .font(.system(size: 20))
                                        Text("Scanning for barcodes...")
                                    }
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                }
                            }
                            .padding(.horizontal, 24)
                            .padding(.vertical, 16)
                            .background(.ultraThinMaterial)
                            .cornerRadius(16)
                            .padding(.top, 20)

                            Spacer()

                            // Flash (left) and centered capture button
                            ZStack {
                                // Flash on the left
                                HStack {
                                    VStack(spacing: 8) {
                                        Button {
                                            camera.toggleFlash()
                                        } label: {
                                            ZStack {
                                                Circle()
                                                    .fill(.white.opacity(0.3))
                                                    .frame(width: 60, height: 60)

                                                Circle()
                                                    .fill(camera.isFlashOn ? .yellow : .white)
                                                    .frame(width: 50, height: 50)

                                                Image(systemName: camera.isFlashOn ? "bolt.fill" : "bolt.slash.fill")
                                                    .font(.title3)
                                                    .foregroundColor(.black)
                                            }
                                        }
                                        .buttonStyle(ScaleButtonStyle())
                                    }
                                    Spacer()
                                }
                                .padding(.horizontal, 32)

                                // Centered AI scan button + label
                                VStack(spacing: 12) {
                                    Button {
                                        if superwallManager.isPremium {
                                            capturePhoto()
                                        } else {
                                            superwallManager.showPaywall()
                                        }
                                    } label: {
                                        ZStack {
                                            Circle()
                                                .fill(.white.opacity(0.3))
                                                .frame(width: 80, height: 80)

                                            Circle()
                                                .fill(.white)
                                                .frame(width: 65, height: 65)

                                            Image(systemName: "sparkles")
                                                .font(.title2)
                                                .foregroundColor(.black)
                                        }
                                    }
                                    .buttonStyle(ScaleButtonStyle())

                                    Text("Tap to AI Scan")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(.ultraThinMaterial)
                                        .cornerRadius(12)
                                }
                            }
                            .padding(.bottom, 50)
                        }
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .onChange(of: selectedItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    if superwallManager.isPremium {
                        capturedImage = image
                        analyzeFoodWithPlaceholder(image: image)
                    } else {
                        await MainActor.run {
                            superwallManager.showPaywall()
                        }
                    }
                }
            }
        }
        .onAppear {
            camera.checkPermissions()

            // Setup barcode detection callback
            camera.onBarcodeDetected = { [self] barcode in
                handleBarcodeDetection(barcode)
            }
        }
        .onDisappear {
            camera.stop()
            camera.onBarcodeDetected = nil
        }
        // Show barcode product result sheet
        .sheet(isPresented: $showBarcodeResult, onDismiss: {
            // Reset barcode state when sheet is dismissed (even if not saved)
            detectedBarcode = nil
            barcodeProduct = nil
            isFetchingProduct = false
        }) {
            if let product = barcodeProduct {
                NavigationStack {
                    LogScannedFoodView(
                        product: product,
                        onLogComplete: {
                            showBarcodeResult = false
                            detectedBarcode = nil
                            barcodeProduct = nil

                            // Navigate to home
                            tabRouter.selectedTab = .home
                            tabRouter.homePath = NavigationPath()
                            tabRouter.scrollHomeToTop()

                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                dismiss()
                            }
                        }
                    )
                }
            }
        }
    }

    // MARK: - Actions

    private func capturePhoto() {
        // Immediate haptic feedback for responsive feel
        let haptic = UIImpactFeedbackGenerator(style: .medium)
        haptic.impactOccurred()

        camera.capturePhoto { image in
            guard let image = image else {
                errorMessage = "Failed to capture photo"
                return
            }

            analyzeFoodWithPlaceholder(image: image)
        }
    }

    private func analyzeFoodWithPlaceholder(image: UIImage) {
        Task {
            // Get userId
            let userId = await UserSession.shared.getCurrentUserId()

            // Create placeholder food item on MainActor and get its ID
            let placeholderFoodID = await MainActor.run { () -> PersistentIdentifier in
                let food = LoggedFood(
                    name: "Analyzing food...",
                    timestamp: Date(),
                    servingSizeDescription: "1 serving",
                    servingAmount: 1.0,
                    caloriesPerServing: 0,
                    proteinPerServing: 0,
                    carbsPerServing: 0,
                    fatPerServing: 0
                )
                food.userId = userId
                food.isAnalyzing = true

                // Add placeholder photo
                let resizedImage = image.resized(toMaxDimension: 1200)
                if let imageData = resizedImage.jpegData(compressionQuality: 0.65) {
                    food.photoData = imageData
                }

                modelContext.insert(food)
                try? modelContext.save()

                // Notify home screen to refresh
                NotificationCenter.default.post(name: Notification.Name("FoodLogCreated"), object: nil)

                return food.persistentModelID
            }

            // Navigate to home immediately
            await MainActor.run {
                tabRouter.selectedTab = .home
                tabRouter.homePath = NavigationPath()
                tabRouter.scrollHomeToTop()

                // Trigger home refresh to show placeholder
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    tabRouter.triggerHomeRefresh()
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    dismiss()
                }
            }

            // Analyze food in background
            do {
                let result = try await AIFoodScanner.shared.analyzeFood(image: image)

                // Update placeholder with real data
                await MainActor.run {
                    // Fetch the food using its persistent ID
                    if let placeholderFood = modelContext.model(for: placeholderFoodID) as? LoggedFood {
                        placeholderFood.name = result.name
                        placeholderFood.servingSizeDescription = result.servingSize
                        placeholderFood.caloriesPerServing = result.calories
                        placeholderFood.proteinPerServing = result.protein
                        placeholderFood.carbsPerServing = result.carbs
                        placeholderFood.fatPerServing = result.fat
                        placeholderFood.fiberPerServing = result.fiber
                        placeholderFood.sugarPerServing = result.sugar
                        placeholderFood.brand = "AI Analyzed"
                        placeholderFood.aiIngredients = result.ingredients
                        placeholderFood.aiConfidence = result.confidence
                        placeholderFood.isAnalyzing = false

                        try? modelContext.save()
                        NotificationCenter.default.post(name: Notification.Name("FoodLogCreated"), object: nil)

                        // Upload to cloud
                        if let userId = userId {
                            Task {
                                await CloudSyncManager.shared.uploadFoodLogImmediately(placeholderFood, userId: userId)

                            await CloudScanUploader.shared.incrementScanCount(
                                for: result.generateAIBarcode(),
                                name: result.name,
                                brand: "AI Analyzed",
                                caloriesPerServing: result.calories,
                                proteinPerServing: result.protein,
                                carbsPerServing: result.carbs,
                                fatPerServing: result.fat,
                                fiberPerServing: result.fiber,
                                sugarPerServing: result.sugar,
                                saltPerServing: 0,
                                potassiumPerServing: 0,
                                servingAmount: 1.0
                            )
                            }
                        }
                    }

                    // Haptic feedback
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
            } catch {
                // If analysis fails, mark as error
                await MainActor.run {
                    // Fetch the food using its persistent ID
                    if let placeholderFood = modelContext.model(for: placeholderFoodID) as? LoggedFood {
                        placeholderFood.name = "Analysis failed"
                        placeholderFood.isAnalyzing = false
                        try? modelContext.save()
                    }

                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                }
            }
        }
    }

    private func analyzeFood(image: UIImage) {
        isAnalyzing = true
        errorMessage = nil
        analysisResult = nil

        Task {
            do {
                let result = try await AIFoodScanner.shared.analyzeFood(image: image)
                await MainActor.run {
                    analysisResult = result
                    isAnalyzing = false

                    // Haptic feedback
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isAnalyzing = false

                    // Haptic feedback
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                }
            }
        }
    }

    private func saveFood(
        result: FoodAnalysisResult,
        servingAmount: Double,
        editedCalories: Double,
        editedCarbs: Double,
        editedProtein: Double,
        editedFat: Double
    ) {
        Task {
            // Get userId from UserSession (same source as queries use)
            let userId = await UserSession.shared.getCurrentUserId()

            print("🍎 AI Scanner: Starting save - userId: \(userId ?? "nil")")

            // Create and save food on MainActor
            await MainActor.run {
                // Create LoggedFood with edited values
                let food = LoggedFood(
                    name: result.name,
                    timestamp: Date(),
                    servingSizeDescription: result.servingSize,
                    servingAmount: servingAmount,
                    caloriesPerServing: editedCalories,
                    proteinPerServing: editedProtein,
                    carbsPerServing: editedCarbs,
                    fatPerServing: editedFat,
                    fiberPerServing: result.fiber,
                    sugarPerServing: result.sugar,
                    saltPerServing: 0,
                    potassiumPerServing: 0,
                    barcode: nil,
                    brand: "AI Analyzed",
                    isHalal: false,
                    photoData: nil,
                    aiIngredients: result.ingredients
                )
                if let resizedImage = capturedImage?.resized(toMaxDimension: 1200),
                   let imageData = resizedImage.jpegData(compressionQuality: 0.65) {
                    food.photoData = imageData
                }
                food.userId = userId

                print("🍎 AI Scanner: Saving food - \(food.name), \(food.totalCalories) cal")

                // Insert and save
                modelContext.insert(food)

                do {
                    try modelContext.save()
                    print("✅ AI Scanner: Food saved to SwiftData")
                    NotificationCenter.default.post(name: Notification.Name("FoodLogCreated"), object: nil)

                    // Upload to Supabase in background
                    if let userId = userId {
                        Task {
                            await CloudSyncManager.shared.uploadFoodLogImmediately(food, userId: userId)

                            // Also upload to master_foods for aggregation
                            await CloudScanUploader.shared.incrementScanCount(
                                for: result.generateAIBarcode(),
                                name: result.name,
                                brand: "AI Analyzed",
                                caloriesPerServing: editedCalories,
                                proteinPerServing: editedProtein,
                                carbsPerServing: editedCarbs,
                                fatPerServing: editedFat,
                                fiberPerServing: result.fiber,
                                sugarPerServing: result.sugar,
                                saltPerServing: 0,
                                potassiumPerServing: 0,
                                servingAmount: servingAmount
                            )
                        }
                    }
                } catch {
                    print("❌ AI Scanner: Save failed: \(error)")
                }

                // Haptic feedback
                UINotificationFeedbackGenerator().notificationOccurred(.success)

                // Navigate to home immediately after save
                print("🏠 AI Scanner: Switching to home tab")
                tabRouter.selectedTab = .home
                tabRouter.homePath = NavigationPath()
                tabRouter.scrollHomeToTop()

                // Trigger home refresh once it's visible, then dismiss quickly
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    tabRouter.triggerHomeRefresh()
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                    print("👋 AI Scanner: Dismissing")
                    dismiss()
                }
            }
        }
    }

    private func resetForNewScan() {
        capturedImage = nil
        analysisResult = nil
        errorMessage = nil
        camera.start()
    }

    // MARK: - Barcode Handling

    private func handleBarcodeDetection(_ barcode: String) {
        // Prevent duplicate scans
        guard detectedBarcode != barcode else { return }

        detectedBarcode = barcode
        isFetchingProduct = true

        print("📱 Barcode detected: \(barcode)")

        // Haptic feedback
        UINotificationFeedbackGenerator().notificationOccurred(.success)

        Task {
            do {
                let product = try await apiService.fetchFoodByBarcode(barcode)

                // Cache the product in SwiftData
                let cachedFood = CommonFood(
                    name: product.productName ?? "Unknown Product",
                    barcode: barcode,
                    caloriesPerServing: product.nutriments?.servingCalories ?? 0,
                    proteinPerServing: product.nutriments?.servingProtein ?? 0,
                    carbsPerServing: product.nutriments?.servingCarbs ?? 0,
                    fatPerServing: product.nutriments?.servingFat ?? 0,
                    fiberPerServing: product.nutriments?.servingFiber ?? 0,
                    sugarPerServing: product.nutriments?.servingSugars ?? 0,
                    saltPerServing: product.nutriments?.servingSalt ?? 0,
                    potassiumPerServing: product.nutriments?.servingPotassium ?? 0,
                    servingSizeDescription: product.servingSize ?? "1 serving",
                    isHalal: product.isHalal
                )

                modelContext.insert(cachedFood)

                await MainActor.run {
                    barcodeProduct = product
                    showBarcodeResult = true
                    isFetchingProduct = false
                }

            } catch {
                await MainActor.run {
                    errorMessage = "Product not found"
                    isFetchingProduct = false
                    detectedBarcode = nil
                }
            }
        }
    }
}

// MARK: - Food Analysis Loading View

struct FoodAnalysisLoadingView: View {
    @State private var currentMessageIndex = 0
    @State private var rotation: Double = 0

    let messages = [
        "Analyzing your food...",
        "Identifying ingredients...",
        "Calculating nutrition...",
        "Estimating portion size...",
        "Finalizing results..."
    ]

    var body: some View {
        VStack(spacing: 30) {
            Spacer()

            // Spinning loading ring
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                    .frame(width: 100, height: 100)

                Circle()
                    .trim(from: 0, to: 0.75)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color("AppPrimaryAccent"),
                                Color("AppSecondaryAccent")
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 100, height: 100)
                    .rotationEffect(.degrees(rotation))
                    .onAppear {
                        withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                            rotation = 360
                        }
                    }

                // Sparkles icon
                Image(systemName: "sparkles")
                    .font(.system(size: 32))
                    .foregroundColor(Color("AppSecondaryAccent"))
                    .scaleEffect(1.1)
                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: rotation)
            }

            // Animated message
            Text(messages[currentMessageIndex])
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                .id(currentMessageIndex)

            Text("AI is working its magic ✨")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))

            Spacer()
        }
        .onAppear {
            cycleMessages()
        }
    }

    private func cycleMessages() {
        // Slow the message cadence to ~1.5s per change
        Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { timer in
            withAnimation(.easeInOut(duration: 0.35)) {
                if currentMessageIndex < messages.count - 1 {
                    currentMessageIndex += 1
                } else {
                    timer.invalidate()
                }
            }
        }
    }
}

// MARK: - Cal AI Result Sheet

struct CalAIResultSheet: View {
    @Binding var result: FoodAnalysisResult
    let onSave: (Double, Double, Double, Double, Double) -> Void  // servingAmount, calories, carbs, protein, fat
    let onRetry: () -> Void

    @State private var servingAmount: Double = 1.0

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

                    Text("\(servingAmount, specifier: "%.1f")")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(minWidth: 40)

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

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Improve this result")
                            .font(.headline)
                            .foregroundStyle(primaryTextColor)
                        Text("Tell us what should be corrected. Examples: \"It's beef, not chicken\", \"Serving is 0.5\", \"Add rice 1 cup\", \"Calories seem high\".")
                            .font(.subheadline)
                            .foregroundStyle(secondaryTextColor)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .onTapGesture {
                        isTextEditorFocused = false
                    }

                    TextEditor(text: $correction)
                        .frame(height: 120)
                        .padding(10)
                        .background(inputBackgroundColor)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(primaryTextColor)
                        .scrollContentBackground(.hidden)
                        .focused($isTextEditorFocused)

                    if let errorMessage {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .onTapGesture {
                                isTextEditorFocused = false
                            }
                    }

                    Button {
                        applyFix()
                    } label: {
                        Text("Apply fix")
                            .fontWeight(.semibold)
                            .foregroundStyle(colorScheme == .dark ? .black : .white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color("AppSecondaryAccent"))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(correction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .padding(.bottom, 20)
                }
                .padding(20)
            }
            .scrollDismissesKeyboard(.immediately)
            .background(backgroundColor.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(secondaryTextColor)
                }
            }
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

// MARK: - Camera Manager

@MainActor
class CameraManager: NSObject, ObservableObject {
    @Published var isAuthorized = false
    @Published var session = AVCaptureSession()
    @Published var output = AVCapturePhotoOutput()
    @Published var preview: AVCaptureVideoPreviewLayer?
    @Published var isFlashOn = false

    // Barcode detection
    private var metadataOutput = AVCaptureMetadataOutput()
    var onBarcodeDetected: ((String) -> Void)?

    private var captureCompletion: ((UIImage?) -> Void)?
    private var currentDevice: AVCaptureDevice?

    override init() {
        super.init()
    }

    func checkPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            isAuthorized = true
            start()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.isAuthorized = granted
                    if granted {
                        self.start()
                    }
                }
            }
        default:
            isAuthorized = false
        }
    }

    func start() {
        guard !session.isRunning else { return }

        session.beginConfiguration()

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            return
        }

        // Store device reference for flash control
        currentDevice = device

        do {
            let input = try AVCaptureDeviceInput(device: device)

            if session.canAddInput(input) {
                session.addInput(input)
            }

            if session.canAddOutput(output) {
                session.addOutput(output)
            }

            // Add barcode detection
            if session.canAddOutput(metadataOutput) {
                session.addOutput(metadataOutput)

                // Set metadata types to detect barcodes
                metadataOutput.metadataObjectTypes = [
                    .ean8, .ean13, .upce, .code39, .code93, .code128,
                    .qr, .pdf417, .aztec, .dataMatrix
                ]

                // Set delegate on a background queue
                let metadataQueue = DispatchQueue(label: "com.yumo.barcode")
                metadataOutput.setMetadataObjectsDelegate(self, queue: metadataQueue)
            }

            session.sessionPreset = .photo
            session.commitConfiguration()

            let captureSession = session
            DispatchQueue.global(qos: .userInitiated).async {
                captureSession.startRunning()
            }

        } catch {
            print("Camera setup error: \(error)")
        }
    }

    func stop() {
        guard session.isRunning else { return }

        // Turn off flash if it's on
        if isFlashOn {
            toggleFlash()
        }

        let captureSession = session
        DispatchQueue.global(qos: .userInitiated).async {
            captureSession.stopRunning()
        }
    }

    func toggleFlash() {
        guard let device = currentDevice, device.hasTorch else { return }

        do {
            try device.lockForConfiguration()

            if isFlashOn {
                device.torchMode = .off
                isFlashOn = false
            } else {
                if device.isTorchModeSupported(.on) {
                    try device.setTorchModeOn(level: 1.0)
                    isFlashOn = true
                }
            }

            device.unlockForConfiguration()
        } catch {
            print("Flash toggle error: \(error)")
        }
    }

    func capturePhoto(completion: @escaping (UIImage?) -> Void) {
        captureCompletion = completion

        let settings = AVCapturePhotoSettings()
        output.capturePhoto(with: settings, delegate: self)
    }
}

extension CameraManager: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            Task { @MainActor in
                captureCompletion?(nil)
            }
            return
        }

        Task { @MainActor in
            captureCompletion?(image)
        }
    }
}

// MARK: - Barcode Detection Delegate

extension CameraManager: AVCaptureMetadataOutputObjectsDelegate {
    nonisolated func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard let metadataObject = metadataObjects.first,
              let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject,
              let stringValue = readableObject.stringValue else {
            return
        }

        // Call the barcode detection callback on main thread
        Task { @MainActor [weak self] in
            self?.onBarcodeDetected?(stringValue)
        }
    }
}

// MARK: - Camera Preview

struct CameraPreview: UIViewRepresentable {
    @ObservedObject var camera: CameraManager

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .black

        let previewLayer = AVCaptureVideoPreviewLayer(session: camera.session)
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)

        DispatchQueue.main.async {
            camera.preview = previewLayer
        }

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if let previewLayer = camera.preview {
            DispatchQueue.main.async {
                previewLayer.frame = uiView.bounds
            }
        }
    }
}

// MARK: - Button Styles

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.90 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

#Preview {
    AICameraScanView()
        .preferredColorScheme(.dark)
}

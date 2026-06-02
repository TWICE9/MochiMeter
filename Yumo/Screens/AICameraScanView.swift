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
    @ObservedObject private var storeKitManager = StoreKitManager.shared
    @ObservedObject private var usageLimitManager = UsageLimitManager.shared
    @State private var showPaywall = false
    @State private var showLimitReached = false
    
    @AppStorage("cameraScanHintDismissed") private var hintDismissed: Bool = false

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
                    // Unified camera view: barcode detection runs continuously in the
                    // background; tap shutter for an AI food scan. Whichever happens first
                    // wins, no mode switcher.
                    ZStack {
                        CameraPreview(camera: camera)
                            .ignoresSafeArea()

                        // Subtle barcode-scanning frame stays visible at all times so the
                        // user knows packaged products will auto-scan.
                        BarcodeScannerFrameOverlay()
                            .opacity(0.55)
                            .allowsHitTesting(false)

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

                            // Dismissible Instructions Banner — single unified message.
                            if !hintDismissed {
                                VStack(spacing: 0) {
                                    HStack(alignment: .top, spacing: 12) {
                                        Image(systemName: "sparkles")
                                            .font(.title2)
                                            .foregroundColor(.yellow)

                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Smart Scan")
                                                .font(.headline)
                                                .foregroundColor(.white)

                                            Text("Tap the shutter to AI-scan your food, or point at any barcode and it'll scan automatically.")
                                                .font(.caption)
                                                .foregroundColor(.white.opacity(0.8))
                                                .fixedSize(horizontal: false, vertical: true)
                                        }

                                        Spacer()

                                        Button {
                                            withAnimation(.easeOut(duration: 0.2)) {
                                                hintDismissed = true
                                            }
                                        } label: {
                                            Image(systemName: "xmark")
                                                .font(.caption.bold())
                                                .foregroundColor(.white.opacity(0.6))
                                                .frame(width: 24, height: 24)
                                                .background(Color.white.opacity(0.2))
                                                .clipShape(Circle())
                                        }
                                    }
                                    .padding(16)
                                    .background(.ultraThinMaterial)
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                }
                                .padding(.horizontal, 16)
                                .padding(.top, 8)
                                .transition(.move(edge: .top).combined(with: .opacity))
                            }

                            Spacer()

                            // Dynamic Hint Area — flips to the barcode lookup state when one is found.
                            Group {
                                if isFetchingProduct {
                                    HStack(spacing: 8) {
                                        ProgressView().tint(.white)
                                        Text("Looking up product…")
                                    }
                                } else {
                                    Text("Tap to scan food · or point at a barcode")
                                }
                            }
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial)
                            .cornerRadius(20)
                            .padding(.bottom, 10)
                            .animation(.easeInOut(duration: 0.2), value: isFetchingProduct)
                            .transition(.opacity)

                            // Bottom Controls Area — flash + single AI shutter button.
                            ZStack {
                                HStack {
                                    Button {
                                        camera.toggleFlash()
                                    } label: {
                                        ZStack {
                                            Circle()
                                                .fill(.ultraThinMaterial)
                                                .frame(width: 50, height: 50)

                                            Image(systemName: camera.isFlashOn ? "bolt.fill" : "bolt.slash.fill")
                                                .font(.body)
                                                .foregroundColor(.white)
                                        }
                                    }
                                    .buttonStyle(ScaleButtonStyle())
                                    Spacer()
                                }
                                .padding(.horizontal, 32)

                                Button {
                                    if storeKitManager.isPremium {
                                        capturePhoto()
                                    } else if usageLimitManager.canUseAIScan() {
                                        usageLimitManager.recordAIScan()
                                        capturePhoto()
                                    } else {
                                        showLimitReached = true
                                    }
                                } label: {
                                    ZStack {
                                        Circle()
                                            .strokeBorder(Color.white, lineWidth: 4)
                                            .frame(width: 84, height: 84)

                                        Circle()
                                            .fill(Color.white)
                                            .frame(width: 70, height: 70)

                                        Image(systemName: "sparkles")
                                            .font(.title2)
                                            .foregroundColor(.black)
                                    }
                                }
                                .buttonStyle(ScaleButtonStyle())
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
                    await MainActor.run {
                        if storeKitManager.isPremium {
                            capturedImage = image
                            analyzeFoodWithPlaceholder(image: image)
                        } else if usageLimitManager.canUseAIScan() {
                            usageLimitManager.recordAIScan()
                            capturedImage = image
                            analyzeFoodWithPlaceholder(image: image)
                        } else {
                            showLimitReached = true
                        }
                    }
                }
            }
        }
        .overlay {
            // Camera Tutorial Overlay — no mode switching anymore, both steps are
            // informational about the unified scanner.
            CameraTutorialOverlay { _ in }
        }
        .onAppear {
            print("🔍 AICameraScanView.onAppear | sessionRunning=\(camera.isSessionRunning)")
            
            // Setup barcode detection callback BEFORE starting the session
            // to avoid a race where barcodes are detected before the callback is wired
            camera.onBarcodeDetected = { [self] barcode in
                handleBarcodeDetection(barcode)
            }
            print("🔍 AICameraScanView: barcode callback wired")
            
            camera.checkPermissions()
            
            // Start camera tutorial for first-time users (with delay for camera to load)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                CameraTutorialManager.shared.startTutorial()
            }
        }
        .onDisappear {
            print("🔍 AICameraScanView.onDisappear")
            camera.stop()
            camera.onBarcodeDetected = nil
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(trigger: "ai_scan_limit")
        }
        .sheet(isPresented: $showLimitReached) {
            DailyLimitReachedView(feature: .aiScan) {
                showPaywall = true
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        // Show barcode product result sheet
        .sheet(isPresented: $showBarcodeResult, onDismiss: {
            // Reset barcode state when sheet is dismissed (even if not saved).
            // Use a short delay before clearing detectedBarcode so that any
            // in-flight metadata callbacks that just fired don't immediately
            // re-trigger a scan for the same barcode before the user has moved away.
            barcodeProduct = nil
            isFetchingProduct = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                detectedBarcode = nil
                camera.resetBarcodeCooldown()
            }
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
            
            // Generate a unique ID for this food item to track it
            let foodUUID = UUID()

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
                food.id = foodUUID  // Use our tracked UUID
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

            // Check if user is logged in - use background-safe approach if so
            if let userId = userId {
                // Background-safe approach: Upload to Supabase, fire and forget
                do {
                    let analysisId = try await PendingAnalysisManager.shared.submitForAnalysis(
                        image: image,
                        localFoodId: foodUUID.uuidString,
                        userId: userId
                    )
                    
                    print("🚀 Background analysis submitted: \(analysisId)")
                    
                    // Track analytics
                    await MainActor.run {
                        AnalyticsManager.shared.trackAIScanUsed(success: true, itemsDetected: 1)
                    }
                    
                    // The edge function will complete in background and write to pending_analyses
                    // Next time app opens, PendingAnalysisSync will update the local food
                    
                } catch {
                    print("⚠️ Background submission failed, falling back to immediate: \(error)")
                    // Fall back to immediate analysis if background submission fails
                    await analyzeImmediately(image: image, placeholderFoodID: placeholderFoodID, userId: userId)
                }
            } else {
                // Not logged in - use immediate analysis (old behavior)
                await analyzeImmediately(image: image, placeholderFoodID: placeholderFoodID, userId: nil)
            }
        }
    }
    
    /// Immediate analysis - used as fallback or for non-logged-in users
    private func analyzeImmediately(image: UIImage, placeholderFoodID: PersistentIdentifier, userId: String?) async {
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
                    placeholderFood.aiIngredientCalories = result.ingredientCaloriesDictionary()
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
                
                // Track analytics
                AnalyticsManager.shared.trackAIScanUsed(success: true, itemsDetected: 1)
                AnalyticsManager.shared.trackFoodLogged(name: result.name, calories: result.calories, source: .aiScan)
            }
        } catch {
            // If analysis fails, mark as error
            await MainActor.run {
                // Fetch the food using its persistent ID
                if let placeholderFood = modelContext.model(for: placeholderFoodID) as? LoggedFood {
                    placeholderFood.name = "Analysis failed"
                    placeholderFood.isAnalyzing = false
                    placeholderFood.isAnalysisFailed = true
                    try? modelContext.save()
                }

                UINotificationFeedbackGenerator().notificationOccurred(.error)
                
                // Track analytics
                AnalyticsManager.shared.trackAIScanUsed(success: false, itemsDetected: 0)
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
        print("🔍 handleBarcodeDetection() called | barcode='\(barcode)' | existingBarcode=\(detectedBarcode ?? "nil") | isFetching=\(isFetchingProduct)")

        // Prevent duplicate scans
        guard detectedBarcode != barcode else {
            print("🔍 ⏭ Skipped: same barcode already detected")
            return
        }

        // Don't fire while a product lookup is already in flight or a result sheet is open.
        guard !isFetchingProduct, !showBarcodeResult else {
            print("🔍 ⏭ Skipped: lookup already in progress / result open")
            return
        }

        // Turn off flash immediately if on
        if camera.isFlashOn {
            camera.toggleFlash()
        }

        detectedBarcode = barcode
        isFetchingProduct = true

        print("🔍 ✅ Barcode accepted, fetching product: \(barcode)")

        // Haptic feedback
        UINotificationFeedbackGenerator().notificationOccurred(.success)

        Task {
            do {
                let product = try await apiService.fetchFoodByBarcode(barcode)
                print("🔍 ✅ Product found: \(product.productName ?? "unknown")")

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
                print("🔍 ❌ Product fetch failed: \(error.localizedDescription)")
                await MainActor.run {
                    errorMessage = "Product not found"
                    isFetchingProduct = false
                    detectedBarcode = nil
                }
            }
        }
    }
}

#Preview {
    AICameraScanView()
        .preferredColorScheme(.dark)
}


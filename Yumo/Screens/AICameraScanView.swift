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
    
    // Camera Modes
    enum CameraMode: String {
        case aiScan
        case barcode
    }
    @AppStorage("lastCameraMode") private var cameraMode: CameraMode = .aiScan
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
                    // Camera View - Initial capture screen
                    ZStack {
                        CameraPreview(camera: camera)
                            .ignoresSafeArea()
                        
                        // Barcode Scanning Frame Overlay (only in barcode mode)
                        if cameraMode == .barcode {
                            BarcodeScannerFrameOverlay()
                                .transition(.opacity)
                                .animation(.easeInOut(duration: 0.3), value: cameraMode)
                        }

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

                            // Dismissible Instructions Banner
                            if !hintDismissed {
                                VStack(spacing: 0) {
                                    HStack(alignment: .top, spacing: 12) {
                                        Image(systemName: cameraMode == .aiScan ? "sparkles" : "barcode.viewfinder")
                                            .font(.title2)
                                            .foregroundColor(.yellow)
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(cameraMode == .aiScan ? "AI Food Scanner" : "Barcode Scanner")
                                                .font(.headline)
                                                .foregroundColor(.white)
                                            
                                            Text(cameraMode == .aiScan 
                                                ? "Point at your food and tap the shutter button. Works best with good lighting and a clear view of the dish."
                                                : "Point the camera at a product's barcode. It will scan automatically when detected.")
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
                                .animation(.easeInOut(duration: 0.25), value: cameraMode)
                            }



                            Spacer()

                            // Dynamic Hint Area
                            Group {
                                if cameraMode == .aiScan {
                                    Text("Take a photo of your food")
                                } else {
                                    if isFetchingProduct {
                                        HStack(spacing: 8) {
                                            ProgressView().tint(.white)
                                            Text("Looking up product...")
                                        }
                                    } else {
                                        Text("Scanning for barcodes...")
                                    }
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
                            .animation(.easeInOut(duration: 0.2), value: cameraMode)
                            .animation(.easeInOut(duration: 0.2), value: isFetchingProduct)
                            .transition(.opacity)
                            
                            // Bottom Controls Area
                            VStack(spacing: 20) {
                                // Mode Selector (Carousel Style)
                                ZStack {
                                    // Active Indicator
                                    Circle()
                                        .fill(Color.yellow) // High visibility indicator
                                        .frame(width: 6, height: 6)
                                        .offset(y: 16)

                                    // Sliding Text Strip
                                    HStack(spacing: 40) {
                                        Button { withAnimation { cameraMode = .aiScan } } label: {
                                            Text("AI SCAN")
                                                .font(.headline)
                                                .fontWeight(.bold)
                                                .foregroundColor(cameraMode == .aiScan ? .yellow : .white.opacity(0.5))
                                                .shadow(radius: 2)
                                        }
                                        .frame(width: 80) // Fixed width for precise centering

                                        Button { withAnimation { cameraMode = .barcode } } label: {
                                            Text("BARCODE")
                                                .font(.headline)
                                                .fontWeight(.bold)
                                                .foregroundColor(cameraMode == .barcode ? .yellow : .white.opacity(0.5))
                                                .shadow(radius: 2)
                                        }
                                        .frame(width: 90)
                                    }
                                    // Slide the strip to center the active item (Shift +/- 62)
                                    .offset(x: cameraMode == .aiScan ? 62 : -62)
                                    .animation(.spring(response: 0.35, dampingFraction: 0.75), value: cameraMode)
                                }
                                .frame(height: 40)
                                .frame(maxWidth: .infinity) // Allow full width so words aren't cut off
                                .contentShape(Rectangle()) // Capture taps/swipes in this area too
                                .gesture(
                                    DragGesture()
                                        .onEnded { value in
                                            if value.translation.width < -20 {
                                                withAnimation { cameraMode = .barcode }
                                            } else if value.translation.width > 20 {
                                                withAnimation { cameraMode = .aiScan }
                                            }
                                        }
                                )
                                .padding(.top, 10)
                                
                                // Flash (left) and Shutter (Center)
                                ZStack {
                                    // Flash on the left (Always visible)
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
                                    
                                    // Center Button Area (Stable Size)
                                    ZStack {
                                        if cameraMode == .aiScan {
                                            // AI Shutter Button
                                            Button {
                                                if superwallManager.isPremium {
                                                    capturePhoto()
                                                } else {
                                                    superwallManager.showPaywall()
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
                                            .transition(.opacity)
                                            
                                        } else {
                                            // Barcode Mode Visual (Same Size)
                                            ZStack {
                                                Circle()
                                                    .strokeBorder(Color.white.opacity(0.3), lineWidth: 4)
                                                    .frame(width: 84, height: 84)
                                                
                                                Circle() // Inner fill for tap target if needed, or just visual
                                                    .fill(Color.white.opacity(0.1))
                                                    .frame(width: 70, height: 70)
                                                
                                                Image(systemName: "barcode.viewfinder")
                                                    .font(.system(size: 32))
                                                    .foregroundColor(.white)
                                            }
                                            .transition(.opacity)
                                        }
                                    }
                                }
                            }
                            .padding(.bottom, 50)
                        }
                        .contentShape(Rectangle()) // Ensure swipes work on the entire screen
                        .gesture(
                            DragGesture()
                                .onEnded { value in
                                    if value.translation.width < -50 {
                                        // Swipe Left -> Barcode
                                        if cameraMode == .aiScan {
                                            withAnimation(.easeInOut(duration: 0.25)) { cameraMode = .barcode }
                                        }
                                    } else if value.translation.width > 50 {
                                        // Swipe Right -> AI Scan
                                        if cameraMode == .barcode {
                                            withAnimation(.easeInOut(duration: 0.25)) { cameraMode = .aiScan }
                                        }
                                    }
                                }
                        )
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
                        try? modelContext.save()
                    }

                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                    
                    // Track analytics
                    AnalyticsManager.shared.trackAIScanUsed(success: false, itemsDetected: 0)
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
        
        // Only run barcode logic if in Barcode Mode
        guard cameraMode == .barcode else { return }
        
        // Turn off flash immediately if on
        if camera.isFlashOn {
            camera.toggleFlash()
        }

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

// MARK: - Barcode Scanner Frame Overlay

struct BarcodeScannerFrameOverlay: View {
    @State private var isAnimating = false
    
    private let frameWidth: CGFloat = 280
    private let frameHeight: CGFloat = 140
    private let cornerLength: CGFloat = 30
    private let lineWidth: CGFloat = 4
    
    var body: some View {
        ZStack {
            // Dimmed background with cutout
            Color.black.opacity(0.4)
                .mask(
                    Rectangle()
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .frame(width: frameWidth, height: frameHeight)
                                .blendMode(.destinationOut)
                        )
                )
                .ignoresSafeArea()
            
            // Scanning Frame with animated line
            ZStack {
                // Animated scanning line
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.clear, .white.opacity(0.8), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: frameWidth - 20, height: 2)
                    .offset(y: isAnimating ? 50 : -50)
                    .animation(
                        .easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                        value: isAnimating
                    )
            }
            .frame(width: frameWidth, height: frameHeight)
        }
        .onAppear {
            isAnimating = true
        }
    }
}

// Corner brackets for the barcode scanner
struct BarcodeScannerCorners: View {
    let frameWidth: CGFloat
    let frameHeight: CGFloat
    let cornerLength: CGFloat
    let lineWidth: CGFloat
    
    var body: some View {
        ZStack {
            // Top-left corner
            CornerBracket(cornerLength: cornerLength, lineWidth: lineWidth)
                .position(x: lineWidth / 2, y: lineWidth / 2)
            
            // Top-right corner
            CornerBracket(cornerLength: cornerLength, lineWidth: lineWidth)
                .rotationEffect(.degrees(90))
                .position(x: frameWidth - lineWidth / 2, y: lineWidth / 2)
            
            // Bottom-left corner
            CornerBracket(cornerLength: cornerLength, lineWidth: lineWidth)
                .rotationEffect(.degrees(-90))
                .position(x: lineWidth / 2, y: frameHeight - lineWidth / 2)
            
            // Bottom-right corner
            CornerBracket(cornerLength: cornerLength, lineWidth: lineWidth)
                .rotationEffect(.degrees(180))
                .position(x: frameWidth - lineWidth / 2, y: frameHeight - lineWidth / 2)
        }
    }
}

// Individual corner bracket
struct CornerBracket: View {
    let cornerLength: CGFloat
    let lineWidth: CGFloat
    
    var body: some View {
        Path { path in
            // Horizontal line
            path.move(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: cornerLength, y: 0))
            
            // Vertical line
            path.move(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: 0, y: cornerLength))
        }
        .stroke(Color.white, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
    }
}

#Preview {
    AICameraScanView()
        .preferredColorScheme(.dark)
}

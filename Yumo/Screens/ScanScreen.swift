// Screens/ScanScreen.swift

import SwiftUI
import VisionKit
import SwiftData

struct ScanScreen: View {

    private let apiService: OpenFoodFactsService

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var tabRouter: TabRouter

    init() {
        self.apiService = OpenFoodFactsService()
    }

    @State private var isScanning = true
    @State private var scannedCode: String?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var foundProduct: OFFProduct?
    @State private var showLogSheet = false
    @State private var showAIScanner = false

    // Adaptive colors for light/dark mode
    private var adaptiveTextColor: Color {
        colorScheme == .light ? Color(red: 0.1, green: 0.1, blue: 0.1) : .white
    }

    var body: some View {
        ZStack {
            DataScannerViewWrapper(
                scannedCode: $scannedCode,
                isScanning: $isScanning
            )
            .ignoresSafeArea()

            VStack {
                // AI Scanner Button at top
                HStack {
                    Spacer()
                    Button {
                        showAIScanner = true
                        isScanning = false
                    } label: {
                        HStack {
                            Image(systemName: "sparkles")
                            Text("AI Scan")
                        }
                        .font(.headline)
                        .foregroundColor(.black)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color("AppSecondaryAccent"))
                        .cornerRadius(24)
                    }
                }
                .padding()

                Spacer()
                _buildStatusOverlay()
            }
            .padding(.bottom, 100)
        }

        .sheet(isPresented: $showAIScanner) {
            AIFoodScanView()
        }

        .onAppear {
            resetScanner()
        }
        .onDisappear {
            isScanning = false
        }

        // When barcode changes
        .task(id: scannedCode) {
            guard let code = scannedCode else { return }

            isScanning = false
            isLoading = true
            errorMessage = nil

            do {
                let product = try await fetchAndCacheProduct(by: code)

                UINotificationFeedbackGenerator().notificationOccurred(.success)

                foundProduct = product
                showLogSheet = true
                isLoading = false

            } catch let error as NetworkError {
                errorMessage = error.localizedDescription
                isLoading = false
            } catch {
                errorMessage = "An unexpected error occurred."
                isLoading = false
            }
        }

        // Don't auto-resume scanning when sheet closes
        .onChange(of: showLogSheet) { _, open in
            if !open {
                isScanning = false
            }
        }

        // Sheet with log view
        .sheet(isPresented: $showLogSheet) {
            resetScanner()
        } content: {
            if let foundProduct {
                NavigationStack {
                    LogScannedFoodView(
                        product: foundProduct,
                        onLogComplete: {
                            // Stop scanning, close sheet, then go home
                            isScanning = false
                            showLogSheet = false
                            tabRouter.homePath = NavigationPath()

                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                dismiss()
                            }
                        }
                    )
                }
            }
        }

        .navigationTitle("Scan Barcode")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Fetch / Cache Product

    private func fetchAndCacheProduct(by code: String) async throws -> OFFProduct {
        let product = try await apiService.fetchFoodByBarcode(code)

        // Cache it immediately in SwiftData
        let newCacheItem = CommonFood(
            name: product.productName ?? "Unknown Product",
            barcode: code,
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

        modelContext.insert(newCacheItem)
        return product
    }

    // MARK: - Status Overlay

    @ViewBuilder
    private func _buildStatusOverlay() -> some View {
        VStack(spacing: 12) {
            if isLoading {
                ProgressView()
                    .tint(adaptiveTextColor)
                Text("Fetching product...")
                    .font(.headline)
                    .foregroundStyle(adaptiveTextColor)
            } else if let errorMessage {
                Text(errorMessage)
                    .font(.headline)
                    .foregroundStyle(adaptiveTextColor)
                    .multilineTextAlignment(.center)
                Button {
                    resetScanner()
                } label: {
                    Text("Try Again")
                        .bold()
                        .padding(10)
                        .background(Color("AppSecondaryAccent"))
                        .foregroundStyle(.black)
                        .clipShape(Capsule())
                }
            } else if isScanning {
                Text("Searching for barcode...")
                    .font(.headline)
                    .foregroundStyle(adaptiveTextColor)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal, 30)
    }

    private func resetScanner() {
        scannedCode = nil
        foundProduct = nil
        errorMessage = nil
        isLoading = false
        isScanning = true
    }
}

// MARK: - VisionKit Data Scanner Wrapper

struct DataScannerViewWrapper: UIViewControllerRepresentable {
    @Binding var scannedCode: String?
    @Binding var isScanning: Bool

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.barcode()],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,  // Better single barcode tracking
            isHighFrameRateTrackingEnabled: true,  // Smoother highlighting
            isHighlightingEnabled: true  // Enable visual highlights
        )
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {
        if isScanning {
            try? uiViewController.startScanning()
        } else {
            uiViewController.stopScanning()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let parent: DataScannerViewWrapper

        init(parent: DataScannerViewWrapper) {
            self.parent = parent
        }

        // Handle manual tap on highlighted items
        func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem) {
            guard parent.isScanning else { return }

            switch item {
            case .barcode(let barcode):
                if let code = barcode.payloadStringValue {
                    parent.scannedCode = code
                    parent.isScanning = false
                }
            default:
                break
            }
        }

        // Auto-detect when barcode appears
        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            guard parent.isScanning else { return }

            for item in addedItems {
                switch item {
                case .barcode(let barcode):
                    if let code = barcode.payloadStringValue {
                        parent.scannedCode = code
                        parent.isScanning = false
                        return
                    }
                default:
                    break
                }
            }
        }
    }
}

//
//  CameraManager.swift
//  Yumo
//
//  Camera session management with AVFoundation for photo capture and barcode scanning.
//

import SwiftUI
import Combine
import os.log
@preconcurrency import AVFoundation

// MARK: - Logger

private let cameraLog = Logger(subsystem: "com.yumo.camera", category: "CameraManager")

// MARK: - Camera Manager

@MainActor
class CameraManager: NSObject, ObservableObject {
    nonisolated static let log = Logger(subsystem: "com.yumo.camera", category: "CameraManager")

    @Published var isAuthorized = false
    @Published var preview: AVCaptureVideoPreviewLayer?
    @Published var isFlashOn = false
    @Published var isSessionRunning = false

    // AVCaptureSession objects — marked nonisolated(unsafe) because they are
    // intentionally accessed from the dedicated sessionQueue (Apple's recommended
    // pattern for AVCaptureSession). The sessionQueue serialises all access.
    nonisolated(unsafe) var session = AVCaptureSession()
    nonisolated(unsafe) var output = AVCapturePhotoOutput()
    nonisolated(unsafe) private var metadataOutput = AVCaptureMetadataOutput()
    nonisolated(unsafe) private var isConfigured = false

    // Barcode detection
    var onBarcodeDetected: ((String) -> Void)?

    // Cooldown: track last delivered barcode + timestamp to prevent duplicate rapid-fire callbacks
    private var lastDeliveredBarcode: String?
    private var lastDeliveredTime: Date = .distantPast
    private let barcodeCooldown: TimeInterval = 2.5

    private var captureCompletion: ((UIImage?) -> Void)?
    private var currentDevice: AVCaptureDevice?

    // Device + in-flight flag used by the capture path on the sessionQueue.
    nonisolated(unsafe) private var captureDevice: AVCaptureDevice?
    nonisolated(unsafe) private var isCapturing = false

    /// Dedicated serial queue for ALL session operations (Apple's recommended pattern).
    private let sessionQueue = DispatchQueue(label: "com.yumo.camera.session", qos: .userInitiated)

    /// Dedicated queue for metadata delegate callbacks.
    private let metadataQueue = DispatchQueue(label: "com.yumo.barcode", qos: .userInteractive)

    private let instanceId = UUID().uuidString.prefix(6)

    override init() {
        super.init()
        cameraLog.info("[\(self.instanceId)] CameraManager.init()")
        setupObservers()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        let id = instanceId
        CameraManager.log.info("[\(id)] CameraManager.deinit")
    }

    // MARK: - Session Observers

    private func setupObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(sessionDidStartRunning), name: .AVCaptureSessionDidStartRunning, object: session)
        NotificationCenter.default.addObserver(self, selector: #selector(sessionDidStopRunning), name: .AVCaptureSessionDidStopRunning, object: session)
        NotificationCenter.default.addObserver(self, selector: #selector(sessionRuntimeError), name: .AVCaptureSessionRuntimeError, object: session)
        NotificationCenter.default.addObserver(self, selector: #selector(sessionWasInterrupted), name: .AVCaptureSessionWasInterrupted, object: session)
        NotificationCenter.default.addObserver(self, selector: #selector(sessionInterruptionEnded), name: .AVCaptureSessionInterruptionEnded, object: session)
    }

    @objc private func sessionDidStartRunning(notification: NSNotification) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.isSessionRunning = true
            let hasCallback = self.onBarcodeDetected != nil
            cameraLog.info("[\(self.instanceId)] ✅ Session STARTED | callbackWired=\(hasCallback)")
        }
    }

    @objc private func sessionDidStopRunning(notification: NSNotification) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.isSessionRunning = false
            cameraLog.info("[\(self.instanceId)] ⏹ Session STOPPED")
        }
    }

    @objc private func sessionRuntimeError(notification: NSNotification) {
        guard let error = notification.userInfo?[AVCaptureSessionErrorKey] as? AVError else { return }
        cameraLog.error("[\(self.instanceId)] ❌ Runtime error: \(error.localizedDescription) code=\(error.code.rawValue)")

        sessionQueue.async { [weak self] in
            guard let self else { return }
            if !self.session.isRunning {
                cameraLog.info("[\(self.instanceId)] 🔄 Restarting after error...")
                self.session.startRunning()
            }
        }
    }

    @objc private func sessionWasInterrupted(notification: NSNotification) {
        if let userInfoValue = notification.userInfo?[AVCaptureSessionInterruptionReasonKey] as AnyObject?,
           let reason = AVCaptureSession.InterruptionReason(rawValue: userInfoValue.intValue) {
            cameraLog.warning("[\(self.instanceId)] ⚠️ Session INTERRUPTED reason=\(reason.rawValue)")
        }
    }

    @objc private func sessionInterruptionEnded(notification: NSNotification) {
        cameraLog.info("[\(self.instanceId)] ℹ️ Interruption ended, restarting...")
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if !self.session.isRunning {
                self.session.startRunning()
            }
        }
    }

    // MARK: - Permissions

    func checkPermissions() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        cameraLog.info("[\(self.instanceId)] checkPermissions() status=\(status.rawValue)")

        switch status {
        case .authorized:
            isAuthorized = true
            start()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.isAuthorized = granted
                    if granted { self.start() }
                }
            }
        default:
            cameraLog.error("[\(self.instanceId)] ❌ Camera permission denied/restricted")
            isAuthorized = false
        }
    }

    // MARK: - Session Lifecycle

    func start() {
        cameraLog.info("[\(self.instanceId)] start() called | isConfigured=\(self.isConfigured)")

        sessionQueue.async { [weak self] in
            guard let self else { return }

            if !self.isConfigured {
                self.configureSession()
            }

            if !self.session.isRunning {
                cameraLog.info("[\(self.instanceId)] ▶️ startRunning()")
                self.session.startRunning()
            } else {
                cameraLog.info("[\(self.instanceId)] ℹ️ Session already running")
            }
        }
    }

    /// Configures inputs, outputs, and metadata in the correct order.
    /// Key fix: metadataObjectTypes is set AFTER commitConfiguration() so that
    /// availableMetadataObjectTypes is fully populated — this resolves the
    /// cold-launch barcode detection failure.
    /// Called from sessionQueue — must be nonisolated.
    nonisolated private func configureSession() {
        let id = instanceId
        let log = CameraManager.log
        log.info("[\(id)] 🔧 Configuring session...")

        session.beginConfiguration()

        // --- Input ---
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            log.error("[\(id)] ❌ No back camera found")
            session.commitConfiguration()
            return
        }

        captureDevice = device  // sessionQueue-owned reference used by the capture path
        Task { @MainActor [weak self] in
            self?.currentDevice = device
        }

        do {
            let input = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(input) {
                session.addInput(input)
            }
        } catch {
            log.error("[\(id)] ❌ Input error: \(error.localizedDescription)")
            session.commitConfiguration()
            return
        }

        // --- Photo Output ---
        if session.canAddOutput(output) {
            session.addOutput(output)
            // Let the photo pipeline use multi-frame fusion + OIS for the sharpest,
            // least-noisy result (the per-shot settings opt in below).
            output.maxPhotoQualityPrioritization = .quality
        }

        // --- Metadata Output (add to session graph, but do NOT set types yet) ---
        if session.canAddOutput(metadataOutput) {
            session.addOutput(metadataOutput)
        } else {
            log.error("[\(id)] ❌ Cannot add metadata output")
        }

        // --- Session Preset ---
        // Prefer the full still-photo pipeline (full-resolution, properly processed
        // captures) over the .high video preset, which only yields a soft 1080p frame.
        if session.canSetSessionPreset(.photo) {
            session.sessionPreset = .photo
        } else if session.canSetSessionPreset(.high) {
            session.sessionPreset = .high
        }

        // --- Device Optimizations ---
        do {
            try device.lockForConfiguration()
            if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
            }
            if device.isSmoothAutoFocusSupported {
                device.isSmoothAutoFocusEnabled = true
            }
            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
            }
            device.unlockForConfiguration()
        } catch {
            log.error("[\(id)] ❌ Device config error: \(error.localizedDescription)")
        }

        // --- Commit first, THEN configure metadata types ---
        session.commitConfiguration()

        // Now that the output is fully connected to the session graph,
        // availableMetadataObjectTypes is populated and we can safely set types.
        let desiredTypes: [AVMetadataObject.ObjectType] = [
            .ean8, .ean13, .upce, .code39, .code93, .code128,
            .qr, .pdf417, .aztec, .dataMatrix, .interleaved2of5, .itf14
        ]

        let available = Set(metadataOutput.availableMetadataObjectTypes)
        let supportedTypes = desiredTypes.filter { available.contains($0) }

        metadataOutput.metadataObjectTypes = supportedTypes
        metadataOutput.setMetadataObjectsDelegate(self, queue: metadataQueue)

        log.info("[\(id)] ✅ Metadata configured with \(supportedTypes.count) types (available: \(available.count))")

        // Enable video stabilization on the metadata connection if supported
        if let connection = metadataOutput.connection(with: .video) {
            if connection.isVideoStabilizationSupported {
                connection.preferredVideoStabilizationMode = .auto
            }
            log.info("[\(id)] ✅ Metadata connection active=\(connection.isActive)")
        }

        isConfigured = true
    }

    func stop() {
        cameraLog.info("[\(self.instanceId)] stop()")

        if isFlashOn {
            toggleFlash()
        }

        sessionQueue.async { [weak self] in
            guard let self else { return }
            if self.session.isRunning {
                self.session.stopRunning()
            }
        }
    }

    // MARK: - Flash

    func toggleFlash() {
        guard let device = currentDevice, device.hasTorch else { return }

        do {
            try device.lockForConfiguration()
            if isFlashOn {
                device.torchMode = .off
                isFlashOn = false
            } else if device.isTorchModeSupported(.on) {
                try device.setTorchModeOn(level: 1.0)
                isFlashOn = true
            }
            device.unlockForConfiguration()
        } catch {
            cameraLog.error("Flash toggle error: \(error.localizedDescription)")
        }
    }

    // MARK: - Photo Capture

    /// Captures a still photo. Before firing the shutter we run a one-shot autofocus +
    /// auto-exposure at the centre and wait (briefly) for the lens to stop hunting, then
    /// capture at full photo quality. This mirrors how the system Camera app locks focus
    /// before a shot and is what removes the occasional blurry frame.
    func capturePhoto(completion: @escaping (UIImage?) -> Void) {
        captureCompletion = completion
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if self.isCapturing { return }  // ignore taps while a capture is already in flight
            self.isCapturing = true
            self.focusThenCapture()
        }
    }

    /// Triggers a one-shot focus/exposure pass, then captures once it settles. (sessionQueue)
    nonisolated private func focusThenCapture() {
        guard let device = captureDevice else { captureNow(); return }
        do {
            try device.lockForConfiguration()
            let centre = CGPoint(x: 0.5, y: 0.5)
            if device.isFocusPointOfInterestSupported { device.focusPointOfInterest = centre }
            if device.isFocusModeSupported(.autoFocus) { device.focusMode = .autoFocus }
            if device.isExposurePointOfInterestSupported { device.exposurePointOfInterest = centre }
            if device.isExposureModeSupported(.autoExpose) { device.exposureMode = .autoExpose }
            device.unlockForConfiguration()
        } catch {
            captureNow()
            return
        }
        // Give AF/AE a moment to engage, then wait until the lens stops hunting (max ~0.65s).
        sessionQueue.asyncAfter(deadline: .now() + 0.12) { [weak self] in
            self?.waitForFocusSettle(device: device, attemptsLeft: 11)
        }
    }

    nonisolated private func waitForFocusSettle(device: AVCaptureDevice, attemptsLeft: Int) {
        if attemptsLeft <= 0 || (!device.isAdjustingFocus && !device.isAdjustingExposure) {
            captureNow()
            return
        }
        sessionQueue.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.waitForFocusSettle(device: device, attemptsLeft: attemptsLeft - 1)
        }
    }

    /// Fires the shutter at the highest quality the output allows. (sessionQueue)
    nonisolated private func captureNow() {
        let settings = AVCapturePhotoSettings()
        settings.photoQualityPrioritization = output.maxPhotoQualityPrioritization
        output.capturePhoto(with: settings, delegate: self)
    }
}

// MARK: - Photo Capture Delegate

extension CameraManager: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            Task { @MainActor in captureCompletion?(nil) }
            return
        }
        Task { @MainActor in captureCompletion?(image) }
    }

    /// Always called once, after all other callbacks for a capture request. Use it to
    /// clear the in-flight flag and return the lens to continuous autofocus — doing this
    /// here (rather than in didFinishProcessingPhoto) guarantees the shutter can't get
    /// stuck even if processing errors out. Hops to sessionQueue so the flag and device
    /// config are only touched from one queue.
    nonisolated func photoOutput(_ output: AVCapturePhotoOutput, didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?) {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.isCapturing = false
            if let device = self.captureDevice {
                do {
                    try device.lockForConfiguration()
                    if device.isFocusModeSupported(.continuousAutoFocus) { device.focusMode = .continuousAutoFocus }
                    if device.isExposureModeSupported(.continuousAutoExposure) { device.exposureMode = .continuousAutoExposure }
                    device.unlockForConfiguration()
                } catch { }
            }
        }
    }
}

// MARK: - Barcode Detection Delegate

extension CameraManager: AVCaptureMetadataOutputObjectsDelegate {
    nonisolated func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        // Filter for machine-readable codes with valid string values
        let readableObjects = metadataObjects.compactMap { $0 as? AVMetadataMachineReadableCodeObject }
            .filter { $0.stringValue != nil }

        guard !readableObjects.isEmpty else { return }

        // Prefer food-relevant barcode types (EAN/UPC) over QR or other codes
        let foodBarcodeTypes: Set<AVMetadataObject.ObjectType> = [.ean8, .ean13, .upce]

        let bestObject: AVMetadataMachineReadableCodeObject
        if let foodBarcode = readableObjects.first(where: { foodBarcodeTypes.contains($0.type) }) {
            bestObject = foodBarcode
        } else {
            bestObject = readableObjects.max(by: {
                ($0.bounds.width * $0.bounds.height) < ($1.bounds.width * $1.bounds.height)
            }) ?? readableObjects[0]
        }

        guard let stringValue = bestObject.stringValue else { return }

        Task { @MainActor [weak self] in
            guard let self else { return }

            let now = Date()
            if stringValue == self.lastDeliveredBarcode,
               now.timeIntervalSince(self.lastDeliveredTime) < self.barcodeCooldown {
                return
            }
            self.lastDeliveredBarcode = stringValue
            self.lastDeliveredTime = now

            cameraLog.info("[\(self.instanceId)] 📤 Barcode '\(stringValue)'")
            self.onBarcodeDetected?(stringValue)
        }
    }

    func resetBarcodeCooldown() {
        lastDeliveredBarcode = nil
        lastDeliveredTime = .distantPast
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

// Services/FastingManager.swift

import Foundation
import SwiftUI
import SwiftData
import Combine
import UserNotifications

// NOTE: FastingZone enum must be defined in Models/FastingZone.swift

class FastingManager: ObservableObject {
    
    @Published var currentLog: FastingLog?
    @Published var timeElapsed: TimeInterval = 0
    @Published var timerRunning = false
    @Published var currentZone: FastingZone = .anabolic
    
    private var timer: AnyCancellable?
    
    // ⭐️ FIX: Define modelContext as a public property that is set during setup.
    // It is safe to use '!' here because MainTabView guarantees setup() is called immediately.
    public var modelContext: ModelContext!

    // ⭐️ FIX: Use the simple default initializer, which removes ambiguity.
    init() {
        // Initialization is done in MainTabView.setup(context:)
    }
    
    // This is the required setup function called by MainTabView
    func setup(context: ModelContext) {
        self.modelContext = context
        loadActiveFast()
        requestNotificationAuthorization()
    }
    
    // MARK: - Notification Setup
    
    private func requestNotificationAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if granted {
                print("Notification permission granted.")
            } else if let error = error {
                print("Notification permission error: \(error.localizedDescription)")
            }
        }
    }
    
    private func scheduleNotification(for goalDuration: Double) {
        let content = UNMutableNotificationContent()
        content.title = "Fast Complete! 🔔"
        content.body = "Congratulations! You reached your \(Int(goalDuration)) hour fasting goal. It's time to break your fast."
        content.sound = .default
        
        let endTime = Date().addingTimeInterval(goalDuration * 3600)
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: endTime)
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: "FastingEndNotification", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["FastingEndNotification"])
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error.localizedDescription)")
            }
        }
    }
    
    private func cancelPendingNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["FastingEndNotification"])
        print("Cancelled any pending fasting end notification.")
    }

    // MARK: - Timer Control
    
    func startFast(goalHours: Double) {
        guard currentLog == nil else { return }

        Task {
            let userId = await UserSession.shared.getCurrentUserId()
            let newLog = FastingLog(goalHours: goalHours)
            newLog.userId = userId
            modelContext.insert(newLog)

            await MainActor.run {
                self.currentLog = newLog
                startTimer()
                scheduleNotification(for: goalHours)
                
                // Track analytics
                AnalyticsManager.shared.trackFastStarted(goalHours: goalHours)
            }
        }
    }
    
    func endFast() {
        guard let log = currentLog else { return }

        timer?.cancel()
        timerRunning = false

        log.endTime = Date()
        let userId = log.userId
        let durationHours = timeElapsed / 3600
        let completed = durationHours >= log.goalDuration / 3600

        try? modelContext.save()

        // Upload the completed fast to cloud if user is signed in
        if let userId = userId {
            Task {
                await CloudSyncManager.shared.uploadFastingLogImmediately(log, userId: userId)
            }
        }
        
        // Track analytics
        AnalyticsManager.shared.trackFastEnded(durationHours: durationHours, completed: completed)

        self.currentLog = nil
        self.timeElapsed = 0
        self.currentZone = .anabolic

        cancelPendingNotification()
    }
    
    private func startTimer() {
        guard currentLog != nil else { return }
        
        timerRunning = true
        timer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self, let log = self.currentLog else { return }
                
                let elapsed = Date().timeIntervalSince(log.startTime)
                self.timeElapsed = elapsed
                
                self.updateCurrentZone(elapsedHours: elapsed / 3600)
            }
    }
    
    private func loadActiveFast() {
        Task {
            if let activeLog = await UserScopedQuery.fetchCurrentFast(context: modelContext) {
                await MainActor.run {
                    self.currentLog = activeLog

                    let elapsed = Date().timeIntervalSince(activeLog.startTime)
                    self.timeElapsed = elapsed
                    self.updateCurrentZone(elapsedHours: elapsed / 3600, isInitialLoad: true)
                    startTimer()
                }
            }
        }
    }
    
    private func updateCurrentZone(elapsedHours: Double, isInitialLoad: Bool = false) {
        for zone in FastingZone.allCases.reversed() {
            if elapsedHours >= zone.startHour {
                if self.currentZone != zone {
                    if !isInitialLoad {
                        let haptic = UINotificationFeedbackGenerator()
                        haptic.notificationOccurred(.success)
                    }
                    self.currentZone = zone
                }
                return
            }
        }
    }
    
    // Helper for display formatting
    static func formatTime(seconds: TimeInterval) -> String {
        let totalSeconds = Int(seconds)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let remainingSeconds = totalSeconds % 60
        
        return String(format: "%02d:%02d:%02d", hours, minutes, remainingSeconds)
    }
}

// Helpers/TabRouter.swift

import SwiftUI
import Combine
import SwiftData // ⭐️ 1. Import SwiftData

// ⭐️ 2. FIX: We now navigate using the log's unique ID
enum HomeDestination: Hashable {
    case search
    case scan
    case recipes
    case reminders
    case detail(PersistentIdentifier) // ⭐️ Changed from LoggedFood
    case logProduct(OFFProduct)

    // ⭐️ FIX: Add the missing cases for your tool grid
    case shoppingList
    case reports
    case fasting
    case savedFoods
    case community
    case challenges
}

enum AppTab: Int, CaseIterable {
    case home
    case health
    case scan
    case reports
    case more

    var icon: String {
        switch self {
        case .home: "house"
        case .health: "figure.run"
        case .scan: "camera.viewfinder"
        case .reports: "chart.pie"
        case .more: "line.3.horizontal"
        }
    }

    var label: String {
        switch self {
        case .home: "Home"
        case .health: "Activity"
        case .scan: "Scan"
        case .reports: "Reports"
        case .more: "More"
        }
    }
}

class TabRouter: ObservableObject {
    @Published var selectedTab: AppTab = .home
    @Published var homePath = NavigationPath()
    @Published var homeRefreshID = UUID()
    @Published var homeScrollTrigger = UUID()

    /// Bumps when the user re-taps the already-active tab. Each tab's root view
    /// observes this and resets its own local state (dismiss sheets, pop nav,
    /// scroll to top, etc.).
    @Published var tabReTapTrigger: UUID = UUID()

    // MARK: - Unsaved Changes Gating
    /// Set to true by views (e.g. CreateRecipeView) that have unsaved changes
    @Published var hasUnsavedChanges = false
    /// The tab the user wants to switch to (held while confirmation is pending)
    @Published var pendingTab: AppTab? = nil
    /// Triggers the discard-changes alert in MainTabView
    @Published var showUnsavedChangesAlert = false

    /// Call this instead of setting `selectedTab` directly from tab bar actions.
    /// If unsaved changes exist, it stores the pending tab and shows the alert.
    func attemptTabSwitch(to tab: AppTab) {
        if hasUnsavedChanges {
            pendingTab = tab
            showUnsavedChangesAlert = true
        } else if selectedTab == tab {
            // Re-tap on active tab → reset to that tab's default state.
            if tab == .home {
                homePath = NavigationPath()
            }
            tabReTapTrigger = UUID()
        } else {
            selectedTab = tab
        }
    }

    /// Called when the user confirms discarding unsaved changes.
    func confirmDiscardAndSwitch() {
        hasUnsavedChanges = false
        if let tab = pendingTab {
            // Pop the navigation stack first so CreateRecipeView is dismissed
            homePath = NavigationPath()
            selectedTab = tab
            pendingTab = nil
        }
    }

    func triggerHomeRefresh() {
        homeRefreshID = UUID()
    }

    func scrollHomeToTop() {
        homeScrollTrigger = UUID()
    }
}

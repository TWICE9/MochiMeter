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
    case community
    case challenges
}

enum Tab: Int, CaseIterable {
    case home
    case reports
    case settings

    var icon: String {
        switch self {
        case .home: "house"
        case .reports: "chart.pie"
        case .settings: "gearshape"
        }
    }

    var label: String {
        String(describing: self).capitalized
    }
}

class TabRouter: ObservableObject {
    @Published var selectedTab: Tab = .home
    @Published var homePath = NavigationPath()
    @Published var homeRefreshID = UUID()
    @Published var homeScrollTrigger = UUID()

    func triggerHomeRefresh() {
        homeRefreshID = UUID()
    }

    func scrollHomeToTop() {
        homeScrollTrigger = UUID()
    }
}

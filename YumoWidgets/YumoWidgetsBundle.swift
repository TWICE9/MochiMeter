// YumoWidgets/YumoWidgetsBundle.swift

import WidgetKit
import SwiftUI

@main
struct YumoWidgetsBundle: WidgetBundle {
    var body: some Widget {
        ScanWidget()
        WaterWidget()
        CalorieWidget() // ⭐️ Added the new widget
    }
}

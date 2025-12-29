//
//  UnitSystem.swift
//  Yumo
//
//  Created by Assistant on 2025-12-28.
//

import Foundation

// MARK: - Conversion Helpers
extension UnitSystem {
    
    // Convert weight from metric (kg) to display units
    func formatWeight(_ weightInKg: Double) -> Double {
        switch self {
        case .metric:
            return weightInKg
        case .imperial:
            return weightInKg * 2.20462 // kg to lbs
        }
    }
    
    // Convert weight from display units to metric (kg) for storage
    func convertWeightToMetric(_ weight: Double) -> Double {
        switch self {
        case .metric:
            return weight
        case .imperial:
            return weight / 2.20462 // lbs to kg
        }
    }
    
    // Convert height from metric (cm) to display units
    func formatHeight(_ heightInCm: Double) -> (primary: Double, secondary: Double?) {
        switch self {
        case .metric:
            return (heightInCm, nil)
        case .imperial:
            let totalInches = heightInCm / 2.54
            let feet = floor(totalInches / 12)
            let inches = totalInches.truncatingRemainder(dividingBy: 12)
            return (feet, inches)
        }
    }
    
    // Convert height from display units to metric (cm) for storage
    func convertHeightToMetric(primary: Double, secondary: Double? = nil) -> Double {
        switch self {
        case .metric:
            return primary
        case .imperial:
            // primary = feet, secondary = inches
            let totalInches = (primary * 12) + (secondary ?? 0)
            return totalInches * 2.54
        }
    }
    
    // Format weight with unit for display
    func weightString(_ weightInKg: Double, decimals: Int = 1) -> String {
        let converted = formatWeight(weightInKg)
        return String(format: "%.\(decimals)f %@", converted, weightUnit)
    }
    
    // Format height with unit for display
    func heightString(_ heightInCm: Double) -> String {
        let (primary, secondary) = formatHeight(heightInCm)
        
        switch self {
        case .metric:
            return String(format: "%.0f cm", primary)
        case .imperial:
            if let inches = secondary {
                return String(format: "%.0f'%.0f\"", primary, inches)
            } else {
                return String(format: "%.0f'0\"", primary)
            }
        }
    }
}

import Foundation

enum MacroType {
    case calories
    case carbs
    case protein
    case fat

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
        case .calories: return "kcal"
        case .carbs, .protein, .fat: return "g"
        }
    }

    var unitDisplay: String {
        unit
    }
}

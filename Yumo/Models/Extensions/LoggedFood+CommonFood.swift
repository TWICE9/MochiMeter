import Foundation

extension CommonFood {
    static func fromLoggedFood(_ log: LoggedFood) -> CommonFood {
        CommonFood(
            name: log.name,
            barcode: log.barcode ?? "",
            caloriesPerServing: log.caloriesPerServing,
            proteinPerServing: log.proteinPerServing,
            carbsPerServing: log.carbsPerServing,
            fatPerServing: log.fatPerServing,
            fiberPerServing: log.fiberPerServing,
            sugarPerServing: log.sugarPerServing,
            saltPerServing: log.saltPerServing,
            potassiumPerServing: log.potassiumPerServing,
            servingSizeDescription: log.servingSizeDescription,
            isHalal: log.isHalal
        )
    }
}

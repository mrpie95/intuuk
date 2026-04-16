import Foundation
import SwiftData

@Model
class FoodEntry {
    var timestamp: Date
    var protein: Double
    var carbs: Double
    var fat: Double

    var calories: Double { protein * 4 + carbs * 4 + fat * 9 }

    init(timestamp: Date = .now, protein: Double, carbs: Double, fat: Double) {
        self.timestamp = timestamp
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
    }
}

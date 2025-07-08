import Foundation

class CostTracker: ObservableObject {
    @Published var claudeCost: Double = 0.0
    
    var totalCost: Double {
        return claudeCost
    }
    
    func addClaudeCost(_ amount: Double) {
        claudeCost += amount
    }
    
    func reset() {
        claudeCost = 0.0
    }
}

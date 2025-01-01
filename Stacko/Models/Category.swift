import Foundation

struct CategoryGroup: Identifiable, Codable {
    let id: UUID
    var name: String
    var emoji: String?
    var categories: [Category]
}

struct Category: Identifiable, Codable {
    let id: UUID
    var name: String
    var emoji: String?
    var target: Target?
    var allocated: Double
    var spent: Double
    
    var available: Double {
        allocated - spent
    }
    
    var targetProgress: Double {
        guard let target = target else { return 0 }
        
        return allocated
    }
}

struct Target: Codable {
    enum TargetType: Codable {
        case monthly(amount: Double)
        case weekly(amount: Double)
        case byDate(amount: Double, date: Date)
    }
    
    let type: TargetType
} 
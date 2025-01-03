import Foundation

struct TransactionTemplate: Identifiable, Codable {
    let id: UUID
    let name: String
    let payee: String
    let categoryId: UUID
    let amount: Double
    let isIncome: Bool
    let recurrence: Recurrence?
    
    enum Recurrence: String, Codable, CaseIterable {
        case daily = "Daily"
        case weekly = "Weekly"
        case monthly = "Monthly"
        case yearly = "Yearly"
        
        var description: String { rawValue }
    }
} 
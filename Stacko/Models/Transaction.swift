import Foundation

struct Transaction: Identifiable, Codable {
    let id: UUID
    var date: Date
    var payee: String
    var categoryId: UUID
    var amount: Double
    var note: String?
    var isIncome: Bool
    var accountId: UUID
    var toAccountId: UUID?
    
    var isTransfer: Bool {
        toAccountId != nil
    }
} 
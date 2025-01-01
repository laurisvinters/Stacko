import Foundation

struct TransactionTemplate: Identifiable, Codable {
    let id: UUID
    var name: String
    var payee: String
    var categoryId: UUID
    var amount: Double
    var isIncome: Bool
    var recurrence: Recurrence?
    
    enum Recurrence: String, Codable, Hashable, CaseIterable {
        case daily = "daily"
        case weekly = "weekly"
        case monthly = "monthly"
        case yearly = "yearly"
        
        var description: String {
            switch self {
            case .daily: return "Daily"
            case .weekly: return "Weekly"
            case .monthly: return "Monthly"
            case .yearly: return "Yearly"
            }
        }
    }
    
    // Add Codable conformance explicitly
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case payee
        case categoryId
        case amount
        case isIncome
        case recurrence
    }
    
    init(id: UUID, name: String, payee: String, categoryId: UUID, amount: Double, isIncome: Bool, recurrence: Recurrence?) {
        self.id = id
        self.name = name
        self.payee = payee
        self.categoryId = categoryId
        self.amount = amount
        self.isIncome = isIncome
        self.recurrence = recurrence
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        payee = try container.decode(String.self, forKey: .payee)
        categoryId = try container.decode(UUID.self, forKey: .categoryId)
        amount = try container.decode(Double.self, forKey: .amount)
        isIncome = try container.decode(Bool.self, forKey: .isIncome)
        recurrence = try container.decodeIfPresent(Recurrence.self, forKey: .recurrence)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(payee, forKey: .payee)
        try container.encode(categoryId, forKey: .categoryId)
        try container.encode(amount, forKey: .amount)
        try container.encode(isIncome, forKey: .isIncome)
        try container.encodeIfPresent(recurrence, forKey: .recurrence)
    }
} 
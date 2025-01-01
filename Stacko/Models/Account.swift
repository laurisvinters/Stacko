import Foundation

struct Account: Identifiable, Codable {
    let id: UUID
    var name: String
    var type: AccountType
    var category: AccountCategory
    var balance: Double
    var clearedBalance: Double
    var icon: String
    var isArchived: Bool
    var notes: String?
    var lastReconciled: Date?
    
    enum AccountType: String, Codable, CaseIterable {
        case cash = "Cash"
        case checking = "Checking"
        case savings = "Savings"
        case creditCard = "Credit Card"
        
        var icon: String {
            switch self {
            case .cash: "💵"
            case .checking: "🏦"
            case .savings: "🏆"
            case .creditCard: "💳"
            }
        }
    }
    
    enum AccountCategory: String, Codable, CaseIterable {
        case personal = "Personal"
        case business = "Business"
        case investment = "Investment"
        case shared = "Shared"
    }
    
    init(
        id: UUID = UUID(),
        name: String,
        type: AccountType,
        category: AccountCategory = .personal,
        balance: Double = 0,
        clearedBalance: Double = 0,
        icon: String? = nil,
        isArchived: Bool = false,
        notes: String? = nil,
        lastReconciled: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.category = category
        self.balance = balance
        self.clearedBalance = clearedBalance
        self.icon = icon ?? type.icon
        self.isArchived = isArchived
        self.notes = notes
        self.lastReconciled = lastReconciled
    }
} 
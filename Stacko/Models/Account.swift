import Foundation
import FirebaseFirestore

struct Account: Identifiable, Codable {
    var id: UUID
    var name: String
    var type: AccountType
    var category: AccountCategory
    var balance: Double
    var clearedBalance: Double
    var icon: String
    var isArchived: Bool
    var notes: String?
    var lastReconciled: Date?
    var initialBalance: Double
    var createdAt: Date
    
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
        lastReconciled: Date? = nil,
        initialBalance: Double = 0,
        createdAt: Date = Date()
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
        self.initialBalance = initialBalance
        self.createdAt = createdAt
    }
    
    // Convert to Firestore data
    func toFirestore() -> [String: Any] {
        return [
            "id": id.uuidString,
            "name": name,
            "type": type.rawValue,
            "category": category.rawValue,
            "balance": balance,
            "clearedBalance": clearedBalance,
            "icon": icon,
            "isArchived": isArchived,
            "notes": notes as Any,
            "lastReconciled": lastReconciled as Any,
            "initialBalance": initialBalance,
            "createdAt": createdAt
        ]
    }
    
    // Create from Firestore data
    static func fromFirestore(_ data: [String: Any]) -> Account? {
        guard 
            let idString = data["id"] as? String,
            let id = UUID(uuidString: idString),
            let name = data["name"] as? String,
            let typeRaw = data["type"] as? String,
            let type = AccountType(rawValue: typeRaw),
            let categoryRaw = data["category"] as? String,
            let category = AccountCategory(rawValue: categoryRaw),
            let balance = data["balance"] as? Double,
            let clearedBalance = data["clearedBalance"] as? Double,
            let icon = data["icon"] as? String,
            let isArchived = data["isArchived"] as? Bool,
            let initialBalance = data["initialBalance"] as? Double,
            let createdAt = data["createdAt"] as? Timestamp
        else { return nil }
        
        return Account(
            id: id,
            name: name,
            type: type,
            category: category,
            balance: balance,
            clearedBalance: clearedBalance,
            icon: icon,
            isArchived: isArchived,
            notes: data["notes"] as? String,
            lastReconciled: (data["lastReconciled"] as? Timestamp)?.dateValue(),
            initialBalance: initialBalance,
            createdAt: createdAt.dateValue()
        )
    }
} 
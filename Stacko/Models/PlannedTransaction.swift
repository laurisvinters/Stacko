import Foundation
import FirebaseFirestore

enum PlannedTransactionType: String, Codable {
    case automatic
    case manual
}

enum RecurrenceType: Codable, Hashable {
    case daily
    case weekly
    case monthly
    case custom(interval: Int, period: RecurrencePeriod)
    
    enum RecurrencePeriod: String, Codable, Hashable {
        case day
        case week
        case month
        case year
    }
    
    private enum CodingKeys: String, CodingKey {
        case type
        case interval
        case period
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .daily:
            try container.encode("daily", forKey: .type)
        case .weekly:
            try container.encode("weekly", forKey: .type)
        case .monthly:
            try container.encode("monthly", forKey: .type)
        case .custom(let interval, let period):
            try container.encode("custom", forKey: .type)
            try container.encode(interval, forKey: .interval)
            try container.encode(period, forKey: .period)
        }
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type {
        case "daily":
            self = .daily
        case "weekly":
            self = .weekly
        case "monthly":
            self = .monthly
        case "custom":
            let interval = try container.decode(Int.self, forKey: .interval)
            let period = try container.decode(RecurrencePeriod.self, forKey: .period)
            self = .custom(interval: interval, period: period)
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Invalid recurrence type")
        }
    }
    
    func toFirestore() -> [String: Any] {
        switch self {
        case .daily:
            return ["type": "daily"]
        case .weekly:
            return ["type": "weekly"]
        case .monthly:
            return ["type": "monthly"]
        case .custom(let interval, let period):
            return [
                "type": "custom",
                "interval": interval,
                "period": period.rawValue
            ]
        }
    }
    
    static func fromFirestore(_ data: [String: Any]) -> RecurrenceType? {
        guard let type = data["type"] as? String else { return nil }
        
        switch type {
        case "daily": return .daily
        case "weekly": return .weekly
        case "monthly": return .monthly
        case "custom":
            guard let interval = data["interval"] as? Int,
                  let periodString = data["period"] as? String,
                  let period = RecurrencePeriod(rawValue: periodString) else { return nil }
            return .custom(interval: interval, period: period)
        default: return nil
        }
    }
    
    func calculateNextDate(from date: Date) -> Date {
        let calendar = Calendar.current
        switch self {
        case .daily:
            return calendar.date(byAdding: .day, value: 1, to: date) ?? date
        case .weekly:
            return calendar.date(byAdding: .weekOfYear, value: 1, to: date) ?? date
        case .monthly:
            return calendar.date(byAdding: .month, value: 1, to: date) ?? date
        case .custom(let interval, let period):
            let component: Calendar.Component
            switch period {
            case .day: component = .day
            case .week: component = .weekOfYear
            case .month: component = .month
            case .year: component = .year
            }
            return calendar.date(byAdding: component, value: interval, to: date) ?? date
        }
    }
}

struct PlannedTransaction: Identifiable, Hashable {
    let id: UUID
    var title: String
    var amount: Double
    var categoryId: UUID?
    var accountId: UUID
    var note: String
    var isIncome: Bool
    var type: PlannedTransactionType
    var recurrence: RecurrenceType
    var isActive: Bool
    var nextDueDate: Date
    var lastProcessedDate: Date?
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: PlannedTransaction, rhs: PlannedTransaction) -> Bool {
        lhs.id == rhs.id
    }
    
    func toFirestore() -> [String: Any] {
        var data: [String: Any] = [
            "id": id.uuidString,
            "title": title,
            "amount": amount,
            "accountId": accountId.uuidString,
            "note": note,
            "isIncome": isIncome,
            "type": type.rawValue,
            "recurrence": recurrence.toFirestore(),
            "isActive": isActive,
            "nextDueDate": Timestamp(date: nextDueDate)
        ]
        
        if let categoryId = categoryId {
            data["categoryId"] = categoryId.uuidString
        }
        
        if let lastProcessedDate = lastProcessedDate {
            data["lastProcessedDate"] = Timestamp(date: lastProcessedDate)
        }
        
        return data
    }
    
    static func fromFirestore(_ data: [String: Any]) -> PlannedTransaction? {
        guard let idString = data["id"] as? String,
              let id = UUID(uuidString: idString),
              let title = data["title"] as? String,
              let amount = data["amount"] as? Double,
              let accountIdString = data["accountId"] as? String,
              let accountId = UUID(uuidString: accountIdString),
              let isIncome = data["isIncome"] as? Bool,
              let typeString = data["type"] as? String,
              let type = PlannedTransactionType(rawValue: typeString),
              let recurrenceData = data["recurrence"] as? [String: Any],
              let recurrence = RecurrenceType.fromFirestore(recurrenceData),
              let isActive = data["isActive"] as? Bool,
              let nextDueTimestamp = data["nextDueDate"] as? Timestamp else {
            return nil
        }
        
        let categoryId: UUID?
        if let categoryIdString = data["categoryId"] as? String {
            categoryId = UUID(uuidString: categoryIdString)
        } else {
            categoryId = nil
        }
        
        let lastProcessedDate: Date?
        if let lastProcessedTimestamp = data["lastProcessedDate"] as? Timestamp {
            lastProcessedDate = lastProcessedTimestamp.dateValue()
        } else {
            lastProcessedDate = nil
        }
        
        return PlannedTransaction(
            id: id,
            title: title,
            amount: amount,
            categoryId: categoryId,
            accountId: accountId,
            note: data["note"] as? String ?? "",
            isIncome: isIncome,
            type: type,
            recurrence: recurrence,
            isActive: isActive,
            nextDueDate: nextDueTimestamp.dateValue(),
            lastProcessedDate: lastProcessedDate
        )
    }
    
    func calculateNextDueDate() -> Date {
        return recurrence.calculateNextDate(from: nextDueDate)
    }
}

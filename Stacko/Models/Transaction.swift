import Foundation
import FirebaseFirestore

struct Transaction: Identifiable, Encodable {
    let id: UUID
    let date: Date
    let payee: String
    let categoryId: UUID
    let amount: Double
    let note: String?
    let isIncome: Bool
    let accountId: UUID
    let toAccountId: UUID?
    
    var isTransfer: Bool {
        toAccountId != nil
    }
    
    // Convert to Firestore data
    func toFirestore() -> [String: Any] {
        var data: [String: Any] = [
            "id": id.uuidString,
            "date": Timestamp(date: date),
            "payee": payee,
            "categoryId": categoryId.uuidString,
            "amount": amount,
            "isIncome": isIncome,
            "accountId": accountId.uuidString
        ]
        
        if let note = note {
            data["note"] = note
        }
        
        if let toAccountId = toAccountId {
            data["toAccountId"] = toAccountId.uuidString
        }
        
        return data
    }
    
    // Create from Firestore data
    static func fromFirestore(_ data: [String: Any]) -> Transaction? {
        guard 
            let idString = data["id"] as? String,
            let id = UUID(uuidString: idString),
            let timestamp = data["date"] as? Timestamp,
            let payee = data["payee"] as? String,
            let categoryIdString = data["categoryId"] as? String,
            let categoryId = UUID(uuidString: categoryIdString),
            let amount = data["amount"] as? Double,
            let isIncome = data["isIncome"] as? Bool,
            let accountIdString = data["accountId"] as? String,
            let accountId = UUID(uuidString: accountIdString)
        else { return nil }
        
        let toAccountId = (data["toAccountId"] as? String).flatMap { UUID(uuidString: $0) }
        
        return Transaction(
            id: id,
            date: timestamp.dateValue(),
            payee: payee,
            categoryId: categoryId,
            amount: amount,
            note: data["note"] as? String,
            isIncome: isIncome,
            accountId: accountId,
            toAccountId: toAccountId
        )
    }
}
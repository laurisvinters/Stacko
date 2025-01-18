import Foundation
import FirebaseFirestore

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
    
    // Convert to Firestore data
    func toFirestore() -> [String: Any] {
        var data: [String: Any] = [
            "id": id.uuidString,
            "name": name,
            "payee": payee,
            "categoryId": categoryId.uuidString,
            "amount": amount,
            "isIncome": isIncome
        ]
        
        if let recurrence = recurrence {
            data["recurrence"] = recurrence.rawValue
        }
        
        return data
    }
    
    // Create from Firestore data
    static func fromFirestore(_ data: [String: Any]) -> TransactionTemplate? {
        guard 
            let idString = data["id"] as? String,
            let id = UUID(uuidString: idString),
            let name = data["name"] as? String,
            let payee = data["payee"] as? String,
            let categoryIdString = data["categoryId"] as? String,
            let categoryId = UUID(uuidString: categoryIdString),
            let amount = data["amount"] as? Double,
            let isIncome = data["isIncome"] as? Bool
        else { return nil }
        
        let recurrence = (data["recurrence"] as? String).flatMap { Recurrence(rawValue: $0) }
        
        return TransactionTemplate(
            id: id,
            name: name,
            payee: payee,
            categoryId: categoryId,
            amount: amount,
            isIncome: isIncome,
            recurrence: recurrence
        )
    }
} 
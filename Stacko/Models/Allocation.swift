import Foundation
import FirebaseFirestore

struct Allocation: Identifiable {
    let id: UUID
    let date: Date
    let categoryId: UUID
    let amount: Double
    
    // Convert to Firestore data
    func toFirestore() -> [String: Any] {
        return [
            "id": id.uuidString,
            "date": Timestamp(date: date),
            "categoryId": categoryId.uuidString,
            "amount": amount
        ]
    }
    
    // Create from Firestore data
    static func fromFirestore(_ data: [String: Any]) -> Allocation? {
        guard 
            let idString = data["id"] as? String,
            let id = UUID(uuidString: idString),
            let timestamp = data["date"] as? Timestamp,
            let categoryIdString = data["categoryId"] as? String,
            let categoryId = UUID(uuidString: categoryIdString),
            let amount = data["amount"] as? Double
        else { return nil }
        
        return Allocation(
            id: id,
            date: timestamp.dateValue(),
            categoryId: categoryId,
            amount: amount
        )
    }
}

import Foundation
import FirebaseFirestore
import FirebaseAuth

class FirebaseService: ObservableObject {
    private let db = Firestore.firestore()
    
    private func createTarget(from data: [String: Any]) -> Target? {
        guard let targetTypeString = data["targetType"] as? String,
              let amount = data["targetAmount"] as? Double else { return nil }
        
        switch targetTypeString {
        case "monthly":
            return Target(type: .monthly(amount: amount))
        case "weekly":
            return Target(type: .weekly(amount: amount))
        case "byDate":
            guard let date = (data["targetDate"] as? Timestamp)?.dateValue() else { return nil }
            return Target(type: .byDate(amount: amount, date: date))
        default:
            return nil
        }
    }

    private func targetData(from target: Target) -> [String: Any] {
        var data: [String: Any] = [:]
        
        switch target.type {
        case .monthly(let amount):
            data["targetType"] = "monthly"
            data["targetAmount"] = amount
        case .weekly(let amount):
            data["targetType"] = "weekly"
            data["targetAmount"] = amount
        case .byDate(let amount, let date):
            data["targetType"] = "byDate"
            data["targetAmount"] = amount
            data["targetDate"] = Timestamp(date: date)
        }
        
        return data
    }

    func saveCategory(_ category: Category, groupId: UUID) async throws {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        var data: [String: Any] = [
            "name": category.name,
            "emoji": category.emoji as Any,
            "allocated": category.allocated,
            "spent": category.spent
        ]
        
        if let target = category.target {
            data.merge(targetData(from: target)) { (_, new) in new }
        }
        
        try await db.collection("users")
            .document(userId)
            .collection("categoryGroups")
            .document(groupId.uuidString)
            .collection("categories")
            .document(category.id.uuidString)
            .setData(data)
    } 
} 
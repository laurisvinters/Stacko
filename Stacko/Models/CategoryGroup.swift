import Foundation
import FirebaseFirestore

struct CategoryGroup: Identifiable {
    let id: UUID
    var name: String
    var emoji: String?
    var categories: [Category]
    
    // Convert to Firestore data
    func toFirestore() -> [String: Any] {
        return [
            "id": id.uuidString,
            "name": name,
            "emoji": emoji as Any,
            "categories": categories.map { $0.toFirestore() }
        ]
    }
    
    // Create from Firestore data
    static func fromFirestore(_ data: [String: Any]) -> CategoryGroup? {
        guard 
            let idString = data["id"] as? String,
            let id = UUID(uuidString: idString),
            let name = data["name"] as? String,
            let categoriesData = data["categories"] as? [[String: Any]]
        else { return nil }
        
        let categories = categoriesData.compactMap { Category.fromFirestore($0) }
        
        return CategoryGroup(
            id: id,
            name: name,
            emoji: data["emoji"] as? String,
            categories: categories
        )
    }
} 
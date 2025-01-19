import Foundation
import FirebaseFirestore

struct Category: Identifiable {
    let id: UUID
    var name: String
    var emoji: String?
    var target: Target?
    var allocated: Double
    var spent: Double
    
    var available: Double {
        allocated - spent
    }
    
    // Convert to Firestore data
    func toFirestore() -> [String: Any] {
        var data: [String: Any] = [
            "id": id.uuidString,
            "name": name,
            "allocated": allocated,
            "spent": spent
        ]
        
        if let emoji = emoji {
            data["emoji"] = emoji
        }
        
        if let target = target {
            data["target"] = target.toFirestore()
        }
        
        return data
    }
    
    // Create from Firestore data
    static func fromFirestore(_ data: [String: Any]) -> Category? {
        guard 
            let idString = data["id"] as? String,
            let id = UUID(uuidString: idString),
            let name = data["name"] as? String,
            let allocated = data["allocated"] as? Double,
            let spent = data["spent"] as? Double
        else { return nil }
        
        let target = (data["target"] as? [String: Any]).flatMap { Target.fromFirestore($0) }
        
        return Category(
            id: id,
            name: name,
            emoji: data["emoji"] as? String,
            target: target,
            allocated: allocated,
            spent: spent
        )
    }
}

// Target model for category budgeting
struct Target {
    enum TargetType {
        case monthly(amount: Double)
        case weekly(amount: Double)
        case byDate(amount: Double, date: Date)
        case custom(amount: Double, interval: Interval)
        case noDate(amount: Double)
    }
    
    enum Interval {
        case days(count: Int)
        case months(count: Int)
        case years(count: Int)
        case monthlyOnDay(day: Int)
    }
    
    let type: TargetType
    
    // Convert to Firestore data
    func toFirestore() -> [String: Any] {
        var data: [String: Any]
        
        switch type {
        case .monthly(let amount):
            data = [
                "type": "monthly",
                "amount": amount
            ]
            
        case .weekly(let amount):
            data = [
                "type": "weekly",
                "amount": amount
            ]
            
        case .byDate(let amount, let date):
            data = [
                "type": "byDate",
                "amount": amount,
                "date": Timestamp(date: date)
            ]
            
        case .custom(let amount, let interval):
            data = [
                "type": "custom",
                "amount": amount
            ]
            
            switch interval {
            case .days(let count):
                data["intervalType"] = "days"
                data["intervalCount"] = count
            case .months(let count):
                data["intervalType"] = "months"
                data["intervalCount"] = count
            case .years(let count):
                data["intervalType"] = "years"
                data["intervalCount"] = count
            case .monthlyOnDay(let day):
                data["intervalType"] = "monthlyOnDay"
                data["day"] = day
            }
            
        case .noDate(let amount):
            data = [
                "type": "noDate",
                "amount": amount
            ]
        }
        
        return data
    }
    
    // Create from Firestore data
    static func fromFirestore(_ data: [String: Any]) -> Target? {
        guard 
            let type = data["type"] as? String,
            let amount = data["amount"] as? Double
        else { return nil }
        
        switch type {
        case "monthly":
            return Target(type: .monthly(amount: amount))
            
        case "weekly":
            return Target(type: .weekly(amount: amount))
            
        case "byDate":
            guard let timestamp = data["date"] as? Timestamp else { return nil }
            return Target(type: .byDate(amount: amount, date: timestamp.dateValue()))
            
        case "custom":
            guard 
                let intervalType = data["intervalType"] as? String,
                let intervalCount = data["intervalCount"] as? Int
            else { return nil }
            
            let interval: Interval
            switch intervalType {
            case "days":
                interval = .days(count: intervalCount)
            case "months":
                interval = .months(count: intervalCount)
            case "years":
                interval = .years(count: intervalCount)
            case "monthlyOnDay":
                guard let day = data["day"] as? Int else { return nil }
                interval = .monthlyOnDay(day: day)
            default:
                return nil
            }
            
            return Target(type: .custom(amount: amount, interval: interval))
            
        case "noDate":
            return Target(type: .noDate(amount: amount))
            
        default:
            return nil
        }
    }
} 
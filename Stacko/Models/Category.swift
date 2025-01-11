import Foundation

struct CategoryGroup: Identifiable, Codable {
    let id: UUID
    var name: String
    var emoji: String?
    var categories: [Category]
}

struct Category: Identifiable, Codable {
    let id: UUID
    var name: String
    var emoji: String?
    var target: Target?
    var allocated: Double
    var spent: Double
    
    var available: Double {
        allocated - spent
    }
    
    var targetProgress: Double {
        guard let target = target else { return 0 }
        
        return allocated
    }
}

struct Target: Codable {
    enum TargetType: Codable {
        case monthly(amount: Double)
        case weekly(amount: Double)
        case byDate(amount: Double, date: Date)
        case custom(amount: Double, interval: Interval)
        case noDate(amount: Double)
    }
    
    enum Interval: Codable {
        case days(count: Int)
        case months(count: Int)
        case years(count: Int)
        case monthlyOnDay(day: Int) // 1-31, represents day of month
    }
    
    let type: TargetType
    
    var resetDate: Date {
        let now = Date()
        
        switch type {
        case .monthly:
            return Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: now))!
        case .weekly:
            return Calendar.current.date(from: Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
        case .byDate(_, let date):
            return date
        case .custom(_, let interval):
            switch interval {
            case .days(let count):
                return Calendar.current.date(byAdding: .day, value: count, to: now)!
            case .months(let count):
                return Calendar.current.date(byAdding: .month, value: count, to: now)!
            case .years(let count):
                return Calendar.current.date(byAdding: .year, value: count, to: now)!
            case .monthlyOnDay(let day):
                var components = Calendar.current.dateComponents([.year, .month], from: now)
                components.day = min(day, Calendar.current.range(of: .day, in: .month, for: now)?.count ?? 28)
                return Calendar.current.date(from: components)!
            }
        case .noDate:
            return .distantFuture
        }
    }
} 
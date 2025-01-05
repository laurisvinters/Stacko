import Foundation
import SwiftUI

// Base model for setup flow
struct SetupGroup: Identifiable {
    let id: UUID
    let name: String
    var categories: [SetupCategory]
    
    init(id: UUID = UUID(), name: String, categories: [SetupCategory] = []) {
        self.id = id
        self.name = name
        self.categories = categories
    }
}

struct SetupCategory: Identifiable {
    let id: UUID
    let name: String
    let emoji: String
    let target: Target?
    
    init(id: UUID = UUID(), name: String, emoji: String, target: Target? = nil) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.target = target
    }
}

// Helper for sheet presentation
struct IdentifiableUUID: Identifiable {
    let id: UUID
} 
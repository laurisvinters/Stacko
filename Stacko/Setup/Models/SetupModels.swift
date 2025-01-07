import Foundation
import SwiftUI

// Base model for setup flow
struct SetupGroup: Identifiable {
    let id: UUID
    let name: String
    var categories: [SetupCategory]
    let description: String
    let examples: String
    
    init(
        id: UUID = UUID(), 
        name: String, 
        categories: [SetupCategory] = [], 
        description: String = "", 
        examples: String = ""
    ) {
        self.id = id
        self.name = name
        self.categories = categories
        self.description = description
        self.examples = examples
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
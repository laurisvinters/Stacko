import SwiftUI

enum SetupStep {
    case modeSelection
    case groups
    case categories
    case targets
    case accounts
    case review
}

enum SetupMode {
    case recommended
    case fast
}

class SetupCoordinator: ObservableObject {
    @Published var currentStep: SetupStep = .modeSelection
    @Published var setupMode: SetupMode?
    @Published var currentGroupIndex = 0
    @Published var setupGroups: [SetupGroup] = []
    @Published var selectedCategories: Set<UUID> = []
    @Published var isSetupComplete = false
    
    var currentGroup: SetupGroup? {
        guard currentGroupIndex < setupGroups.count else { return nil }
        return setupGroups[currentGroupIndex]
    }
    
    var isLastGroup: Bool {
        currentGroupIndex == setupGroups.count - 1
    }
    
    func setSetupMode(_ mode: SetupMode) {
        setupMode = mode
        switch mode {
        case .recommended:
            currentStep = .groups
        case .fast:
            // Use the full list of suggested groups from GroupSetupView
            setupGroups = [
                SetupGroup(name: "Housing", categories: [
                    SetupCategory(name: "Rent/Mortgage", emoji: "🏠"),
                    SetupCategory(name: "Property Tax", emoji: "📋"),
                    SetupCategory(name: "Home Insurance", emoji: "🔒"),
                    SetupCategory(name: "Home Maintenance", emoji: "🔧"),
                    SetupCategory(name: "Home Improvement", emoji: "🏗️"),
                    SetupCategory(name: "Furniture", emoji: "🛋️")
                ]),
                SetupGroup(name: "Transportation", categories: [
                    SetupCategory(name: "Car Payment", emoji: "🚗"),
                    SetupCategory(name: "Car Insurance", emoji: "🔒"),
                    SetupCategory(name: "Gas", emoji: "⛽️"),
                    SetupCategory(name: "Car Maintenance", emoji: "🔧"),
                    SetupCategory(name: "Public Transit", emoji: "🚌"),
                    SetupCategory(name: "Parking", emoji: "🅿️")
                ]),
                SetupGroup(name: "Food", categories: [
                    SetupCategory(name: "Groceries", emoji: "🛒"),
                    SetupCategory(name: "Restaurants", emoji: "🍽️"),
                    SetupCategory(name: "Coffee Shops", emoji: "☕️"),
                    SetupCategory(name: "Food Delivery", emoji: "🛵"),
                    SetupCategory(name: "Snacks", emoji: "🍿")
                ]),
                SetupGroup(name: "Monthly Bills", categories: [
                    SetupCategory(name: "Utilities", emoji: "⚡️"),
                    SetupCategory(name: "Phone & Internet", emoji: "📱"),
                    SetupCategory(name: "Insurance", emoji: "📄"),
                    SetupCategory(name: "Credit Card", emoji: "💳"),
                    SetupCategory(name: "Loan Payments", emoji: "💰")
                ]),
                SetupGroup(name: "Shopping", categories: [
                    SetupCategory(name: "Clothing", emoji: "👕"),
                    SetupCategory(name: "Electronics", emoji: "🖥️"),
                    SetupCategory(name: "Accessories", emoji: "👜"),
                    SetupCategory(name: "Jewelry", emoji: "💍"),
                    SetupCategory(name: "Equipment", emoji: "🛠"),
                    SetupCategory(name: "Gifts", emoji: "🎁"),
                    SetupCategory(name: "Online Shopping", emoji: "🛒")
                ]),
                SetupGroup(name: "Entertainment", categories: [
                    SetupCategory(name: "Netflix", emoji: "📺"),
                    SetupCategory(name: "Games", emoji: "🎮"),
                    SetupCategory(name: "Sports", emoji: "⚽️"),
                    SetupCategory(name: "Concerts", emoji: "🎵"),
                    SetupCategory(name: "Streaming Services", emoji: "📺"),
                    SetupCategory(name: "Books", emoji: "📚"),
                    SetupCategory(name: "Hobbies", emoji: "🎨")
                ]),
                SetupGroup(name: "Health", categories: [
                    SetupCategory(name: "Medical", emoji: "🏥"),
                    SetupCategory(name: "Dental", emoji: "🦷"),
                    SetupCategory(name: "Vision", emoji: "👓"),
                    SetupCategory(name: "Pharmacy", emoji: "💊"),
                    SetupCategory(name: "Fitness", emoji: "🏋")
                ]),
                SetupGroup(name: "Personal Care", categories: [
                    SetupCategory(name: "Hair Care", emoji: "💇"),
                    SetupCategory(name: "Skincare", emoji: "🧴"),
                    SetupCategory(name: "Cosmetics", emoji: "💄"),
                    SetupCategory(name: "Spa & Massage", emoji: "💆"),
                    SetupCategory(name: "Grooming", emoji: "✂️")
                ]),
                SetupGroup(name: "Education", categories: [
                    SetupCategory(name: "Tuition", emoji: "🎓"),
                    SetupCategory(name: "Books", emoji: "📚"),
                    SetupCategory(name: "Courses", emoji: "📝"),
                    SetupCategory(name: "School Supplies", emoji: "🎒"),
                    SetupCategory(name: "Student Loans", emoji: "💰")
                ]),
                SetupGroup(name: "Travel / Holidays", categories: [
                    SetupCategory(name: "Flights", emoji: "✈️"),
                    SetupCategory(name: "Hotels", emoji: "🏨"),
                    SetupCategory(name: "Car Rental", emoji: "🚗"),
                    SetupCategory(name: "Activities", emoji: "🎯"),
                    SetupCategory(name: "Travel Insurance", emoji: "🔒"),
                    SetupCategory(name: "Food & Dining", emoji: "🍽️"),
                    SetupCategory(name: "Shopping", emoji: "🛍️"),
                    SetupCategory(name: "Tours & Excursions", emoji: "🏛️"),
                    SetupCategory(name: "Beach Activities", emoji: "🏖️"),
                    SetupCategory(name: "Souvenirs", emoji: "🎁")
                ]),
                SetupGroup(name: "Pets", categories: [
                    SetupCategory(name: "Food", emoji: "🦴"),
                    SetupCategory(name: "Vet", emoji: "🏥"),
                    SetupCategory(name: "Supplies", emoji: "🪮"),
                    SetupCategory(name: "Grooming", emoji: "✂️"),
                    SetupCategory(name: "Insurance", emoji: "📄")
                ]),
                SetupGroup(name: "Income", categories: [
                    SetupCategory(name: "Salary", emoji: "💰"),
                    SetupCategory(name: "Investments", emoji: "📈"),
                    SetupCategory(name: "Side Jobs", emoji: "💼"),
                    SetupCategory(name: "Gifts", emoji: "🎁"),
                    SetupCategory(name: "Rental Income", emoji: "🏠"),
                    SetupCategory(name: "Dividends", emoji: "💵"),
                    SetupCategory(name: "Refunds", emoji: "🔄")
                ])
            ]
            
            // Auto-select all categories
            for group in setupGroups {
                for category in group.categories {
                    selectedCategories.insert(category.id)
                }
            }
            
            // In fast mode, start with targets setup
            currentStep = .targets
        }
    }
    
    func moveToNextGroup() {
        if currentGroupIndex < setupGroups.count - 1 {
            currentGroupIndex += 1
        }
    }
    
    func moveToPreviousGroup() {
        if currentGroupIndex > 0 {
            currentGroupIndex -= 1
        }
    }
    
    func completeSetup() {
        // Save all selected categories and groups
        // This would typically involve persisting the data to your storage
        
        // Mark setup as complete
        isSetupComplete = true
    }
    
    func moveToPreviousStep() {
        switch currentStep {
        case .modeSelection:
            break // First step, do nothing
        case .groups:
            reset() // Reset all state when going back to mode selection
        case .categories:
            currentStep = .groups
            currentGroupIndex = 0
        case .targets:
            if setupMode == .fast {
                reset() // Reset all state when going back to mode selection in fast mode
            } else {
                currentStep = .categories
            }
        case .accounts:
            if setupMode == .fast {
                currentStep = .targets
            } else {
                currentStep = .targets
            }
        case .review:
            currentStep = .accounts
        }
    }
    
    func moveToNextStep() {
        switch currentStep {
        case .modeSelection:
            break
        case .groups:
            currentStep = .categories
        case .categories:
            currentStep = .targets
        case .targets:
            currentStep = .accounts
        case .accounts:
            currentStep = .review
        case .review:
            isSetupComplete = true
        }
    }
    
    func cancelSetup() {
        reset()
    }
    
    func reset() {
        // Reset all state to initial values
        currentStep = .modeSelection
        setupMode = nil
        currentGroupIndex = 0
        setupGroups = []
        selectedCategories = []
        isSetupComplete = false
    }
}
import SwiftUI

enum SetupStep {
    case groups
    case categories
    case targets
    case accounts
    case review
}

class SetupCoordinator: ObservableObject {
    @Published var currentStep: SetupStep = .groups
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
    
    func moveToPreviousStep() {
        switch currentStep {
        case .groups:
            break // First step, do nothing
        case .categories:
            currentStep = .groups
            currentGroupIndex = 0
        case .targets:
            currentStep = .categories
        case .accounts:
            currentStep = .targets
        case .review:
            currentStep = .accounts
        }
    }
    
    func moveToNextStep() {
        switch currentStep {
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
        currentStep = .groups
        currentGroupIndex = 0
        setupGroups = []
        selectedCategories = []
        isSetupComplete = false
    }
} 
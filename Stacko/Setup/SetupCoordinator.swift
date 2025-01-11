import SwiftUI

enum SetupStep {
    case groups
    case categories
    case accounts
    case review
}

class SetupCoordinator: ObservableObject {
    @Published var currentStep: SetupStep = .groups
    @Published var isSetupComplete = false
    @Published var setupGroups: [SetupGroup] = []
    @Published var selectedCategories = Set<UUID>()
    @Published var setupAccounts: [SetupAccount] = []
    @Published var currentGroup: SetupGroup?
    @Published var currentGroupIndex: Int = 0
    
    var isLastGroup: Bool {
        currentGroupIndex == setupGroups.count - 1
    }
    
    func setInitialGroups(_ groups: [SetupGroup]) {
        setupGroups = groups
        currentGroupIndex = 0
        currentGroup = groups.first
        
        selectedCategories = Set(groups.flatMap { group in
            group.categories.map { $0.id }
        })
    }
    
    func moveToNextGroup() {
        if currentGroupIndex < setupGroups.count - 1 {
            currentGroupIndex += 1
            currentGroup = setupGroups[currentGroupIndex]
        }
    }
    
    func moveToPreviousGroup() {
        if currentGroupIndex > 0 {
            currentGroupIndex -= 1
            currentGroup = setupGroups[currentGroupIndex]
        }
    }
    
    func cancelSetup() {
        currentStep = .groups
        setupGroups.removeAll()
        selectedCategories.removeAll()
        setupAccounts.removeAll()
        currentGroup = nil
        currentGroupIndex = 0
        isSetupComplete = false
    }
    
    func reset() {
        cancelSetup()
    }
    
    func moveToPreviousStep() {
        switch currentStep {
        case .groups:
            break // First step, do nothing
        case .categories:
            currentStep = .groups
            currentGroupIndex = 0
        case .accounts:
            currentStep = .categories
        case .review:
            currentStep = .accounts
        }
    }
} 
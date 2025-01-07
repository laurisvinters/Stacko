import SwiftUI

class SetupCoordinator: ObservableObject {
    @Published var currentStep: SetupStep = .groups
    @Published var isSetupComplete: Bool = false {
        didSet {
            if isSetupComplete {
                if let userId = UserDefaults.standard.string(forKey: "currentUserId") {
                    UserDefaults.standard.set(true, forKey: "hasCompletedSetup-\(userId)")
                }
            }
        }
    }
    
    @Published var selectedGroups: [UUID] = []
    @Published var currentGroupIndex: Int = 0
    @Published var setupGroups: [SetupGroup] = []
    @Published var selectedCategories: Set<UUID> = []
    
    var currentGroup: SetupGroup? {
        guard currentGroupIndex < setupGroups.count else { return nil }
        return setupGroups[currentGroupIndex]
    }
    
    enum SetupStep {
        case groups
        case categories
        case targets
        case review
    }
    
    func moveToNextGroup() {
        if currentGroupIndex < setupGroups.count - 1 {
            currentGroupIndex += 1
        } else {
            currentStep = .review
        }
    }
    
    func moveToPreviousGroup() {
        if currentGroupIndex > 0 {
            currentGroupIndex -= 1
        } else {
            currentStep = .groups
        }
    }
    
    func reset() {
        currentStep = .groups
        selectedGroups = []
        setupGroups = []
        currentGroupIndex = 0
        selectedCategories.removeAll()
        isSetupComplete = false
    }
    
    init() {
        if let userId = UserDefaults.standard.string(forKey: "currentUserId") {
            self.isSetupComplete = UserDefaults.standard.bool(forKey: "hasCompletedSetup-\(userId)")
        }
    }
    
    var isLastGroup: Bool {
        currentGroupIndex == setupGroups.count - 1
    }
} 
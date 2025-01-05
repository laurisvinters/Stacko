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
    
    var currentGroup: SetupGroup? {
        guard currentGroupIndex < setupGroups.count else { return nil }
        return setupGroups[currentGroupIndex]
    }
    
    enum SetupStep: Int, CaseIterable {
        case groups
        case categories
        case review
        
        var title: String {
            switch self {
            case .groups: return "Setup Groups"
            case .categories: return "Setup Categories"
            case .review: return "Review"
            }
        }
    }
    
    func moveToNextGroup() {
        if currentGroupIndex < setupGroups.count - 1 {
            currentGroupIndex += 1
        } else {
            currentStep = .review
        }
    }
    
    func reset() {
        currentStep = .groups
        selectedGroups = []
        setupGroups = []
        currentGroupIndex = 0
        isSetupComplete = false
    }
    
    init() {
        if let userId = UserDefaults.standard.string(forKey: "currentUserId") {
            self.isSetupComplete = UserDefaults.standard.bool(forKey: "hasCompletedSetup-\(userId)")
        }
    }
} 
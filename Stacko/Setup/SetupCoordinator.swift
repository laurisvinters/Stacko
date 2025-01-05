import SwiftUI

class SetupCoordinator: ObservableObject {
    @Published var currentStep: SetupStep = .categoriesAndGroups
    @Published var isSetupComplete: Bool {
        didSet {
            if isSetupComplete {
                // Store setup completion for specific user
                if let userId = UserDefaults.standard.string(forKey: "currentUserId") {
                    UserDefaults.standard.set(true, forKey: "hasCompletedSetup-\(userId)")
                }
            }
        }
    }
    
    init() {
        // Check setup status for current user
        if let userId = UserDefaults.standard.string(forKey: "currentUserId") {
            self.isSetupComplete = UserDefaults.standard.bool(forKey: "hasCompletedSetup-\(userId)")
        } else {
            self.isSetupComplete = false
        }
    }
    
    // Add method to reset setup status when signing out
    func reset() {
        isSetupComplete = false
    }
    
    enum SetupStep: Int, CaseIterable {
        case categoriesAndGroups
        
        var title: String {
            switch self {
            case .categoriesAndGroups:
                return "Categories"
            }
        }
    }
} 
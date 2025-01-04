import SwiftUI

class SetupCoordinator: ObservableObject {
    @Published var currentStep: SetupStep = .categoriesAndGroups
    @Published var isSetupComplete = false
    
    enum SetupStep: Int, CaseIterable {
        case categoriesAndGroups
        // More steps will be added later
        
        var title: String {
            switch self {
            case .categoriesAndGroups:
                return "Categories"
            }
        }
    }
} 
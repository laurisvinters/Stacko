import SwiftUI

struct SetupContainerView: View {
    @ObservedObject var budget: Budget
    @ObservedObject var coordinator: SetupCoordinator
    @ObservedObject var authManager: AuthenticationManager
    
    var body: some View {
        NavigationStack {
            Group {
                switch coordinator.currentStep {
                case .modeSelection:
                    SetupModeSelectionView(coordinator: coordinator, authManager: authManager)
                case .groups:
                    GroupSetupView(budget: budget, coordinator: coordinator, authManager: authManager)
                case .categories:
                    CategoriesSetupView(budget: budget, coordinator: coordinator)
                case .accounts:
                    AccountsSetupView(coordinator: coordinator, budget: budget)
                case .targets:
                    CategoryTargetsSetupView(budget: budget, coordinator: coordinator)
                case .review:
                    ReviewSetupView(budget: budget, coordinator: coordinator)
                }
            }
        }
    }
}

#Preview {
    let budget = Budget()
    let coordinator = SetupCoordinator()
    let authManager = AuthenticationManager(
        budget: budget,
        setupCoordinator: coordinator
    )
    
    SetupContainerView(
        budget: budget,
        coordinator: coordinator,
        authManager: authManager
    )
} 
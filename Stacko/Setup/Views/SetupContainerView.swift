import SwiftUI

struct SetupContainerView: View {
    @ObservedObject var budget: Budget
    @ObservedObject var coordinator: SetupCoordinator
    @ObservedObject var authManager: AuthenticationManager
    
    var body: some View {
        NavigationStack {
            Group {
                switch coordinator.currentStep {
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
    let dataController = DataController()
    let budget = Budget(dataController: dataController)
    let coordinator = SetupCoordinator()
    let authManager = AuthenticationManager(
        dataController: dataController,
        budget: budget,
        setupCoordinator: coordinator
    )
    
    return SetupContainerView(
        budget: budget,
        coordinator: coordinator,
        authManager: authManager
    )
} 
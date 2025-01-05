import SwiftUI

struct SetupContainerView: View {
    @ObservedObject var budget: Budget
    @ObservedObject var coordinator: SetupCoordinator
    
    var body: some View {
        NavigationStack {
            Group {
                switch coordinator.currentStep {
                case .groups:
                    GroupSetupView(budget: budget, coordinator: coordinator)
                case .categories:
                    CategoriesSetupView(budget: budget, coordinator: coordinator)
                case .review:
                    ReviewSetupView(budget: budget, coordinator: coordinator)
                }
            }
        }
    }
}

#Preview {
    SetupContainerView(
        budget: Budget(dataController: DataController()),
        coordinator: SetupCoordinator()
    )
} 
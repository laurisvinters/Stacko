import SwiftUI

struct MainView: View {
    @ObservedObject var authManager: AuthenticationManager
    @ObservedObject var budget: Budget
    @ObservedObject var setupCoordinator: SetupCoordinator
    
    var body: some View {
        if setupCoordinator.isSetupComplete || !budget.categoryGroups.isEmpty {
            // Regular app content
            TabView {
                NavigationStack {
                    BudgetView(budget: budget)
                }
                .tabItem {
                    Label("Budget", systemImage: "dollarsign.circle")
                }
                
                NavigationStack {
                    AccountsView(budget: budget)
                }
                .tabItem {
                    Label("Accounts", systemImage: "creditcard")
                }
                
                NavigationStack {
                    TransactionsView(budget: budget)
                }
                .tabItem {
                    Label("Transactions", systemImage: "list.bullet")
                }
                
                NavigationStack {
                    ReportsView(budget: budget)
                }
                .tabItem {
                    Label("Reports", systemImage: "chart.bar")
                }
                
                NavigationStack {
                    ProfileView(authManager: authManager)
                }
                .tabItem {
                    Label("Profile", systemImage: "person.circle")
                }
            }
        } else {
            // Setup flow
            SetupContainerView(
                budget: budget, 
                coordinator: setupCoordinator,
                authManager: authManager
            )
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
    
    MainView(
        authManager: authManager,
        budget: budget,
        setupCoordinator: coordinator
    )
} 
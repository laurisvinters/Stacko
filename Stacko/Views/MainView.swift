import SwiftUI

struct MainView: View {
    @ObservedObject var authManager: AuthenticationManager
    @ObservedObject var budget: Budget
    @ObservedObject var setupCoordinator: SetupCoordinator
    
    var body: some View {
        Group {
            if budget.isSetupComplete == nil {
                // Loading state
                ProgressView()
            } else if budget.isSetupComplete == false {
                // Setup flow
                SetupContainerView(
                    budget: budget, 
                    coordinator: setupCoordinator,
                    authManager: authManager
                )
            } else {
                // Regular app content
                TabView {
                    NavigationStack {
                        BudgetView(budget: budget)
                            .toolbar {
                                ToolbarItem(placement: .navigationBarTrailing) {
                                    NavigationLink {
                                        ProfileView(authManager: authManager)
                                    } label: {
                                        Label("Profile", systemImage: "person.circle")
                                    }
                                }
                            }
                    }
                    .tabItem {
                        Label("Budget", systemImage: "dollarsign.circle")
                    }
                    
                    NavigationStack {
                        AccountsView(budget: budget)
                            .toolbar {
                                ToolbarItem(placement: .navigationBarTrailing) {
                                    NavigationLink {
                                        ProfileView(authManager: authManager)
                                    } label: {
                                        Label("Profile", systemImage: "person.circle")
                                    }
                                }
                            }
                    }
                    .tabItem {
                        Label("Accounts", systemImage: "creditcard")
                    }
                    
                    NavigationStack {
                        TransactionsView(budget: budget)
                            .toolbar {
                                ToolbarItem(placement: .navigationBarTrailing) {
                                    NavigationLink {
                                        ProfileView(authManager: authManager)
                                    } label: {
                                        Label("Profile", systemImage: "person.circle")
                                    }
                                }
                            }
                    }
                    .tabItem {
                        Label("Transactions", systemImage: "list.bullet")
                    }
                    
                    NavigationStack {
                        ReportsView(budget: budget)
                            .toolbar {
                                ToolbarItem(placement: .navigationBarTrailing) {
                                    NavigationLink {
                                        ProfileView(authManager: authManager)
                                    } label: {
                                        Label("Profile", systemImage: "person.circle")
                                    }
                                }
                            }
                    }
                    .tabItem {
                        Label("Reports", systemImage: "chart.bar")
                    }
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
    
    MainView(
        authManager: authManager,
        budget: budget,
        setupCoordinator: coordinator
    )
} 
import SwiftUI

struct MainView: View {
    @ObservedObject var authManager: AuthenticationManager
    @ObservedObject var budget: Budget
    @ObservedObject var setupCoordinator: SetupCoordinator
    @State private var showingAddTransaction = false
    @State private var selectedTab = 0
    @State private var previousTab = 0  // Add this to track the previous tab
    
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
                TabView(selection: $selectedTab) {
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
                    .tag(0)
                    
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
                    .tag(1)
                    
                    // Add Transaction Tab
                    Color.clear
                        .tabItem {
                            Label("Add", systemImage: "plus.circle.fill")
                        }
                        .tag(2)
                    
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
                    .tag(3)
                    
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
                    .tag(4)
                }
                .onChange(of: selectedTab) { newTab in
                    if newTab == 2 {
                        showingAddTransaction = true
                        selectedTab = previousTab  // Return to the previous tab
                    } else {
                        previousTab = newTab  // Store the new tab as previous
                    }
                }
                .sheet(isPresented: $showingAddTransaction) {
                    QuickAddTransactionSheet(budget: budget)
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
    
    return MainView(
        authManager: authManager,
        budget: budget,
        setupCoordinator: coordinator
    )
}

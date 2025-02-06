import SwiftUI

struct MainView: View {
    @ObservedObject var authManager: AuthenticationManager
    @ObservedObject var budget: Budget
    @ObservedObject var setupCoordinator: SetupCoordinator
    @State private var showingAddTransaction = false
    @State private var selectedTab = 0
    @State private var previousTab = 0
    @State private var isEditing = false
    @State private var showingProfile = false
    
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
                        BudgetView(budget: budget, isEditing: $isEditing)
                            .toolbar {
                                ToolbarItem(placement: .navigationBarTrailing) {
                                    if !isEditing {
                                        Button {
                                            showingProfile = true
                                        } label: {
                                            Label("Profile", systemImage: "person.circle")
                                        }
                                    }
                                }
                            }
                    }
                    .tabItem {
                        Label("Budget", systemImage: "dollarsign.circle")
                            .environment(\.symbolVariants, .none)
                            .font(.system(size: 18))
                    }
                    .tag(0)
                    
                    NavigationStack {
                        AccountsView(budget: budget)
                            .toolbar {
                                ToolbarItem(placement: .navigationBarTrailing) {
                                    if !isEditing {
                                        Button {
                                            showingProfile = true
                                        } label: {
                                            Label("Profile", systemImage: "person.circle")
                                        }
                                    }
                                }
                            }
                    }
                    .tabItem {
                        Label("Accounts", systemImage: "creditcard")
                            .environment(\.symbolVariants, .none)
                            .font(.system(size: 18))
                    }
                    .tag(1)
                    
                    // Add Transaction Tab
                    Color.clear
                        .tabItem {
                            Label("Add", systemImage: "plus.circle.fill")
                                .environment(\.symbolVariants, .fill)
                                .font(.system(size: 22))
                        }
                        .tag(2)
                    
                    NavigationStack {
                        TransactionsView(budget: budget)
                            .toolbar {
                                ToolbarItem(placement: .navigationBarTrailing) {
                                    if !isEditing {
                                        Button {
                                            showingProfile = true
                                        } label: {
                                            Label("Profile", systemImage: "person.circle")
                                        }
                                    }
                                }
                            }
                    }
                    .tabItem {
                        Label("Transactions", systemImage: "list.bullet")
                            .environment(\.symbolVariants, .none)
                            .font(.system(size: 18))
                    }
                    .tag(3)
                    
                    NavigationStack {
                        ReportsView(budget: budget)
                            .toolbar {
                                ToolbarItem(placement: .navigationBarTrailing) {
                                    if !isEditing {
                                        Button {
                                            showingProfile = true
                                        } label: {
                                            Label("Profile", systemImage: "person.circle")
                                        }
                                    }
                                }
                            }
                    }
                    .tabItem {
                        Label("Reports", systemImage: "chart.bar")
                            .environment(\.symbolVariants, .none)
                            .font(.system(size: 18))
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
                .fullScreenCover(isPresented: $showingProfile) {
                    NavigationStack {
                        ProfileView(authManager: authManager)
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
    
    return MainView(
        authManager: authManager,
        budget: budget,
        setupCoordinator: coordinator
    )
}

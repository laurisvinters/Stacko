import SwiftUI

struct MainView: View {
    @ObservedObject var authManager: AuthenticationManager
    @ObservedObject var budget: Budget
    
    var body: some View {
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
    }
} 
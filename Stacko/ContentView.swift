//
//  ContentView.swift
//  Stacko
//
//  Created by Lauris Vinters on 01/01/2025.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var budget = Budget()
    
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
        }
    }
}

#Preview {
    ContentView()
}

//
//  ContentView.swift
//  Stacko
//
//  Created by Lauris Vinters on 01/01/2025.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject var authManager: AuthenticationManager
    @ObservedObject var budget: Budget
    
    var body: some View {
        Group {
            if authManager.currentUser != nil {
                MainView(authManager: authManager, budget: budget)
            } else {
                SignInView(authManager: authManager)
            }
        }
        .environment(\.managedObjectContext, budget.dataController.container.viewContext)
    }
}

#Preview {
    let dataController = DataController()
    let budget = Budget(dataController: dataController)
    let authManager = AuthenticationManager(dataController: dataController, budget: budget)
    
    return ContentView(authManager: authManager, budget: budget)
}

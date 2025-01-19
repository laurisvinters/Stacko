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
    @ObservedObject var setupCoordinator: SetupCoordinator
    
    var body: some View {
        Group {
            if authManager.currentUser != nil {
                MainView(
                    authManager: authManager,
                    budget: budget,
                    setupCoordinator: setupCoordinator
                )
            } else {
                SignInView(authManager: authManager)
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
    
    ContentView(
        authManager: authManager,
        budget: budget,
        setupCoordinator: coordinator
    )
}
  

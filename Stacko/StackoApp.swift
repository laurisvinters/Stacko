//
//  StackoApp.swift
//  Stacko
//
//  Created by Lauris Vinters on 01/01/2025.
//

import SwiftUI
import FirebaseCore

@main
struct StackoApp: App {
    @StateObject private var budget = Budget()
    @StateObject private var setupCoordinator = SetupCoordinator()
    @StateObject private var authManager: AuthenticationManager
    
    init() {
        // Configure Firebase
        FirebaseApp.configure()
        
        let budgetInstance = Budget()
        let coordinator = SetupCoordinator()
        
        _budget = StateObject(wrappedValue: budgetInstance)
        _setupCoordinator = StateObject(wrappedValue: coordinator)
        _authManager = StateObject(wrappedValue: AuthenticationManager(
            budget: budgetInstance,
            setupCoordinator: coordinator
        ))
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView(
                authManager: authManager,
                budget: budget,
                setupCoordinator: setupCoordinator
            )
        }
    }
}

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
    private let budget: Budget
    private let setupCoordinator: SetupCoordinator
    @StateObject private var themeManager = ThemeManager()
    @StateObject private var authManager: AuthenticationManager
    
    init() {
        // Configure Firebase
        FirebaseApp.configure()
        
        // Create instances first
        self.budget = Budget()
        self.setupCoordinator = SetupCoordinator()
        
        // Then initialize auth manager with those instances
        let auth = AuthenticationManager(
            budget: self.budget,
            setupCoordinator: self.setupCoordinator
        )
        _authManager = StateObject(wrappedValue: auth)
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView(
                authManager: authManager,
                budget: budget,
                setupCoordinator: setupCoordinator
            )
            .environmentObject(themeManager)
            .preferredColorScheme(themeManager.colorScheme)
        }
    }
}

//
//  StackoApp.swift
//  Stacko
//
//  Created by Lauris Vinters on 01/01/2025.
//

import SwiftUI

@main
struct StackoApp: App {
    @StateObject private var dataController = DataController()
    @StateObject private var budget: Budget
    @StateObject private var setupCoordinator = SetupCoordinator()
    @StateObject private var authManager: AuthenticationManager
    
    init() {
        let controller = DataController()
        let budgetInstance = Budget(dataController: controller)
        let coordinator = SetupCoordinator()
        
        _dataController = StateObject(wrappedValue: controller)
        _budget = StateObject(wrappedValue: budgetInstance)
        _setupCoordinator = StateObject(wrappedValue: coordinator)
        _authManager = StateObject(wrappedValue: AuthenticationManager(
            dataController: controller,
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
            .environment(\.managedObjectContext, dataController.container.viewContext)
        }
    }
}

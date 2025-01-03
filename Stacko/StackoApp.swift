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
    @StateObject private var authManager: AuthenticationManager
    
    init() {
        let controller = DataController()
        let budgetInstance = Budget(dataController: controller)
        
        _dataController = StateObject(wrappedValue: controller)
        _budget = StateObject(wrappedValue: budgetInstance)
        _authManager = StateObject(wrappedValue: AuthenticationManager(
            dataController: controller,
            budget: budgetInstance
        ))
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView(authManager: authManager, budget: budget)
                .environment(\.managedObjectContext, dataController.container.viewContext)
        }
    }
}

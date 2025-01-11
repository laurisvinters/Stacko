//
//  StackoApp.swift
//  Stacko
//
//  Created by Lauris Vinters on 01/01/2025.
//

import SwiftUI
import FirebaseCore

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()
        return true
    }
}

@main
struct StackoApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
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

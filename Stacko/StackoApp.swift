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
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, dataController.container.viewContext)
        }
    }
}

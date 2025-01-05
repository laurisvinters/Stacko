import SwiftUI

struct ReviewSetupView: View {
    @ObservedObject var budget: Budget
    @ObservedObject var coordinator: SetupCoordinator
    
    var body: some View {
        List {
            Section {
                Text("Review your categories before continuing.")
                    .foregroundStyle(.secondary)
            }
            
            ForEach(coordinator.setupGroups) { group in
                Section(group.name) {
                    ForEach(group.categories) { category in
                        HStack {
                            Text(category.emoji)
                            Text(category.name)
                        }
                    }
                }
            }
        }
        .navigationTitle("Review Setup")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Complete Setup") {
                    saveSetup()
                }
            }
        }
    }
    
    private func saveSetup() {
        // Save all groups and categories to Core Data
        for group in coordinator.setupGroups {
            let createdGroup = budget.addCategoryGroup(name: group.name, emoji: nil)
            
            for category in group.categories {
                budget.addCategory(
                    name: category.name,
                    emoji: category.emoji,
                    groupId: createdGroup.id,
                    target: category.target
                )
            }
        }
        
        coordinator.isSetupComplete = true
    }
} 
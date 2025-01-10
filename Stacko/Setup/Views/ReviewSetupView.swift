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
                    ForEach(group.categories.filter { coordinator.selectedCategories.contains($0.id) }) { category in
                        HStack {
                            Text(category.emoji)
                            Text(category.name)
                            
                            if let target = category.target {
                                Spacer()
                                Group {
                                    switch target.type {
                                    case .monthly(let amount):
                                        Text("Monthly: \(amount, format: .currency(code: "USD"))")
                                    case .weekly(let amount):
                                        Text("Weekly: \(amount, format: .currency(code: "USD"))")
                                    case .byDate(let amount, let date):
                                        Text("\(amount, format: .currency(code: "USD")) by \(date.formatted(date: .abbreviated, time: .omitted))")
                                    }
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Review Setup")
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    coordinator.moveToPreviousStep()
                }) {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                }
            }
            
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
            
            // Only save selected categories
            for category in group.categories where coordinator.selectedCategories.contains(category.id) {
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
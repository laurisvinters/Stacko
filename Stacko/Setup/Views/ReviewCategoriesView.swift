import SwiftUI

struct ReviewCategoriesView: View {
    @ObservedObject var budget: Budget
    @ObservedObject var coordinator: SetupCoordinator
    @Environment(\.dismiss) private var dismiss
    
    let selectedGroups: Set<UUID>
    let selectedCategories: Set<UUID>
    let suggestedGroups: [SuggestedGroup]
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Review your selected categories before continuing.")
                        .foregroundStyle(.secondary)
                }
                
                ForEach(suggestedGroups.filter { selectedGroups.contains($0.id) }) { group in
                    Section(group.name) {
                        ForEach(group.categories.filter { selectedCategories.contains($0.id) }) { category in
                            HStack {
                                Text(category.emoji)
                                Text(category.name)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Review Categories")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Back") { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Continue") {
                        saveSelectedCategories()
                    }
                }
            }
        }
    }
    
    private func saveSelectedCategories() {
        for group in suggestedGroups where selectedGroups.contains(group.id) {
            // Add group without emoji
            let createdGroupId = budget.addCategoryGroup(name: group.name, emoji: nil).id
            
            // Add selected categories for this group
            for category in group.categories where selectedCategories.contains(category.id) {
                budget.addCategory(
                    name: category.name,
                    emoji: category.emoji,
                    groupId: createdGroupId,
                    target: category.target
                )
            }
        }
        
        coordinator.isSetupComplete = true
        dismiss()
    }
} 
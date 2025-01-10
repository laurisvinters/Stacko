import SwiftUI

struct SetupCategoriesView: View {
    @ObservedObject var budget: Budget
    @ObservedObject var coordinator: SetupCoordinator
    @State private var selectedCategoryForEdit: SetupCategory?
    @State private var showingCancelAlert = false
    
    var body: some View {
        List {
            if let currentGroup = coordinator.currentGroup {
                Section {
                    Text("Select categories for \(currentGroup.name)")
                        .foregroundStyle(.secondary)
                }
                
                Section {
                    ForEach(currentGroup.categories) { category in
                        SetupCategoryRow(
                            category: category,
                            isSelected: coordinator.selectedCategories.contains(category.id),
                            onTap: {
                                toggleCategory(category.id)
                            },
                            onReview: {
                                selectedCategoryForEdit = category
                            }
                        )
                    }
                }
            }
        }
        .navigationTitle("Setup Categories")
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                if coordinator.currentGroupIndex > 0 {
                    Button(action: {
                        coordinator.moveToPreviousGroup()
                    }) {
                        HStack {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                    }
                } else {
                    Button("Cancel") {
                        showingCancelAlert = true
                    }
                }
            }
            
            ToolbarItem(placement: .primaryAction) {
                Button(coordinator.isLastGroup ? "Next" : "Next Group") {
                    if coordinator.isLastGroup {
                        coordinator.currentStep = .targets
                    } else {
                        coordinator.moveToNextGroup()
                    }
                }
            }
        }
        .alert("Cancel Setup", isPresented: $showingCancelAlert) {
            Button("Continue Setup", role: .cancel) { }
            Button("Cancel Setup", role: .destructive) {
                coordinator.cancelSetup()
            }
        } message: {
            Text("Are you sure you want to cancel the setup process? All progress will be lost.")
        }
        .sheet(item: $selectedCategoryForEdit) { category in
            EditCategorySheet(category: category) { newName, newEmoji in
                updateCategory(id: category.id, name: newName, emoji: newEmoji)
            }
        }
    }
    
    private func toggleCategory(_ id: UUID) {
        if coordinator.selectedCategories.contains(id) {
            coordinator.selectedCategories.remove(id)
        } else {
            coordinator.selectedCategories.insert(id)
        }
    }
    
    private func updateCategory(id: UUID, name: String, emoji: String) {
        guard var currentGroup = coordinator.currentGroup else { return }
        
        if let index = currentGroup.categories.firstIndex(where: { $0.id == id }) {
            let updatedCategory = SetupCategory(
                id: id,
                name: name,
                emoji: emoji,
                target: nil
            )
            currentGroup.categories[index] = updatedCategory
            
            if let groupIndex = coordinator.setupGroups.firstIndex(where: { $0.id == currentGroup.id }) {
                coordinator.setupGroups[groupIndex] = currentGroup
            }
        }
    }
}

#Preview {
    NavigationStack {
        SetupCategoriesView(
            budget: Budget(dataController: DataController()),
            coordinator: SetupCoordinator()
        )
    }
}

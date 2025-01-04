import SwiftUI

// Move types outside to make them accessible
struct SuggestedCategory: Identifiable {
    let id = UUID()
    let name: String
    let emoji: String
    let target: Target?
}

struct SuggestedGroup: Identifiable {
    let id: UUID
    let name: String
    let emoji: String
    let categories: [SuggestedCategory]
    
    init(id: UUID = UUID(), name: String, emoji: String, categories: [SuggestedCategory]) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.categories = categories
    }
}

// Wrapper for UUID to make it Identifiable
struct IdentifiableUUID: Identifiable {
    let id: UUID
}

struct CategoryGroupRow: View {
    let group: SuggestedGroup
    let isSelected: Bool
    @Binding var selectedCategories: Set<UUID>
    let onGroupSelect: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Group header with selection button
            HStack(spacing: 12) {
                Button(action: onGroupSelect) {
                    HStack(spacing: 8) {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(isSelected ? .blue : .secondary)
                            .imageScale(.large)
                        
                        Text(group.emoji)
                        
                        Text(group.name)
                            .font(.headline)
                    }
                }
                .buttonStyle(.plain)
            }
            .frame(height: 36)
            
            if isSelected {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(group.categories) { category in
                        SetupCategoryRow(
                            category: category,
                            isSelected: selectedCategories.contains(category.id)
                        ) {
                            if selectedCategories.contains(category.id) {
                                selectedCategories.remove(category.id)
                            } else {
                                selectedCategories.insert(category.id)
                            }
                        }
                    }
                }
                .padding(.leading, 32)
            }
        }
        .padding(.vertical, 2)
    }
}

struct SetupCategoryRow: View {
    let category: SuggestedCategory
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? .blue : .secondary)
                    .imageScale(.small)
                
                Text(category.emoji)
                
                Text(category.name)
                    .foregroundStyle(.primary)
                
                Spacer()
            }
        }
        .buttonStyle(.plain)
        .frame(height: 32)
    }
}

struct CategoriesSetupView: View {
    @ObservedObject var budget: Budget
    @ObservedObject var coordinator: SetupCoordinator
    @State private var selectedGroups: Set<UUID> = []
    @State private var selectedCategories: Set<UUID> = []
    @State private var showingAddGroup = false
    @State private var showingReview = false
    
    // Create static constants for suggested groups
    private let housingGroup = SuggestedGroup(
        name: "Housing",
        emoji: "🏠",
        categories: [
            SuggestedCategory(name: "Rent/Mortgage", emoji: "🏘️", target: nil),
            SuggestedCategory(name: "Utilities", emoji: "💡", target: nil),
            SuggestedCategory(name: "Maintenance", emoji: "🔧", target: nil)
        ]
    )
    
    private let transportationGroup = SuggestedGroup(
        name: "Transportation",
        emoji: "🚗",
        categories: [
            SuggestedCategory(name: "Fuel", emoji: "⛽", target: nil),
            SuggestedCategory(name: "Public Transit", emoji: "🚌", target: nil),
            SuggestedCategory(name: "Car Maintenance", emoji: "🔧", target: nil)
        ]
    )
    
    // Add state for custom groups
    @State private var customGroups: [CategoryGroup] = []
    
    private var allGroups: [SuggestedGroup] {
        // Combine suggested and custom groups
        suggestedGroups + customGroups.map { group in
            SuggestedGroup(
                id: group.id,
                name: group.name,
                emoji: group.emoji ?? "📁",
                categories: group.categories.map { category in
                    SuggestedCategory(
                        name: category.name,
                        emoji: category.emoji ?? "🏷️",
                        target: nil
                    )
                }
            )
        }
    }
    
    private let suggestedGroups: [SuggestedGroup]
    
    init(budget: Budget, coordinator: SetupCoordinator) {
        self.budget = budget
        self.coordinator = coordinator
        self.suggestedGroups = [housingGroup, transportationGroup]
        // Load existing custom groups
        self._customGroups = State(initialValue: budget.categoryGroups)
    }
    
    var body: some View {
        NavigationStack {
            List {
                introSection
                suggestedCategoriesSection
                customGroupSection
            }
            .navigationTitle("Setup Categories")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Review") {
                        showingReview = true
                    }
                    .disabled(selectedCategories.isEmpty)
                }
            }
            .sheet(isPresented: $showingAddGroup) {
                AddGroupSheet(budget: budget, onAdd: { newGroup in
                    customGroups.append(newGroup)
                    selectedGroups.insert(newGroup.id)
                })
            }
            .sheet(isPresented: $showingReview) {
                ReviewCategoriesView(
                    budget: budget,
                    coordinator: coordinator,
                    selectedGroups: selectedGroups,
                    selectedCategories: selectedCategories,
                    suggestedGroups: allGroups
                )
            }
        }
    }
    
    private var introSection: some View {
        Section {
            Text("Choose categories to track your spending or create your own.")
                .foregroundStyle(.secondary)
        }
    }
    
    private var suggestedCategoriesSection: some View {
        Section("Suggested Categories") {
            ForEach(suggestedGroups) { group in
                CategoryGroupRow(
                    group: group,
                    isSelected: selectedGroups.contains(group.id),
                    selectedCategories: $selectedCategories,
                    onGroupSelect: { toggleGroup(group.id) }
                )
            }
        }
    }
    
    private var customGroupSection: some View {
        Section {
            Button {
                showingAddGroup = true
            } label: {
                Label("Add Custom Group", systemImage: "folder.badge.plus")
            }
        }
    }
    
    private func toggleGroup(_ id: UUID) {
        if selectedGroups.contains(id) {
            selectedGroups.remove(id)
        } else {
            selectedGroups.insert(id)
        }
    }
}

// Preview provider
#Preview {
    CategoriesSetupView(
        budget: Budget(dataController: DataController()),
        coordinator: SetupCoordinator()
    )
} 
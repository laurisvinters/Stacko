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
    let categories: [SuggestedCategory]
    
    init(id: UUID = UUID(), name: String, categories: [SuggestedCategory]) {
        self.id = id
        self.name = name
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
    let onAddCategory: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Button(action: onGroupSelect) {
                    HStack(spacing: 8) {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(isSelected ? .blue : .secondary)
                            .imageScale(.large)
                        
                        Text(group.name)
                            .font(.headline)
                    }
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                if isSelected {
                    Button(action: onAddCategory) {
                        Image(systemName: "plus.circle")
                            .foregroundStyle(.blue)
                    }
                }
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
    @State private var customGroups: [SuggestedGroup] = []
    
    // Add static suggested groups
    private static let suggestedGroups = [
        SuggestedGroup(
            name: "Housing",
            categories: [
                SuggestedCategory(name: "Rent/Mortgage", emoji: "🏘️", target: nil),
                SuggestedCategory(name: "Utilities", emoji: "💡", target: nil),
                SuggestedCategory(name: "Maintenance", emoji: "🔧", target: nil)
            ]
        ),
        SuggestedGroup(
            name: "Transportation",
            categories: [
                SuggestedCategory(name: "Fuel", emoji: "⛽", target: nil),
                SuggestedCategory(name: "Public Transit", emoji: "🚌", target: nil),
                SuggestedCategory(name: "Car Maintenance", emoji: "🔧", target: nil)
            ]
        )
    ]
    
    private var allGroups: [SuggestedGroup] {
        // Make sure custom groups appear after suggested groups
        Self.suggestedGroups + customGroups
    }
    
    init(budget: Budget, coordinator: SetupCoordinator) {
        self.budget = budget
        self.coordinator = coordinator
    }
    
    // Change UUID to IdentifiableUUID for sheet presentation
    @State private var selectedGroupForCategory: IdentifiableUUID?
    
    private func showAddCategory(for groupId: UUID) {
        selectedGroupForCategory = IdentifiableUUID(id: groupId)
    }
    
    var body: some View {
        NavigationStack {
            List {
                introSection
                
                // Combined section for all groups
                Section("Categories") {
                    ForEach(allGroups) { group in
                        CategoryGroupRow(
                            group: group,
                            isSelected: selectedGroups.contains(group.id),
                            selectedCategories: $selectedCategories,
                            onGroupSelect: { toggleGroup(group.id) },
                            onAddCategory: {
                                showAddCategory(for: group.id)
                            }
                        )
                    }
                }
                
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
                AddGroupSheet(budget: budget) { newGroup in
                    let suggestedGroup = SuggestedGroup(
                        id: newGroup.id,
                        name: newGroup.name,
                        categories: []
                    )
                    customGroups.append(suggestedGroup)
                    selectedGroups.insert(newGroup.id)
                    budget.deleteGroup(newGroup.id)
                }
            }
            .sheet(item: $selectedGroupForCategory) { wrapper in
                SetupAddCategorySheet(budget: budget) { name, emoji in
                    addCategory(name: name, emoji: emoji, to: wrapper.id)
                }
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
    
    private func addCategory(name: String, emoji: String, to groupId: UUID) {
        if let groupIndex = customGroups.firstIndex(where: { $0.id == groupId }) {
            let newCategory = SuggestedCategory(
                name: name,
                emoji: emoji,
                target: nil
            )
            // Create a new group with updated categories
            let updatedGroup = customGroups[groupIndex]
            var updatedCategories = updatedGroup.categories
            updatedCategories.append(newCategory)
            
            // Create new group with updated categories
            let newGroup = SuggestedGroup(
                id: updatedGroup.id,
                name: updatedGroup.name,
                categories: updatedCategories
            )
            
            // Replace old group with updated one
            customGroups[groupIndex] = newGroup
            
            // Auto-select the new category
            selectedCategories.insert(newCategory.id)
        }
    }
    
    private var introSection: some View {
        Section {
            Text("Choose categories to track your spending or create your own.")
                .foregroundStyle(.secondary)
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

// Rename to SetupAddCategorySheet to avoid conflict
struct SetupAddCategorySheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var budget: Budget
    let onAdd: (String, String) -> Void
    
    @State private var name = ""
    @State private var selectedEmoji = "🎯"
    
    private let suggestedEmojis = [
        "🎯", "💰", "🏠", "🚗", "🍽️", "🛒", "💊", "🎮",
        "👕", "✈️", "📱", "🎓", "🎁", "🏋️", "🎬", "📚"
    ]
    
    var body: some View {
        NavigationStack {
            Form {
                TextField("Category Name", text: $name)
                
                Section("Choose Icon") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))], spacing: 10) {
                        ForEach(suggestedEmojis, id: \.self) { emoji in
                            Button(action: { selectedEmoji = emoji }) {
                                Text(emoji)
                                    .font(.title2)
                                    .padding(8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(selectedEmoji == emoji ? 
                                                  Color.accentColor.opacity(0.2) : 
                                                  Color.clear)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("New Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        onAdd(name, selectedEmoji)
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
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
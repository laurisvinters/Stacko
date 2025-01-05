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

struct SetupCategoryRow: View {
    let category: SetupCategory
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
    @State private var selectedCategories: Set<UUID> = []
    @State private var showingAddCategory = false
    @State private var selectedGroupForCategory: IdentifiableUUID?
    
    var body: some View {
        List {
            if let currentGroup = coordinator.currentGroup {
                Section {
                    Text("Add categories to \(currentGroup.name)")
                        .foregroundStyle(.secondary)
                }
                
                Section {
                    ForEach(currentGroup.categories) { category in
                        SetupCategoryRow(
                            category: category,
                            isSelected: selectedCategories.contains(category.id)
                        ) {
                            toggleCategory(category.id)
                        }
                    }
                    
                    Button {
                        showingAddCategory = true
                    } label: {
                        Label("Add Category", systemImage: "plus.circle")
                            .frame(height: 44)
                    }
                }
            }
        }
        .navigationTitle("Setup Categories")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Next") {
                    coordinator.moveToNextGroup()
                }
            }
        }
        .sheet(isPresented: $showingAddCategory) {
            SetupAddCategorySheet(budget: budget) { name, emoji in
                addCategory(name: name, emoji: emoji)
            }
        }
    }
    
    private func toggleCategory(_ id: UUID) {
        if selectedCategories.contains(id) {
            selectedCategories.remove(id)
        } else {
            selectedCategories.insert(id)
        }
    }
    
    private func addCategory(name: String, emoji: String) {
        guard var currentGroup = coordinator.currentGroup else { return }
        
        let newCategory = SetupCategory(
            name: name,
            emoji: emoji
        )
        
        currentGroup.categories.append(newCategory)
        selectedCategories.insert(newCategory.id)
        
        // Update the group in coordinator
        if let index = coordinator.setupGroups.firstIndex(where: { $0.id == currentGroup.id }) {
            coordinator.setupGroups[index] = currentGroup
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
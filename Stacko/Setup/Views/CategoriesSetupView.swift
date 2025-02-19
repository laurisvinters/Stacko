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
    let onReview: () -> Void
    
    var body: some View {
        HStack {
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
            
            Button(action: onReview) {
                Image(systemName: "pencil.circle")
                    .foregroundStyle(.blue)
            }
            .buttonStyle(.plain)
        }
        .frame(height: 32)
    }
}

struct CategoriesSetupView: View {
    @ObservedObject var budget: Budget
    @ObservedObject var coordinator: SetupCoordinator
    @State private var showingAddCategory = false
    @State private var selectedCategoryForEdit: SetupCategory?
    
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
                            isSelected: coordinator.selectedCategories.contains(category.id),
                            onTap: { toggleCategory(category.id) },
                            onReview: { selectedCategoryForEdit = category }
                        )
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
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    if coordinator.currentGroupIndex > 0 {
                        coordinator.moveToPreviousGroup()
                    } else {
                        coordinator.moveToPreviousStep()
                    }
                }) {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                }
            }
            
            ToolbarItem(placement: .primaryAction) {
                Button(coordinator.isLastGroup ? "Next" : "Next Group") {
                    if coordinator.isLastGroup {
                        coordinator.currentStep = .targets
                    } else {
                        coordinator.moveToNextGroup()
                        // Select all categories for the new group
                        if let nextGroup = coordinator.currentGroup {
                            coordinator.selectedCategories.formUnion(nextGroup.categories.map { $0.id })
                        }
                    }
                }
            }
        }
        .onAppear {
            // Select all categories by default for the current group
            if let currentGroup = coordinator.currentGroup {
                coordinator.selectedCategories.formUnion(currentGroup.categories.map { $0.id })
            }
        }
        .sheet(isPresented: $showingAddCategory) {
            SetupAddCategorySheet(onAdd: { name, emoji in
                addCategory(name: name, emoji: emoji)
            })
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
    
    private func addCategory(name: String, emoji: String) {
        guard var currentGroup = coordinator.currentGroup else { return }
        
        let newCategory = SetupCategory(
            name: name,
            emoji: emoji
        )
        
        currentGroup.categories.append(newCategory)
        coordinator.selectedCategories.insert(newCategory.id)
        
        // Update the group in coordinator
        if let index = coordinator.setupGroups.firstIndex(where: { $0.id == currentGroup.id }) {
            coordinator.setupGroups[index] = currentGroup
        }
    }
    
    private func updateCategory(id: UUID, name: String, emoji: String) {
        guard var currentGroup = coordinator.currentGroup else { return }
        
        if let index = currentGroup.categories.firstIndex(where: { $0.id == id }) {
            let updatedCategory = SetupCategory(
                id: id,
                name: name,
                emoji: emoji,
                target: nil // Keep target as nil for now
            )
            currentGroup.categories[index] = updatedCategory
            
            // Update the group in coordinator
            if let groupIndex = coordinator.setupGroups.firstIndex(where: { $0.id == currentGroup.id }) {
                coordinator.setupGroups[groupIndex] = currentGroup
            }
        }
    }
}

// Rename to SetupAddCategorySheet to avoid conflict
struct SetupAddCategorySheet: View {
    @Environment(\.dismiss) private var dismiss
    let onAdd: (String, String) -> Void
    
    @State private var name = ""
    @State private var selectedEmoji = "🎯"
    @State private var customEmoji = ""
    @State private var isShowingCustomEmoji = false
    
    var body: some View {
        NavigationStack {
            Form {
                TextField("Category Name", text: $name)
                
                Section("Choose an Emoji") {
                    ScrollView {
                        LazyVGrid(columns: [
                            GridItem(.adaptive(minimum: 44))
                        ], spacing: 8) {
                            ForEach(categoryEmojis, id: \.self) { emoji in
                                Button(action: {
                                    selectedEmoji = emoji
                                    HapticManager.shared.impact()
                                }) {
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
                            
                            // Custom emoji button
                            Button(action: {
                                isShowingCustomEmoji = true
                            }) {
                                Image(systemName: "plus")
                                    .font(.title2)
                                    .padding(8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.secondary, style: StrokeStyle(lineWidth: 1, dash: [5]))
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 8)
                    
                    if isShowingCustomEmoji {
                        TextField("Enter custom emoji", text: $customEmoji)
                            .onChange(of: customEmoji) { oldValue, newValue in
                                if !newValue.isEmpty {
                                    selectedEmoji = String(newValue.prefix(2))
                                }
                            }
                    }
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

// Update EditCategorySheet to remove target functionality
struct EditCategorySheet: View {
    @Environment(\.dismiss) private var dismiss
    let category: SetupCategory
    let onSave: (String, String) -> Void
    
    @State private var name: String
    @State private var selectedEmoji: String
    @State private var customEmoji = ""
    @State private var isShowingCustomEmoji = false
    
    init(category: SetupCategory, onSave: @escaping (String, String) -> Void) {
        self.category = category
        self.onSave = onSave
        _name = State(initialValue: category.name)
        _selectedEmoji = State(initialValue: category.emoji)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                TextField("Category Name", text: $name)
                
                Section("Choose an Emoji") {
                    ScrollView {
                        LazyVGrid(columns: [
                            GridItem(.adaptive(minimum: 44))
                        ], spacing: 8) {
                            ForEach(categoryEmojis, id: \.self) { emoji in
                                Button(action: {
                                    selectedEmoji = emoji
                                    HapticManager.shared.impact()
                                }) {
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
                            
                            // Custom emoji button
                            Button(action: {
                                isShowingCustomEmoji = true
                            }) {
                                Image(systemName: "plus")
                                    .font(.title2)
                                    .padding(8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.secondary, style: StrokeStyle(lineWidth: 1, dash: [5]))
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 8)
                    
                    if isShowingCustomEmoji {
                        TextField("Enter custom emoji", text: $customEmoji)
                            .onChange(of: customEmoji) { oldValue, newValue in
                                if !newValue.isEmpty {
                                    selectedEmoji = String(newValue.prefix(2))
                                }
                            }
                    }
                }
            }
            .navigationTitle("Edit Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(name, selectedEmoji)
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
        budget: Budget(),
        coordinator: SetupCoordinator()
    )
}
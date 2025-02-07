import SwiftUI

struct ManageCategoriesView: View {
    @ObservedObject var budget: Budget
    @State private var editingCategory: Category?
    @State private var showingDeleteAlert = false
    @State private var categoryToDelete: (UUID, UUID)? // (groupId, categoryId)
    
    var body: some View {
        List {
            Text("Swipe right to edit a category, or swipe left to delete it.")
                .font(.caption)
                .foregroundColor(.secondary)
                .listRowSeparator(.hidden)
            
            ForEach(budget.categoryGroups.filter { $0.name != "Income" }) { group in
                Section(header: Text(group.name)) {
                    ForEach(group.categories) { category in
                        HStack {
                            if let emoji = category.emoji {
                                Text(emoji)
                            }
                            Text(category.name)
                            Spacer()
                            Text(category.allocated, format: .currency(code: "USD"))
                                .foregroundStyle(.secondary)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                categoryToDelete = (group.id, category.id)
                                showingDeleteAlert = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            Button {
                                editingCategory = category
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
                        .swipeHint(enabled: category.id == group.categories.first?.id)
                    }
                }
            }
        }
        .navigationTitle("Manage Categories")
        .sheet(isPresented: Binding(
            get: { editingCategory != nil },
            set: { if !$0 { editingCategory = nil } }
        )) {
            if let category = editingCategory {
                NavigationStack {
                    EditCategoryView(budget: budget, category: category)
                }
                .presentationDetents([.medium])
            }
        }
        .alert("Delete Category", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let (groupId, categoryId) = categoryToDelete {
                    budget.deleteCategory(groupId: groupId, categoryId: categoryId)
                }
            }
        } message: {
            Text("Are you sure you want to delete this category? This action cannot be undone.")
        }
    }
}

struct EditCategoryView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var budget: Budget
    let category: Category
    
    @State private var name: String = ""
    @State private var emoji: String = ""
    @State private var showingEmojiPicker = false
    
    var body: some View {
        Form {
            Section {
                TextField("Category Name", text: $name)
                
                Button {
                    showingEmojiPicker = true
                } label: {
                    HStack {
                        Text("Emoji")
                        Spacer()
                        Text(emoji.isEmpty ? "Select" : emoji)
                    }
                }
            }
        }
        .navigationTitle("Edit Category")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    budget.updateCategory(category.id, name: name, emoji: emoji.isEmpty ? nil : emoji)
                    dismiss()
                }
                .disabled(name.isEmpty)
            }
        }
        .sheet(isPresented: $showingEmojiPicker) {
            EmojiPickerView(selectedEmoji: $emoji)
                .presentationDetents([.medium])
        }
        .onAppear {
            // Initialize state immediately when view appears
            name = category.name
            emoji = category.emoji ?? ""
        }
    }
}

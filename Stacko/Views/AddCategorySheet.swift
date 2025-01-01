import SwiftUI

struct AddCategorySheet: View {
    @ObservedObject var budget: Budget
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var emoji = ""
    @State private var selectedGroupId: UUID?
    
    var body: some View {
        NavigationStack {
            Form {
                TextField("Category Name", text: $name)
                TextField("Emoji (Optional)", text: $emoji)
                
                Picker("Group", selection: $selectedGroupId) {
                    ForEach(budget.categoryGroups) { group in
                        Text(group.name)
                            .tag(Optional(group.id))
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
                    Button("Add") { saveCategory() }
                        .disabled(!isValid)
                }
            }
        }
    }
    
    private var isValid: Bool {
        !name.isEmpty && selectedGroupId != nil
    }
    
    private func saveCategory() {
        guard let groupId = selectedGroupId else { return }
        budget.addCategory(
            name: name,
            emoji: emoji.isEmpty ? nil : emoji,
            groupId: groupId
        )
        dismiss()
    }
} 
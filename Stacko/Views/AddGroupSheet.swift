import SwiftUI

struct AddGroupSheet: View {
    @ObservedObject var budget: Budget
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var emoji = ""
    
    var body: some View {
        NavigationStack {
            Form {
                TextField("Group Name", text: $name)
                TextField("Emoji (Optional)", text: $emoji)
            }
            .navigationTitle("New Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { saveGroup() }
                        .disabled(name.isEmpty)
                }
            }
        }
    }
    
    private func saveGroup() {
        budget.addCategoryGroup(
            name: name,
            emoji: emoji.isEmpty ? nil : emoji
        )
        dismiss()
    }
}

#Preview {
    AddGroupSheet(budget: Budget())
} 
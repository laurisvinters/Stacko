import SwiftUI

struct AddGroupSheet: View {
    @ObservedObject var budget: Budget
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    var onAdd: ((CategoryGroup) -> Void)?
    
    var body: some View {
        NavigationStack {
            Form {
                TextField("Group Name", text: $name)
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
        let group = budget.addCategoryGroup(name: name, emoji: nil)
        onAdd?(group)
        dismiss()
    }
}

#Preview {
    AddGroupSheet(budget: Budget(dataController: DataController()))
} 
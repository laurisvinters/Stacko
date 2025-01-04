import SwiftUI

struct AddGroupSheet: View {
    @ObservedObject var budget: Budget
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var selectedEmoji: String?
    
    var onAdd: ((CategoryGroup) -> Void)?
    
    var body: some View {
        NavigationStack {
            Form {
                TextField("Group Name", text: $name)
                
                // Add emoji picker
                Section("Choose Icon") {
                    EmojiPicker(selection: $selectedEmoji)
                }
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
        let group = budget.addCategoryGroup(name: name, emoji: selectedEmoji)
        onAdd?(group)
        dismiss()
    }
}

// Reusable emoji picker
struct EmojiPicker: View {
    @Binding var selection: String?
    
    private let suggestedEmojis = [
        "🏠", "🚗", "💰", "🍽️", "🛒", "💊", "🎮",
        "👕", "✈️", "📱", "🎓", "🎁", "🏋️", "🎬", "📚"
    ]
    
    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))], spacing: 10) {
            ForEach(suggestedEmojis, id: \.self) { emoji in
                Button(action: {
                    selection = emoji
                }) {
                    Text(emoji)
                        .font(.title2)
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(selection == emoji ? 
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

#Preview {
    AddGroupSheet(budget: Budget(dataController: DataController()))
} 
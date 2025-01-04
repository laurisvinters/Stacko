import SwiftUI

struct AddCategorySheet: View {
    @ObservedObject var budget: Budget
    let groupId: UUID?
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var selectedEmoji = "🎯"
    @State private var selectedGroupId: UUID?
    
    init(budget: Budget, groupId: UUID? = nil) {
        self.budget = budget
        self.groupId = groupId
        _selectedGroupId = State(initialValue: groupId)
    }
    
    // Predefined emoji suggestions based on common budget categories
    private let suggestedEmojis = [
        "🎯", "💰", "🏠", "🚗", "🍽️", "🛒", "💊", "🎮",
        "👕", "✈️", "📱", "🎓", "🎁", "🏋️", "🎬", "📚"
    ]
    
    var body: some View {
        NavigationStack {
            Form {
                TextField("Category Name", text: $name)
                
                Section("Choose Icon") {
                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 44))
                    ], spacing: 10) {
                        ForEach(suggestedEmojis, id: \.self) { emoji in
                            Button(action: {
                                selectedEmoji = emoji
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
                    }
                    .padding(.vertical, 8)
                }
                
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
            emoji: selectedEmoji,
            groupId: groupId
        )
        dismiss()
    }
} 
import SwiftUI

struct AddCategorySheet: View {
    @ObservedObject var budget: Budget
    let groupId: UUID?
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var selectedEmoji = "🎯"
    @State private var selectedGroupId: UUID?
    @State private var customEmoji = ""
    @State private var isShowingCustomEmoji = false
    
    init(budget: Budget, groupId: UUID? = nil) {
        self.budget = budget
        self.groupId = groupId
        _selectedGroupId = State(initialValue: groupId)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Category Name", text: $name)
                }
                
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
                            .onChange(of: customEmoji) { newValue in
                                if !newValue.isEmpty {
                                    selectedEmoji = String(newValue.prefix(2)) // Take only first emoji
                                }
                            }
                    }
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
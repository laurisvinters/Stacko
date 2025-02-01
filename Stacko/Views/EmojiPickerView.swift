import SwiftUI

struct EmojiPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedEmoji: String
    
    let columns = Array(repeating: GridItem(.flexible()), count: 6)
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(categoryEmojis, id: \.self) { emoji in
                        Button {
                            selectedEmoji = emoji
                            dismiss()
                        } label: {
                            Text(emoji)
                                .font(.title)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Select Emoji")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    EmojiPickerView(selectedEmoji: .constant(""))
}

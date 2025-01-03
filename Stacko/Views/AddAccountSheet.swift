import SwiftUI

struct AddAccountSheet: View {
    @ObservedObject var budget: Budget
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var type = Account.AccountType.checking
    @State private var icon = ""
    @State private var keyboardHeight: CGFloat = 0
    
    var body: some View {
        NavigationStack {
            Form {
                TextField("Account Name", text: $name)
                
                Picker("Type", selection: $type) {
                    ForEach(Account.AccountType.allCases, id: \.self) { type in
                        Text(type.rawValue)
                            .tag(type)
                    }
                }
                
                TextField("Icon (Optional)", text: $icon)
            }
            .navigationTitle("New Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { saveAccount() }
                        .disabled(name.isEmpty)
                }
            }
            .ignoresSafeArea(.keyboard)
            .onAppear {
                setupKeyboardNotifications()
            }
            .onDisappear {
                removeKeyboardNotifications()
            }
            .padding(.bottom, keyboardHeight)
        }
    }
    
    private func saveAccount() {
        budget.addAccount(
            name: name,
            type: type,
            icon: icon.isEmpty ? type.icon : icon
        )
        dismiss()
    }
    
    private func setupKeyboardNotifications() {
        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillShowNotification,
            object: nil,
            queue: .main
        ) { notification in
            if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                keyboardHeight = keyboardFrame.height
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillHideNotification,
            object: nil,
            queue: .main
        ) { _ in
            keyboardHeight = 0
        }
    }
    
    private func removeKeyboardNotifications() {
        NotificationCenter.default.removeObserver(self)
    }
} 
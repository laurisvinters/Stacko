import SwiftUI

struct AddAccountSheet: View {
    @ObservedObject var budget: Budget
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var type = Account.AccountType.cash
    @State private var currentBalance = ""
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
                
                TextField("Current Balance", text: $currentBalance)
                    .keyboardType(.decimalPad)
            }
            .navigationTitle("New Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { saveAccount() }
                        .disabled(name.isEmpty || currentBalance.isEmpty)
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
        let balance = Double(currentBalance.replacingOccurrences(of: ",", with: ".")) ?? 0
        
        // Create account with initial balance
        let account = Account(
            name: name,
            type: type,
            balance: balance,
            clearedBalance: balance,
            icon: type.icon
        )
        budget.addAccount(
            name: account.name,
            type: account.type,
            icon: account.icon,
            balance: account.balance
        )
        
        // Add initial balance transaction if needed
        if balance != 0,
           let account = budget.accounts.first(where: { $0.name == name }),
           let incomeGroup = budget.categoryGroups.first(where: { $0.name == "Income" }),
           let initialBalanceCategory = incomeGroup.categories.first(where: { $0.name == "Initial Balance" }) ?? incomeGroup.categories.first {
            let transaction = Transaction(
                id: UUID(),
                date: Date(),
                payee: "Initial Balance",
                categoryId: initialBalanceCategory.id,
                amount: abs(balance),
                note: "Initial balance for \(name)",
                isIncome: balance > 0,
                accountId: account.id,
                toAccountId: nil
            )
            budget.addTransaction(transaction)
        }
        
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
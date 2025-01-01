import SwiftUI

struct QuickAddTransactionSheet: View {
    @ObservedObject var budget: Budget
    @Environment(\.dismiss) private var dismiss
    
    @State private var amount = ""
    @State private var payee = ""
    @State private var selectedCategoryId: UUID?
    @State private var selectedAccountId: UUID?
    @State private var isIncome = false
    @State private var date = Date()
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Amount", text: $amount)
                        .keyboardType(.decimalPad)
                    
                    TextField("Payee", text: $payee)
                    
                    Picker("Category", selection: $selectedCategoryId) {
                        ForEach(budget.categoryGroups) { group in
                            Section(group.name) {
                                ForEach(group.categories) { category in
                                    Text(category.name)
                                        .tag(Optional(category.id))
                                }
                            }
                        }
                    }
                    
                    Picker("Account", selection: $selectedAccountId) {
                        ForEach(budget.accounts.filter { !$0.isArchived }) { account in
                            Text(account.name)
                                .tag(Optional(account.id))
                        }
                    }
                    
                    Toggle("Income", isOn: $isIncome)
                    
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                }
            }
            .navigationTitle("Quick Add")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        saveTransaction()
                    }
                    .disabled(!isValid)
                }
            }
            .onAppear {
                // Set default account
                if selectedAccountId == nil {
                    selectedAccountId = budget.accounts.first?.id
                }
            }
        }
    }
    
    private var isValid: Bool {
        guard let amountDouble = Double(amount),
              amountDouble > 0,
              !payee.isEmpty,
              selectedCategoryId != nil,
              selectedAccountId != nil else {
            return false
        }
        return true
    }
    
    private func saveTransaction() {
        guard let amountDouble = Double(amount),
              let categoryId = selectedCategoryId,
              let accountId = selectedAccountId else { return }
        
        let transaction = Transaction(
            id: UUID(),
            date: date,
            payee: payee,
            categoryId: categoryId,
            amount: amountDouble,
            note: nil,
            isIncome: isIncome,
            accountId: accountId,
            toAccountId: nil
        )
        
        budget.addTransaction(transaction)
        dismiss()
    }
}

#Preview {
    QuickAddTransactionSheet(budget: Budget())
} 
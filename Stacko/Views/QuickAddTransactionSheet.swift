import SwiftUI

struct QuickAddTransactionSheet: View {
    @ObservedObject var budget: Budget
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Field?
    
    private enum Field {
        case amount
        case payee
    }
    
    let existingTransaction: Transaction?
    
    @State private var amount = ""
    @State private var payee = ""
    @State private var selectedCategoryId: UUID?
    @State private var selectedAccountId: UUID?
    @State private var isIncome = false
    @State private var showAllCategories = false
    @State private var date = Date()
    @State private var showCategoryPicker = false
    
    init(budget: Budget, existingTransaction: Transaction? = nil) {
        self.budget = budget
        self.existingTransaction = existingTransaction
        
        if let transaction = existingTransaction {
            _amount = State(initialValue: String(abs(transaction.amount)))
            _payee = State(initialValue: transaction.payee)
            _selectedCategoryId = State(initialValue: transaction.categoryId)
            _selectedAccountId = State(initialValue: transaction.accountId)
            _isIncome = State(initialValue: transaction.isIncome)
            _date = State(initialValue: transaction.date)
        }
    }
    
    private var sortedCategoryGroups: [CategoryGroup] {
        let incomeGroup = budget.categoryGroups.first { $0.name == "Income" }
        let otherGroups = budget.categoryGroups.filter { $0.name != "Income" }
        
        if isIncome {
            if let incomeGroup = incomeGroup {
                return showAllCategories ? [incomeGroup] + otherGroups : [incomeGroup]
            }
            return otherGroups
        } else {
            // Always include Income group for Expense transactions
            if let incomeGroup = incomeGroup {
                return [incomeGroup] + otherGroups
            }
            return otherGroups
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Type", selection: $isIncome) {
                        Text("Expense").tag(false)
                        Text("Income").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: isIncome) { _ in
                        // Reset category selection when switching between income/expense
                        selectedCategoryId = nil
                        showAllCategories = false
                    }
                }
                
                Section {
                    TextField("Amount", text: $amount)
                        .keyboardType(.decimalPad)
                        .focused($focusedField, equals: .amount)
                    
                    TextField("Payee", text: $payee)
                        .focused($focusedField, equals: .payee)
                    
                    HStack {
                        Text("Category")
                        Spacer()
                        Text(selectedCategoryName)
                            .foregroundColor(.secondary)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        showCategoryPicker = true
                    }
                    .sheet(isPresented: $showCategoryPicker) {
                        NavigationStack {
                            List {
                                ForEach(sortedCategoryGroups) { group in
                                    Section(group.name) {
                                        ForEach(group.categories) { category in
                                            Button(action: {
                                                selectedCategoryId = category.id
                                                showCategoryPicker = false
                                            }) {
                                                HStack {
                                                    Text(category.name)
                                                    Spacer()
                                                    if selectedCategoryId == category.id {
                                                        Image(systemName: "checkmark")
                                                    }
                                                }
                                            }
                                            .foregroundColor(.primary)
                                        }
                                    }
                                }
                                
                                if isIncome && !showAllCategories {
                                    Section {
                                        Button(action: {
                                            showAllCategories = true
                                        }) {
                                            Text("Show all categories")
                                                .foregroundColor(.blue)
                                        }
                                    }
                                }
                            }
                            .navigationTitle("Select Category")
                            .navigationBarTitleDisplayMode(.inline)
                            .toolbar {
                                ToolbarItem(placement: .cancellationAction) {
                                    Button("Cancel") {
                                        showCategoryPicker = false
                                    }
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
                    
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                }
            }
            .navigationTitle(existingTransaction != nil ? "Edit Transaction" : "Quick Add")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button(existingTransaction != nil ? "Save" : "Add") {
                        if existingTransaction != nil {
                            updateTransaction()
                        } else {
                            saveTransaction()
                        }
                    }
                    .disabled(!isValid)
                }
                
                ToolbarItem(placement: .keyboard) {
                    Button("Done") {
                        focusedField = nil
                    }
                }
            }
            .onAppear {
                // Set default account
                if selectedAccountId == nil {
                    selectedAccountId = budget.accounts.first?.id
                }
                
                // Set initial focus to amount field
                focusedField = .amount
            }
        }
        .interactiveDismissDisabled()
    }
    
    private var selectedCategoryName: String {
        if let categoryId = selectedCategoryId {
            for group in budget.categoryGroups {
                if let category = group.categories.first(where: { $0.id == categoryId }) {
                    return category.name
                }
            }
        }
        return "Select a category"
    }
    
    private var isValid: Bool {
        guard let amount = Double(amount), amount > 0 else { return false }
        guard !payee.isEmpty else { return false }
        guard selectedCategoryId != nil else { return false }
        guard selectedAccountId != nil else { return false }
        return true
    }
    
    private func saveTransaction() {
        guard let amount = Double(amount),
              let categoryId = selectedCategoryId,
              let accountId = selectedAccountId else {
            return
        }
        
        let transaction = Transaction(
            id: UUID(),
            date: date,
            payee: payee,
            categoryId: categoryId,
            amount: isIncome ? amount : -amount,
            note: nil,
            isIncome: isIncome,
            accountId: accountId,
            toAccountId: nil
        )
        
        budget.addTransaction(transaction)
        dismiss()
    }
    
    private func updateTransaction() {
        guard let amount = Double(amount),
              let categoryId = selectedCategoryId,
              let accountId = selectedAccountId,
              let existingTransaction = existingTransaction else {
            return
        }
        
        let updatedTransaction = Transaction(
            id: existingTransaction.id,
            date: date,
            payee: payee,
            categoryId: categoryId,
            amount: isIncome ? amount : -amount,
            note: existingTransaction.note,
            isIncome: isIncome,
            accountId: accountId,
            toAccountId: nil
        )
        
        budget.updateTransaction(existingTransaction, with: updatedTransaction)
        dismiss()
    }
}

#Preview {
    QuickAddTransactionSheet(budget: Budget())
}
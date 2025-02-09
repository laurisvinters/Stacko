import SwiftUI

struct QuickAddTransactionSheet: View {
    @ObservedObject var budget: Budget
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Field?
    
    private enum Field {
        case amount
        case payee
    }
    
    private enum TransactionType {
        case expense
        case income
        case transfer
    }
    
    let categoryId: UUID?
    let existingTransaction: Transaction?
    
    @State private var amount = ""
    @State private var payee = ""
    @State private var selectedCategoryId: UUID?
    @State private var selectedAccountId: UUID?
    @State private var transactionType: TransactionType = .expense
    @State private var showAllCategories = false
    @State private var date = Date()
    @State private var showCategoryPicker = false
    @State private var toAccountId: UUID?
    
    // New state variables for alerts
    @State private var showInsufficientFundsAlert = false
    @State private var showAllocationAlert = false
    @State private var proceedWithoutAllocation = false
    @State private var showInsufficientTransferFundsAlert = false
    
    private var isIncome: Bool {
        transactionType == .income
    }
    
    private var isTransfer: Bool {
        transactionType == .transfer
    }
    
    private var transactionAmount: Double {
        Double(amount) ?? 0
    }
    
    private var selectedCategory: Category? {
        guard let categoryId = selectedCategoryId else { return nil }
        for group in budget.categoryGroups {
            if let category = group.categories.first(where: { $0.id == categoryId }) {
                return category
            }
        }
        return nil
    }
    
    private var hasInsufficientFunds: Bool {
        guard let category = selectedCategory, !isIncome else { return false }
        let available = category.available
        return transactionAmount > available
    }
    
    private var hasInsufficientTransferFunds: Bool {
        guard isTransfer,
              let fromAccount = budget.accounts.first(where: { $0.id == selectedAccountId }),
              let amount = Double(amount) else { return false }
        return amount > fromAccount.balance
    }
    
    private var canAllocateMore: Bool {
        let totalAvailable = budget.accounts.filter { !$0.isArchived }.reduce(0) { $0 + $1.balance }
        var totalAllocated: Double = 0
        for group in budget.categoryGroups {
            for category in group.categories {
                totalAllocated += category.allocated
            }
        }
        return totalAvailable > totalAllocated + transactionAmount
    }
    
    init(budget: Budget, existingTransaction: Transaction? = nil, categoryId: UUID? = nil) {
        self.budget = budget
        self.existingTransaction = existingTransaction
        self.categoryId = categoryId
        
        if let transaction = existingTransaction {
            _amount = State(initialValue: String(abs(transaction.amount)))
            _payee = State(initialValue: transaction.payee)
            _selectedCategoryId = State(initialValue: transaction.categoryId)
            _selectedAccountId = State(initialValue: transaction.accountId)
            _transactionType = State(initialValue: transaction.toAccountId != nil ? .transfer : (transaction.isIncome ? .income : .expense))
            _date = State(initialValue: transaction.date)
            _toAccountId = State(initialValue: transaction.toAccountId)
        } else {
            // For new transactions, use the provided categoryId if available
            _selectedCategoryId = State(initialValue: categoryId)
            
            // Set the default account to the one from the last transaction
            if let lastTransaction = budget.transactions.sorted(by: { $0.date > $1.date }).first {
                _selectedAccountId = State(initialValue: lastTransaction.accountId)
            } else if let firstAccount = budget.accounts.filter({ !$0.isArchived }).first {
                // If no transactions exist, use the first non-archived account
                _selectedAccountId = State(initialValue: firstAccount.id)
            }
        }
    }
    
    private var sortedCategoryGroups: [CategoryGroup] {
        if isIncome && !showAllCategories {
            // Only show Income group when income is selected and not showing all categories
            return budget.categoryGroups.filter { $0.name == "Income" }
        }
        // Show all groups when showing all categories or when it's an expense
        return budget.categoryGroups
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Type", selection: $transactionType) {
                        Text("Expense").tag(TransactionType.expense)
                        Text("Income").tag(TransactionType.income)
                        Text("Transfer").tag(TransactionType.transfer)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: transactionType) { newValue in
                        // Reset category when switching to/from transfer
                        if newValue == .transfer {
                            selectedCategoryId = nil
                            payee = ""
                            toAccountId = nil
                        } else if isTransfer {
                            // Coming from transfer mode
                            toAccountId = nil
                            // Set default category based on new type
                            if let firstGroup = budget.categoryGroups.first,
                               let firstCategory = firstGroup.categories.first {
                                selectedCategoryId = firstCategory.id
                            }
                        }
                    }
                }
                
                Section {
                    TextField("Amount", text: $amount)
                        .keyboardType(.decimalPad)
                        .focused($focusedField, equals: .amount)
                    
                    if !isTransfer {
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
                                                Text("See more categories")
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
                                            showAllCategories = false
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                    Picker(isTransfer ? "From Account" : "Account", selection: $selectedAccountId) {
                        ForEach(budget.accounts.filter { !$0.isArchived }) { account in
                            Text(account.name)
                                .tag(Optional(account.id))
                        }
                    }
                    .onChange(of: selectedAccountId) { newValue in
                        // If in transfer mode and the selected account is the same as the destination account,
                        // reset the destination account
                        if isTransfer && newValue == toAccountId {
                            toAccountId = nil
                        }
                    }
                    
                    if isTransfer {
                        Picker("To Account", selection: $toAccountId) {
                            Text("Select Account").tag(Optional<UUID>.none)
                            ForEach(budget.accounts.filter { !$0.isArchived && $0.id != selectedAccountId }) { account in
                                Text(account.name)
                                    .tag(Optional(account.id))
                            }
                        }
                    }
                    
                    DatePicker("Date & Time", selection: $date, displayedComponents: [.date, .hourAndMinute])
                }
            }
            .navigationTitle(existingTransaction == nil ? "Add Transaction" : "Edit Transaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button(existingTransaction == nil ? "Add" : "Save") {
                        if isTransfer {
                            if hasInsufficientTransferFunds {
                                showInsufficientTransferFundsAlert = true
                            } else {
                                saveTransfer()
                            }
                        } else if !isIncome && hasInsufficientFunds {
                            if canAllocateMore {
                                showAllocationAlert = true
                            } else {
                                showInsufficientFundsAlert = true
                            }
                        } else {
                            if existingTransaction == nil {
                                saveTransaction()
                            } else {
                                updateTransaction()
                            }
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
        }
        .interactiveDismissDisabled()
        .alert("Insufficient Funds", isPresented: $showInsufficientFundsAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Continue Anyway", role: .destructive) {
                if existingTransaction == nil {
                    saveTransaction()
                } else {
                    updateTransaction()
                }
            }
        } message: {
            Text("This category doesn't have enough allocated funds. It's recommended to reallocate funds from other categories first.")
        }
        .alert("Insufficient Transfer Funds", isPresented: $showInsufficientTransferFundsAlert) {
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("The source account doesn't have enough funds for this transfer.")
        }
        .alert("Allocate Funds?", isPresented: $showAllocationAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Skip", role: .destructive) {
                if existingTransaction == nil {
                    saveTransaction()
                } else {
                    updateTransaction()
                }
            }
            Button("Allocate", role: .none) {
                if let category = selectedCategory {
                    // First allocate funds
                    budget.allocateToBudget(amount: transactionAmount, categoryId: category.id)
                    // Wait a moment for allocation to complete before adding transaction
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        if existingTransaction == nil {
                            saveTransaction()
                        } else {
                            updateTransaction()
                        }
                    }
                }
            }
        } message: {
            Text("This category needs more funds. Would you like to allocate \(transactionAmount.formatted(.currency(code: "USD"))) to this category?")
        }
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
        guard selectedAccountId != nil else { return false }
        
        if isTransfer {
            guard let toId = toAccountId, toId != selectedAccountId else { return false }
            return true
        } else {
            guard !payee.isEmpty else { return false }
            guard selectedCategoryId != nil else { return false }
            return true
        }
    }
    
    private func saveTransaction() {
        guard let amount = Double(amount),
              let categoryId = selectedCategoryId,
              let accountId = selectedAccountId else {
            return
        }
        
        // For expenses, we store negative amounts
        // For income, we store positive amounts
        let transactionAmount = isIncome ? abs(amount) : -abs(amount)
        
        let transaction = Transaction(
            id: UUID(),
            date: date,
            payee: payee,
            categoryId: categoryId,
            amount: transactionAmount,
            note: nil,
            isIncome: isIncome,
            accountId: accountId,
            toAccountId: nil
        )
        
        budget.addTransaction(transaction)
        dismiss()
    }
    
    private func saveTransfer() {
        guard let amount = Double(amount),
              let fromId = selectedAccountId,
              let toId = toAccountId else {
            return
        }
        
        budget.createTransfer(
            fromAccountId: fromId,
            toAccountId: toId,
            amount: amount,
            date: date,
            note: nil
        )
        dismiss()
    }
    
    private func updateTransaction() {
        guard let amount = Double(amount),
              let categoryId = selectedCategoryId,
              let accountId = selectedAccountId,
              let existingTransaction = existingTransaction else {
            return
        }
        
        // For expenses, we store negative amounts
        // For income, we store positive amounts
        let transactionAmount = isIncome ? abs(amount) : -abs(amount)
        
        let updatedTransaction = Transaction(
            id: existingTransaction.id,
            date: date,
            payee: payee,
            categoryId: categoryId,
            amount: transactionAmount,
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
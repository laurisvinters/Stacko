import Foundation
import SwiftUI

class Budget: ObservableObject {
    @Published var categoryGroups: [CategoryGroup]
    @Published var transactions: [Transaction]
    @Published var templates: [TransactionTemplate]
    @Published var accounts: [Account]
    
    // Track monthly income
    @Published var monthlyIncome: Double = 0
    
    init() {
        // Initialize empty arrays
        self.categoryGroups = []
        self.transactions = []
        self.templates = []
        self.accounts = [
            Account(
                name: "Wallet",
                type: .cash,
                category: .personal,
                icon: "💵"
            ),
            Account(
                name: "Main Card",
                type: .creditCard,
                category: .personal,
                icon: "💳"
            )
        ]
        
        // Add these predefined groups and categories first
        createDefaultCategories()
        
        // Then create test transactions
        let walletId = accounts[0].id
        let cardId = accounts[1].id
        
        // Create test transactions...
        // Rest of the initialization code...
    }
    
    var balance: Double {
        transactions.reduce(0) { sum, transaction in
            sum + (transaction.isIncome ? transaction.amount : -transaction.amount)
        }
    }
    
    func addTransaction(_ transaction: Transaction) {
        transactions.append(transaction)
        updateCategorySpending(transaction)
        updateAccountBalance(transaction)
    }
    
    private func updateCategorySpending(_ transaction: Transaction) {
        guard let groupIndex = categoryGroups.firstIndex(where: { group in
            group.categories.contains { $0.id == transaction.categoryId }
        }), let categoryIndex = categoryGroups[groupIndex].categories.firstIndex(where: { $0.id == transaction.categoryId }) else {
            return
        }
        
        let amount = transaction.isIncome ? -transaction.amount : transaction.amount
        categoryGroups[groupIndex].categories[categoryIndex].spent += amount
    }
    
    private func updateAccountBalance(_ transaction: Transaction) {
        if let index = accounts.firstIndex(where: { $0.id == transaction.accountId }) {
            if transaction.isTransfer {
                accounts[index].balance -= transaction.amount
            } else {
                accounts[index].balance += (transaction.isIncome ? transaction.amount : -transaction.amount)
            }
        }
        
        if let toAccountId = transaction.toAccountId,
           let index = accounts.firstIndex(where: { $0.id == toAccountId }) {
            accounts[index].balance += transaction.amount
        }
    }
    
    func createTransactionFromTemplate(_ template: TransactionTemplate) {
        guard let defaultAccount = accounts.first else { return }
        
        let transaction = Transaction(
            id: UUID(),
            date: Date(),
            payee: template.payee,
            categoryId: template.categoryId,
            amount: template.amount,
            note: "Created from template: \(template.name)",
            isIncome: template.isIncome,
            accountId: defaultAccount.id,
            toAccountId: nil
        )
        addTransaction(transaction)
    }
    
    func allocateToBudget(amount: Double, categoryId: UUID) {
        objectWillChange.send()
        guard let (groupIndex, categoryIndex) = findCategory(byId: categoryId) else { return }
        categoryGroups[groupIndex].categories[categoryIndex].allocated += amount
    }
    
    func deallocateFromBudget(amount: Double, categoryId: UUID) {
        guard let (groupIndex, categoryIndex) = findCategory(byId: categoryId),
              categoryGroups[groupIndex].categories[categoryIndex].allocated >= amount else { return }
        categoryGroups[groupIndex].categories[categoryIndex].allocated -= amount
    }
    
    func findCategory(byId id: UUID) -> (Int, Int)? {
        for (groupIndex, group) in categoryGroups.enumerated() {
            if let categoryIndex = group.categories.firstIndex(where: { $0.id == id }) {
                return (groupIndex, categoryIndex)
            }
        }
        return nil
    }
    
    // Category management
    func addCategory(name: String, emoji: String?, groupId: UUID, target: Target? = nil) {
        guard let groupIndex = categoryGroups.firstIndex(where: { $0.id == groupId }) else { return }
        let newCategory = Category(
            id: UUID(),
            name: name,
            emoji: emoji,
            target: target,
            allocated: 0,
            spent: 0
        )
        categoryGroups[groupIndex].categories.append(newCategory)
    }
    
    @discardableResult
    func addCategoryGroup(name: String, emoji: String?) -> CategoryGroup {
        let newGroup = CategoryGroup(
            id: UUID(),
            name: name,
            emoji: emoji,
            categories: []
        )
        categoryGroups.append(newGroup)
        return newGroup
    }
    
    // Analytics
    func monthlySpending(for categoryId: UUID, in month: Date) -> Double {
        let calendar = Calendar.current
        return transactions
            .filter { transaction in
                transaction.categoryId == categoryId &&
                calendar.isDate(transaction.date, equalTo: month, toGranularity: .month)
            }
            .reduce(0) { $0 + $1.amount }
    }
    
    func categorySpending(in month: Date) -> [(Category, Double)] {
        let allCategories = categoryGroups.flatMap(\.categories)
        return allCategories.map { category in
            (category, monthlySpending(for: category.id, in: month))
        }
    }
    
    // Account management
    func addAccount(name: String, type: Account.AccountType, icon: String) {
        let newAccount = Account(
            name: name,
            type: type,
            icon: icon
        )
        accounts.append(newAccount)
    }
    
    func updateAccount(_ account: Account) {
        if let index = accounts.firstIndex(where: { $0.id == account.id }) {
            accounts[index] = account
        }
    }
    
    func archiveAccount(_ accountId: UUID) {
        if let index = accounts.firstIndex(where: { $0.id == accountId }) {
            accounts[index].isArchived = true
        }
    }
    
    func createTransfer(amount: Double, fromAccountId: UUID, toAccountId: UUID, date: Date, note: String?) {
        let transaction = Transaction(
            id: UUID(),
            date: date,
            payee: "Transfer",
            categoryId: UUID(), // We might want to create a special transfer category
            amount: amount,
            note: note,
            isIncome: false,
            accountId: fromAccountId,
            toAccountId: toAccountId
        )
        
        // Update account balances
        if let fromIndex = accounts.firstIndex(where: { $0.id == fromAccountId }) {
            accounts[fromIndex].balance -= amount
        }
        
        if let toIndex = accounts.firstIndex(where: { $0.id == toAccountId }) {
            accounts[toIndex].balance += amount
        }
        
        transactions.append(transaction)
    }
    
    // Helper method for creating test transactions
    private func createTestTransaction(
        date: String,
        amount: Double,
        payee: String,
        categoryName: String? = nil,
        isIncome: Bool = false,
        accountId: UUID
    ) -> Transaction {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        // Find category ID by name, creating a new one if necessary
        let categoryId: UUID
        if let name = categoryName {
            if let existingCategory = categoryGroups
                .flatMap(\.categories)
                .first(where: { $0.name == name }) {
                categoryId = existingCategory.id
            } else {
                // If category doesn't exist, create it in the first group
                let newCategory = Category(
                    id: UUID(),
                    name: name,
                    emoji: "📝",
                    target: nil,
                    allocated: 0,
                    spent: 0
                )
                if !categoryGroups.isEmpty {
                    categoryGroups[0].categories.append(newCategory)
                }
                categoryId = newCategory.id
            }
        } else {
            categoryId = categoryGroups[0].categories[0].id
        }
        
        return Transaction(
            id: UUID(),
            date: dateFormatter.date(from: date) ?? Date(),
            payee: payee,
            categoryId: categoryId,
            amount: amount,
            note: "Test data",
            isIncome: isIncome,
            accountId: accountId,
            toAccountId: nil
        )
    }
    
    // Add these predefined groups and categories
    private func createDefaultCategories() {
        // Immediate Obligations - Monthly targets
        let immediate = addCategoryGroup(name: "Immediate Obligations", emoji: "🏠")
        addCategory(name: "Mortgage/Rent", emoji: "🏘️", groupId: immediate.id, 
                   target: Target(type: .monthly(amount: 1200)))
        addCategory(name: "Electric", emoji: "⚡", groupId: immediate.id,
                   target: Target(type: .monthly(amount: 150)))
        addCategory(name: "Water", emoji: "💧", groupId: immediate.id,
                   target: Target(type: .monthly(amount: 80)))
        addCategory(name: "Internet", emoji: "📡", groupId: immediate.id,
                   target: Target(type: .monthly(amount: 70)))
        addCategory(name: "Phone", emoji: "📱", groupId: immediate.id,
                   target: Target(type: .monthly(amount: 60)))
        addCategory(name: "Groceries", emoji: "🛒", groupId: immediate.id,
                   target: Target(type: .monthly(amount: 500)))
        
        // True Expenses - Monthly targets
        let trueExpenses = addCategoryGroup(name: "True Expenses", emoji: "📊")
        addCategory(name: "Auto Maintenance", emoji: "🚗", groupId: trueExpenses.id,
                   target: Target(type: .monthly(amount: 200)))
        addCategory(name: "Home Maintenance", emoji: "🔧", groupId: trueExpenses.id,
                   target: Target(type: .monthly(amount: 150)))
        addCategory(name: "Insurance", emoji: "🛡️", groupId: trueExpenses.id,
                   target: Target(type: .monthly(amount: 300)))
        addCategory(name: "Medical", emoji: "🏥", groupId: trueExpenses.id,
                   target: Target(type: .monthly(amount: 200)))
        addCategory(name: "Clothing", emoji: "👕", groupId: trueExpenses.id,
                   target: Target(type: .monthly(amount: 100)))
        addCategory(name: "Technology", emoji: "💻", groupId: trueExpenses.id,
                   target: Target(type: .monthly(amount: 100)))
        
        // Debt Payments - Monthly targets
        let debt = addCategoryGroup(name: "Debt Payments", emoji: "💳")
        addCategory(name: "Credit Card", emoji: "💳", groupId: debt.id,
                   target: Target(type: .monthly(amount: 500)))
        addCategory(name: "Student Loan", emoji: "🎓", groupId: debt.id,
                   target: Target(type: .monthly(amount: 400)))
        addCategory(name: "Car Loan", emoji: "🚙", groupId: debt.id,
                   target: Target(type: .monthly(amount: 350)))
        
        // Quality of Life - Weekly targets
        let quality = addCategoryGroup(name: "Quality of Life", emoji: "✨")
        addCategory(name: "Dining Out", emoji: "🍽️", groupId: quality.id,
                   target: Target(type: .weekly(amount: 100)))
        addCategory(name: "Entertainment", emoji: "🎭", groupId: quality.id,
                   target: Target(type: .weekly(amount: 50)))
        addCategory(name: "Shopping", emoji: "🛍️", groupId: quality.id,
                   target: Target(type: .weekly(amount: 75)))
        addCategory(name: "Hobbies", emoji: "🎨", groupId: quality.id,
                   target: Target(type: .weekly(amount: 50)))
        addCategory(name: "Fitness", emoji: "💪", groupId: quality.id,
                   target: Target(type: .weekly(amount: 40)))
        
        // Savings Goals - By Date targets
        let savings = addCategoryGroup(name: "Savings Goals", emoji: "🎯")
        let yearEnd = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
        addCategory(name: "Emergency Fund", emoji: "🚨", groupId: savings.id,
                   target: Target(type: .byDate(amount: 10000, date: yearEnd)))
        addCategory(name: "Vacation", emoji: "✈️", groupId: savings.id,
                   target: Target(type: .byDate(amount: 3000, date: yearEnd)))
        addCategory(name: "New Car", emoji: "🚗", groupId: savings.id,
                   target: Target(type: .byDate(amount: 20000, date: yearEnd)))
        addCategory(name: "Home Down Payment", emoji: "🏡", groupId: savings.id,
                   target: Target(type: .byDate(amount: 50000, date: yearEnd)))
        addCategory(name: "Retirement", emoji: "👴", groupId: savings.id,
                   target: Target(type: .monthly(amount: 1000)))
        
        // Income - Monthly targets
        let income = addCategoryGroup(name: "Income", emoji: "💰")
        addCategory(name: "Salary", emoji: "💵", groupId: income.id,
                   target: Target(type: .monthly(amount: 5000)))
        addCategory(name: "Bonus", emoji: "🎉", groupId: income.id,
                   target: Target(type: .monthly(amount: 1000)))
        addCategory(name: "Interest", emoji: "📈", groupId: income.id,
                   target: Target(type: .monthly(amount: 100)))
        addCategory(name: "Side Hustle", emoji: "💪", groupId: income.id,
                   target: Target(type: .monthly(amount: 500)))
    }
    
    // Add helper method for creating transfer transactions
    private func createTransferTransaction(
        date: String,
        amount: Double,
        fromId: UUID,
        toId: UUID
    ) -> Transaction {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        return Transaction(
            id: UUID(),
            date: dateFormatter.date(from: date) ?? Date(),
            payee: "Credit Card Payment",
            categoryId: UUID(), // Transfer category
            amount: amount,
            note: "Monthly credit card payment",
            isIncome: false,
            accountId: fromId,
            toAccountId: toId
        )
    }
    
    public var availableToBudget: Double {
        // Sum of all account balances
        let totalBalance = accounts
            .filter { !$0.isArchived }  // Only consider active accounts
            .reduce(0.0) { sum, account in
                print("Account: \(account.name), Balance: \(account.balance)")
                if account.type == .creditCard {
                    return sum + max(0, account.balance)
                }
                return sum + account.balance
            }
        
        print("Total Balance: \(totalBalance)")
        
        // Subtract allocated amounts
        let totalAllocated = categoryGroups
            .flatMap(\.categories)
            .reduce(0.0) { $0 + $1.allocated }
        
        print("Total Allocated: \(totalAllocated)")
        print("Available to Budget: \(totalBalance - totalAllocated)")
        
        return totalBalance - totalAllocated
    }
    
    // Also add a debug method to check account balances
    func debugBalances() {
        print("\n--- Debug Account Balances ---")
        for account in accounts {
            print("\(account.name): \(account.balance)")
        }
        print("Total Balance: \(totalBalance)")
        print("Available to Budget: \(availableToBudget)")
        print("---------------------------\n")
    }
    
    // Add a computed property for total balance
    public var totalBalance: Double {
        accounts
            .filter { !$0.isArchived }
            .reduce(0.0) { sum, account in
                if account.type == .creditCard {
                    return sum + max(0, account.balance)
                }
                return sum + account.balance
            }
    }
    
    // Add this method to the Budget class
    func setTarget(for categoryId: UUID, target: Target) {
        objectWillChange.send()
        if let (groupIndex, categoryIndex) = findCategory(byId: categoryId) {
            categoryGroups[groupIndex].categories[categoryIndex].target = target
            // Force a UI update
            let currentAllocated = categoryGroups[groupIndex].categories[categoryIndex].allocated
            categoryGroups[groupIndex].categories[categoryIndex].allocated = currentAllocated
        }
    }
} 
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
        let rentCategoryId = UUID()
        // Add some sample data for testing
        self.categoryGroups = [
            CategoryGroup(id: UUID(), name: "Monthly Bills", emoji: "🏠", categories: [
                Category(id: rentCategoryId, name: "Rent", emoji: "🏢", target: nil, allocated: 0, spent: 0),
                Category(id: UUID(), name: "Utilities", emoji: "💡", target: nil, allocated: 0, spent: 0)
            ]),
            CategoryGroup(id: UUID(), name: "Daily Living", emoji: "🛒", categories: [
                Category(id: UUID(), name: "Groceries", emoji: "🥑", target: nil, allocated: 0, spent: 0),
                Category(id: UUID(), name: "Transportation", emoji: "🚗", target: nil, allocated: 0, spent: 0)
            ])
        ]
        self.transactions = []
        self.templates = [
            TransactionTemplate(
                id: UUID(),
                name: "Monthly Rent",
                payee: "Landlord",
                categoryId: rentCategoryId,
                amount: 1200,
                isIncome: false,
                recurrence: TransactionTemplate.Recurrence.monthly
            )
        ]
        
        // Initialize accounts
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
        
        // Create test transactions for wallet account
        let walletId = accounts[0].id  // Get the wallet account ID
        // let groceryCategoryId = categoryGroups[1].categories[0].id  // Not needed anymore
        // let transportCategoryId = categoryGroups[1].categories[1].id  // Not needed anymore
        
        // Create date formatter for test data
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        // Generate regular expenses
        let testTransactions: [Transaction] = [
            // 2022
            createTestTransaction(date: "2022-01-15", amount: 2500, payee: "Main Job Salary", categoryName: "Salary", isIncome: true, accountId: walletId),
            createTestTransaction(date: "2022-01-25", amount: 500, payee: "Freelance Work", categoryName: "Side Hustle", isIncome: true, accountId: walletId),
            createTestTransaction(date: "2022-02-15", amount: 2500, payee: "Main Job Salary", categoryName: "Salary", isIncome: true, accountId: walletId),
            createTestTransaction(date: "2022-03-15", amount: 2500, payee: "Main Job Salary", categoryName: "Salary", isIncome: true, accountId: walletId),
            createTestTransaction(date: "2022-03-20", amount: 1000, payee: "Q1 Bonus", categoryName: "Bonus", isIncome: true, accountId: walletId),
            createTestTransaction(date: "2022-04-15", amount: 2500, payee: "Main Job Salary", categoryName: "Salary", isIncome: true, accountId: walletId),
            
            // Regular expenses (keep existing ones)
            createTestTransaction(date: "2022-01-20", amount: 800, payee: "Landlord", categoryName: "Mortgage/Rent", accountId: walletId),
            createTestTransaction(date: "2022-02-01", amount: 75.50, payee: "Grocery Store", categoryName: "Groceries", accountId: walletId),
            createTestTransaction(date: "2022-02-15", amount: 45.30, payee: "Electric Company", categoryName: "Electric", accountId: walletId),
            createTestTransaction(date: "2022-03-01", amount: 2000, payee: "Salary", isIncome: true, accountId: walletId),
            createTestTransaction(date: "2022-03-10", amount: 120, payee: "Internet Provider", categoryName: "Internet", accountId: walletId),
            createTestTransaction(date: "2022-03-15", amount: 50, payee: "Netflix & Chill", categoryName: "Entertainment", accountId: walletId),
            createTestTransaction(date: "2022-04-01", amount: 1800, payee: "Salary", isIncome: true, accountId: walletId),
            createTestTransaction(date: "2022-04-05", amount: 200, payee: "Car Service", categoryName: "Auto Maintenance", accountId: walletId),
            createTestTransaction(date: "2022-04-15", amount: 60, payee: "Restaurant", categoryName: "Dining Out", accountId: walletId),
            
            // 2024
            createTestTransaction(date: "2024-12-01", amount: 3000, payee: "Main Job Salary", categoryName: "Salary", isIncome: true, accountId: walletId),
            createTestTransaction(date: "2024-12-05", amount: 1000, payee: "Landlord", categoryName: "Mortgage/Rent", accountId: walletId),
            createTestTransaction(date: "2024-12-10", amount: 150, payee: "Phone Company", categoryName: "Phone", accountId: walletId),
            createTestTransaction(date: "2024-12-15", amount: 500, payee: "Emergency Fund", categoryName: "Emergency Fund", accountId: walletId),
            createTestTransaction(date: "2024-12-20", amount: 2000, payee: "Year-End Bonus", categoryName: "Bonus", isIncome: true, accountId: walletId),
            createTestTransaction(date: "2024-12-22", amount: 50, payee: "Bank Interest", categoryName: "Interest", isIncome: true, accountId: walletId),
            
            // 2025
            createTestTransaction(date: "2025-01-01", amount: 3000, payee: "Main Job Salary", categoryName: "Salary", isIncome: true, accountId: walletId),
            createTestTransaction(date: "2025-01-05", amount: 100, payee: "Investment Dividend", categoryName: "Interest", isIncome: true, accountId: walletId)
        ]
        
        // After the wallet test transactions, add credit card transactions
        let cardId = accounts[1].id  // Get the credit card account ID
        
        // Create credit card test transactions
        let cardTransactions: [Transaction] = [
            // 2022
            createTestTransaction(date: "2022-01-05", amount: 89.99, payee: "Amazon", categoryName: "Shopping", accountId: cardId),
            createTestTransaction(date: "2022-01-12", amount: 45.50, payee: "Netflix", categoryName: "Entertainment", accountId: cardId),
            createTestTransaction(date: "2022-01-25", amount: 120.30, payee: "Costco", categoryName: "Groceries", accountId: cardId),
            
            createTestTransaction(date: "2022-02-03", amount: 67.80, payee: "Shell Gas", categoryName: "Auto Maintenance", accountId: cardId),
            createTestTransaction(date: "2022-02-14", amount: 158.90, payee: "Restaurant", categoryName: "Dining Out", accountId: cardId),
            createTestTransaction(date: "2022-02-28", amount: 49.99, payee: "Spotify Annual", categoryName: "Entertainment", accountId: cardId),
            
            // 2024
            createTestTransaction(date: "2024-12-02", amount: 299.99, payee: "Apple", categoryName: "Technology", accountId: cardId),
            createTestTransaction(date: "2024-12-08", amount: 145.50, payee: "H&M", categoryName: "Clothing", accountId: cardId),
            createTestTransaction(date: "2024-12-15", amount: 89.90, payee: "Amazon Prime", categoryName: "Shopping", accountId: cardId),
            createTestTransaction(date: "2024-12-18", amount: 250.00, payee: "Flight Tickets", categoryName: "Vacation", accountId: cardId),
            createTestTransaction(date: "2024-12-22", amount: 180.75, payee: "Best Buy", categoryName: "Technology", accountId: cardId),
            createTestTransaction(date: "2024-12-24", amount: 320.50, payee: "Holiday Gifts", categoryName: "Shopping", accountId: cardId),
            
            // Add cashback/rewards
            createTestTransaction(date: "2022-01-31", amount: 25.50, payee: "Card Cashback", categoryName: "Interest", isIncome: true, accountId: cardId),
            createTestTransaction(date: "2022-02-28", amount: 32.75, payee: "Card Cashback", categoryName: "Interest", isIncome: true, accountId: cardId),
            createTestTransaction(date: "2024-12-31", amount: 85.30, payee: "Card Cashback", categoryName: "Interest", isIncome: true, accountId: cardId),
            
            // Credit Card Payments (keep existing ones)
            createTransferTransaction(date: "2022-01-30", amount: 255.79, fromId: walletId, toId: cardId),
            createTransferTransaction(date: "2022-02-28", amount: 276.69, fromId: walletId, toId: cardId),
            createTransferTransaction(date: "2024-12-28", amount: 1286.64, fromId: walletId, toId: cardId)
        ]
        
        // Update the transactions array to include both wallet and card transactions
        self.transactions = testTransactions + cardTransactions
        
        // Update credit card balance
        if let cardIndex = accounts.firstIndex(where: { $0.id == cardId }) {
            accounts[cardIndex].balance = cardTransactions.reduce(0) { sum, transaction in
                if transaction.toAccountId == cardId {
                    return sum + transaction.amount // Payment reduces negative balance
                } else {
                    return sum - transaction.amount // Purchases increase negative balance
                }
            }
        }
        
        // Update wallet balance
        if let walletIndex = accounts.firstIndex(where: { $0.id == walletId }) {
            accounts[walletIndex].balance = transactions
                .filter { $0.accountId == walletId || $0.toAccountId == walletId }
                .reduce(0.0) { sum, transaction in
                    if transaction.accountId == walletId {
                        if transaction.isTransfer {
                            return sum - transaction.amount // Outgoing transfer
                        } else {
                            return sum + (transaction.isIncome ? transaction.amount : -transaction.amount)
                        }
                    } else if transaction.toAccountId == walletId {
                        return sum + transaction.amount // Incoming transfer
                    }
                    return sum
                }
        }
        
        // Add these predefined groups and categories
        createDefaultCategories()
        
        // Add debug print at the end of init
        debugBalances()
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
    func addCategory(name: String, emoji: String?, groupId: UUID) {
        guard let groupIndex = categoryGroups.firstIndex(where: { $0.id == groupId }) else { return }
        let newCategory = Category(
            id: UUID(),
            name: name,
            emoji: emoji,
            target: nil,
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
        
        // Find category ID by name
        let categoryId: UUID
        if let name = categoryName {
            categoryId = categoryGroups
                .flatMap(\.categories)
                .first(where: { $0.name == name })?.id ?? categoryGroups[0].categories[0].id
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
        // Immediate Obligations
        let immediate = addCategoryGroup(name: "Immediate Obligations", emoji: "🏠")
        addCategory(name: "Mortgage/Rent", emoji: "🏘️", groupId: immediate.id)
        addCategory(name: "Electric", emoji: "⚡", groupId: immediate.id)
        addCategory(name: "Water", emoji: "💧", groupId: immediate.id)
        addCategory(name: "Internet", emoji: "📡", groupId: immediate.id)
        addCategory(name: "Phone", emoji: "📱", groupId: immediate.id)
        addCategory(name: "Groceries", emoji: "🛒", groupId: immediate.id)
        
        // True Expenses
        let trueExpenses = addCategoryGroup(name: "True Expenses", emoji: "📊")
        addCategory(name: "Auto Maintenance", emoji: "🚗", groupId: trueExpenses.id)
        addCategory(name: "Home Maintenance", emoji: "🔧", groupId: trueExpenses.id)
        addCategory(name: "Insurance", emoji: "🛡️", groupId: trueExpenses.id)
        addCategory(name: "Medical", emoji: "🏥", groupId: trueExpenses.id)
        addCategory(name: "Clothing", emoji: "👕", groupId: trueExpenses.id)
        addCategory(name: "Technology", emoji: "💻", groupId: trueExpenses.id)
        
        // Debt Payments
        let debt = addCategoryGroup(name: "Debt Payments", emoji: "💳")
        addCategory(name: "Credit Card", emoji: "💳", groupId: debt.id)
        addCategory(name: "Student Loan", emoji: "🎓", groupId: debt.id)
        addCategory(name: "Car Loan", emoji: "🚙", groupId: debt.id)
        
        // Quality of Life
        let quality = addCategoryGroup(name: "Quality of Life", emoji: "✨")
        addCategory(name: "Dining Out", emoji: "🍽️", groupId: quality.id)
        addCategory(name: "Entertainment", emoji: "🎭", groupId: quality.id)
        addCategory(name: "Shopping", emoji: "🛍️", groupId: quality.id)
        addCategory(name: "Hobbies", emoji: "🎨", groupId: quality.id)
        addCategory(name: "Fitness", emoji: "💪", groupId: quality.id)
        
        // Savings Goals
        let savings = addCategoryGroup(name: "Savings Goals", emoji: "🎯")
        addCategory(name: "Emergency Fund", emoji: "🚨", groupId: savings.id)
        addCategory(name: "Vacation", emoji: "✈️", groupId: savings.id)
        addCategory(name: "New Car", emoji: "🚗", groupId: savings.id)
        addCategory(name: "Home Down Payment", emoji: "🏡", groupId: savings.id)
        addCategory(name: "Retirement", emoji: "👴", groupId: savings.id)
        
        // Income
        let income = addCategoryGroup(name: "Income", emoji: "💰")
        addCategory(name: "Salary", emoji: "💵", groupId: income.id)
        addCategory(name: "Bonus", emoji: "🎉", groupId: income.id)
        addCategory(name: "Interest", emoji: "📈", groupId: income.id)
        addCategory(name: "Side Hustle", emoji: "💪", groupId: income.id)
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
} 
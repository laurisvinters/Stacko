import Foundation
import SwiftUI
import CoreData

class Budget: ObservableObject {
    let dataController: DataController
    private var reloadTask: Task<Void, Never>?
    
    @Published private(set) var accounts: [Account] = []
    @Published private(set) var categoryGroups: [CategoryGroup] = []
    @Published private(set) var transactions: [Transaction] = []
    @Published private(set) var templates: [TransactionTemplate] = []
    
    init(dataController: DataController) {
        self.dataController = dataController
        loadData()
    }
    
    func reload() {
        // Cancel any pending reload
        reloadTask?.cancel()
        
        // Create new reload task with delay
        reloadTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second delay
            if !Task.isCancelled {
                loadData()
            }
        }
    }
    
    private func loadData() {
        accounts = dataController.fetchAllAccounts()
        categoryGroups = dataController.fetchAllCategoryGroups()
        transactions = dataController.fetchAllTransactions()
        templates = dataController.fetchAllTemplates()
    }
    
    // MARK: - Public Methods
    
    func addTransaction(_ transaction: Transaction) {
        dataController.addTransaction(transaction)
        loadData()
    }
    
    func addAccount(name: String, type: Account.AccountType, category: Account.AccountCategory = .personal, icon: String) {
        dataController.addAccount(name: name, type: type, category: category, icon: icon)
        loadData()
    }
    
    func addCategoryGroup(name: String, emoji: String?) {
        _ = dataController.addCategoryGroup(name: name, emoji: emoji)
        loadData()
    }
    
    func addCategory(name: String, emoji: String?, groupId: UUID, target: Target? = nil) {
        dataController.addCategory(name: name, emoji: emoji, groupId: groupId, target: target)
        loadData()
    }
    
    func addTemplate(_ template: TransactionTemplate) {
        dataController.addTemplate(template)
        loadData()
    }
    
    func createTransactionFromTemplate(_ template: TransactionTemplate) {
        dataController.createTransactionFromTemplate(template)
        loadData()
    }
    
    var availableToBudget: Double {
        let totalBalance = accounts
            .filter { !$0.isArchived }
            .reduce(0.0) { sum, account in
                if account.type == .creditCard {
                    return sum + max(0, account.balance)
                }
                return sum + account.balance
            }
        
        let totalAllocated = categoryGroups
            .flatMap(\.categories)
            .reduce(0.0) { $0 + $1.allocated }
        
        return totalBalance - totalAllocated
    }
    
    var monthlyIncome: Double {
        transactions
            .filter { $0.isIncome }
            .reduce(0.0) { $0 + $1.amount }
    }
    
    func findCategory(byId id: UUID) -> (Int, Int)? {
        for (groupIndex, group) in categoryGroups.enumerated() {
            if let categoryIndex = group.categories.firstIndex(where: { $0.id == id }) {
                return (groupIndex, categoryIndex)
            }
        }
        return nil
    }
    
    func allocateToBudget(amount: Double, categoryId: UUID) {
        guard let (groupIndex, categoryIndex) = findCategory(byId: categoryId) else { return }
        dataController.allocateAmount(amount, toCategoryId: categoryId)
        loadData()
    }
    
    func setTarget(for categoryId: UUID, target: Target) {
        dataController.setTarget(for: categoryId, target: target)
        loadData()
    }
    
    func reconcileAccount(id: UUID, balance: Double, date: Date) {
        dataController.reconcileAccount(id: id, balance: balance, date: date)
        loadData()
    }
    
    func createTransfer(from fromId: UUID, to toId: UUID, amount: Double, date: Date, note: String?) {
        dataController.createTransfer(from: fromId, to: toId, amount: amount, date: date, note: note)
        loadData()
    }
} 
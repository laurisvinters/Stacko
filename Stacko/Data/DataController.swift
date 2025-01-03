import Foundation
import CoreData
import SwiftUI

class DataController: ObservableObject {
    let container: NSPersistentContainer
    
    init() {
        container = NSPersistentContainer(name: "StackoModel")
        
        // Add these options for development
        let description = container.persistentStoreDescriptions.first
        description?.setOption(true as NSNumber, forKey: NSMigratePersistentStoresAutomaticallyOption)
        description?.setOption(true as NSNumber, forKey: NSInferMappingModelAutomaticallyOption)
        
        container.loadPersistentStores { description, error in
            if let error = error {
                print("Core Data failed to load: \(error.localizedDescription)")
                // Handle the error appropriately
                fatalError("Failed to load Core Data store: \(error)")
            }
        }
        
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
    
    func save() {
        if container.viewContext.hasChanges {
            do {
                try container.viewContext.save()
            } catch {
                print("Error saving context: \(error)")
                // Handle the error appropriately
                container.viewContext.rollback()
            }
        }
    }
    
    // MARK: - Fetch Methods with Conversion
    
    func fetchAllAccounts() -> [Account] {
        guard let owner = getCurrentUser() else { return [] }
        
        let request = CDAccount.fetchRequest()
        request.predicate = NSPredicate(format: "owner == %@", owner)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CDAccount.name, ascending: true)]
        
        guard let accounts = try? container.viewContext.fetch(request) else { return [] }
        return accounts.compactMap { cdAccount in
            guard let id = cdAccount.id,
                  let name = cdAccount.name,
                  let type = cdAccount.type,
                  let category = cdAccount.category,
                  let icon = cdAccount.icon else { return nil }
            
            return Account(
                id: id,
                name: name,
                type: Account.AccountType(rawValue: type) ?? .checking,
                category: Account.AccountCategory(rawValue: category) ?? .personal,
                balance: cdAccount.balance,
                clearedBalance: cdAccount.clearedBalance,
                icon: icon,
                isArchived: cdAccount.isArchived,
                notes: cdAccount.notes,
                lastReconciled: cdAccount.lastReconciled
            )
        }
    }
    
    func fetchAllCategoryGroups() -> [CategoryGroup] {
        guard let owner = getCurrentUser() else { return [] }
        
        let request = CDCategoryGroup.fetchRequest()
        request.predicate = NSPredicate(format: "owner == %@", owner)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CDCategoryGroup.order, ascending: true)]
        
        guard let groups = try? container.viewContext.fetch(request) else { return [] }
        return groups.compactMap { cdGroup in
            guard let id = cdGroup.id,
                  let name = cdGroup.name else { return nil }
            
            return CategoryGroup(
                id: id,
                name: name,
                emoji: cdGroup.emoji,
                categories: (cdGroup.categories?.allObjects as? [CDCategory])?.compactMap { cdCategory in
                    guard let categoryId = cdCategory.id,
                          let categoryName = cdCategory.name else { return nil }
                    
                    return Category(
                        id: categoryId,
                        name: categoryName,
                        emoji: cdCategory.emoji,
                        target: createTarget(from: cdCategory),
                        allocated: cdCategory.allocated,
                        spent: cdCategory.spent
                    )
                } ?? []
            )
        }
    }
    
    func fetchAllTransactions() -> [Transaction] {
        guard let owner = getCurrentUser() else { return [] }
        
        let request = CDTransaction.fetchRequest()
        request.predicate = NSPredicate(format: "owner == %@", owner)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CDTransaction.date, ascending: false)]
        
        guard let transactions = try? container.viewContext.fetch(request) else { return [] }
        return transactions.compactMap { cdTransaction in
            guard let id = cdTransaction.id,
                  let date = cdTransaction.date,
                  let payee = cdTransaction.payee,
                  let account = cdTransaction.account,
                  let category = cdTransaction.category else { return nil }
            
            return Transaction(
                id: id,
                date: date,
                payee: payee,
                categoryId: category.id ?? UUID(),
                amount: cdTransaction.amount,
                note: cdTransaction.note,
                isIncome: cdTransaction.isIncome,
                accountId: account.id ?? UUID(),
                toAccountId: cdTransaction.toAccount?.id
            )
        }
    }
    
    private func createTarget(from category: CDCategory) -> Target? {
        guard let targetType = category.targetType else { return nil }
        
        switch targetType {
        case "monthly":
            return Target(type: .monthly(amount: category.targetAmount))
        case "weekly":
            return Target(type: .weekly(amount: category.targetAmount))
        case "byDate":
            guard let date = category.targetDate else { return nil }
            return Target(type: .byDate(amount: category.targetAmount, date: date))
        default:
            return nil
        }
    }
    
    private func updateBalances(for transaction: CDTransaction) {
        guard let account = transaction.account else { return }
        
        if transaction.isIncome {
            account.balance += transaction.amount
        } else {
            account.balance -= transaction.amount
        }
        
        if let toAccount = transaction.toAccount {
            toAccount.balance += transaction.amount
        }
    }
    
    // MARK: - Account Methods
    func addAccount(name: String, type: Account.AccountType, category: Account.AccountCategory = .personal, icon: String) {
        guard let owner = getCurrentUser() else { return }
        
        let account = CDAccount(context: container.viewContext)
        account.id = UUID()
        account.name = name
        account.type = type.rawValue
        account.category = category.rawValue
        account.icon = icon
        account.balance = 0
        account.clearedBalance = 0
        account.isArchived = false
        account.owner = owner
        
        save()
    }
    
    // MARK: - Category Methods
    func addCategoryGroup(name: String, emoji: String?) -> CDCategoryGroup {
        guard let owner = getCurrentUser() else { fatalError("No user logged in") }
        
        let group = CDCategoryGroup(context: container.viewContext)
        group.id = UUID()
        group.name = name
        group.emoji = emoji
        group.order = Int16(fetchAllCategoryGroups().count)
        group.owner = owner
        
        save()
        return group
    }
    
    func addCategory(name: String, emoji: String?, groupId: UUID, target: Target? = nil) {
        guard let owner = getCurrentUser(),
              let group = fetchCategoryGroup(id: groupId) else { return }
        
        let category = CDCategory(context: container.viewContext)
        category.id = UUID()
        category.name = name
        category.emoji = emoji
        category.group = group
        category.allocated = 0
        category.spent = 0
        category.owner = owner
        
        if let target = target {
            saveTarget(target, for: category)
        }
        
        save()
    }
    
    // MARK: - Transaction Methods
    func addTransaction(_ transaction: Transaction) {
        guard let owner = getCurrentUser(),
              let account = fetchAccount(id: transaction.accountId),
              let category = fetchCategory(id: transaction.categoryId) else { return }
        
        let cdTransaction = CDTransaction(context: container.viewContext)
        cdTransaction.id = transaction.id
        cdTransaction.date = transaction.date
        cdTransaction.payee = transaction.payee
        cdTransaction.amount = transaction.amount
        cdTransaction.note = transaction.note
        cdTransaction.isIncome = transaction.isIncome
        cdTransaction.account = account
        cdTransaction.category = category
        cdTransaction.owner = owner
        
        if let toAccountId = transaction.toAccountId,
           let toAccount = fetchAccount(id: toAccountId) {
            cdTransaction.toAccount = toAccount
        }
        
        updateBalances(for: cdTransaction)
        save()
    }
    
    private func fetchAccount(id: UUID) -> CDAccount? {
        guard let owner = getCurrentUser() else { return nil }
        
        let request = CDAccount.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@ AND owner == %@", id as CVarArg, owner)
        return try? container.viewContext.fetch(request).first
    }
    
    private func fetchCategory(id: UUID) -> CDCategory? {
        guard let owner = getCurrentUser() else { return nil }
        
        let request = CDCategory.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@ AND owner == %@", id as CVarArg, owner)
        return try? container.viewContext.fetch(request).first
    }
    
    private func fetchCategoryGroup(id: UUID) -> CDCategoryGroup? {
        guard let owner = getCurrentUser() else { return nil }
        
        let request = CDCategoryGroup.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@ AND owner == %@", id as CVarArg, owner)
        return try? container.viewContext.fetch(request).first
    }
    
    private func saveTarget(_ target: Target, for category: CDCategory) {
        switch target.type {
        case .monthly(let amount):
            category.targetType = "monthly"
            category.targetAmount = amount
        case .weekly(let amount):
            category.targetType = "weekly"
            category.targetAmount = amount
        case .byDate(let amount, let date):
            category.targetType = "byDate"
            category.targetAmount = amount
            category.targetDate = date
        }
    }
    
    func allocateAmount(_ amount: Double, toCategoryId categoryId: UUID) {
        guard let category = fetchCategory(id: categoryId) else { return }
        category.allocated += amount
        save()
    }
    
    func reconcileAccount(id: UUID, balance: Double, date: Date) {
        guard let account = fetchAccount(id: id) else { return }
        account.clearedBalance = balance
        account.lastReconciled = date
        save()
    }
    
    func setTarget(for categoryId: UUID, target: Target) {
        guard let category = fetchCategory(id: categoryId) else { return }
        saveTarget(target, for: category)
        save()
    }
    
    func createTransfer(from fromId: UUID, to toId: UUID, amount: Double, date: Date, note: String?) {
        guard let owner = getCurrentUser(),
              let fromAccount = fetchAccount(id: fromId),
              let toAccount = fetchAccount(id: toId) else { return }
        
        let transfer = CDTransaction(context: container.viewContext)
        transfer.id = UUID()
        transfer.date = date
        transfer.payee = "Transfer"
        transfer.amount = amount
        transfer.note = note
        transfer.isIncome = false
        transfer.account = fromAccount
        transfer.toAccount = toAccount
        transfer.owner = owner
        
        updateBalances(for: transfer)
        save()
    }
    
    func addTemplate(_ template: TransactionTemplate) {
        guard let owner = getCurrentUser(),
              let category = fetchCategory(id: template.categoryId) else { return }
        
        let cdTemplate = CDTemplate(context: container.viewContext)
        cdTemplate.id = template.id
        cdTemplate.name = template.name
        cdTemplate.payee = template.payee
        cdTemplate.amount = template.amount
        cdTemplate.isIncome = template.isIncome
        cdTemplate.category = category
        cdTemplate.recurrence = template.recurrence?.rawValue
        cdTemplate.owner = owner
        
        save()
    }
    
    func fetchAllTemplates() -> [TransactionTemplate] {
        guard let owner = getCurrentUser() else { return [] }
        
        let request = CDTemplate.fetchRequest()
        request.predicate = NSPredicate(format: "owner == %@", owner)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CDTemplate.name, ascending: true)]
        
        guard let templates = try? container.viewContext.fetch(request) else { return [] }
        return templates.compactMap { cdTemplate in
            guard let id = cdTemplate.id,
                  let name = cdTemplate.name,
                  let payee = cdTemplate.payee,
                  let category = cdTemplate.category else { return nil }
            
            return TransactionTemplate(
                id: id,
                name: name,
                payee: payee,
                categoryId: category.id ?? UUID(),
                amount: cdTemplate.amount,
                isIncome: cdTemplate.isIncome,
                recurrence: cdTemplate.recurrence.flatMap { TransactionTemplate.Recurrence(rawValue: $0) }
            )
        }
    }
    
    func createTransactionFromTemplate(_ template: TransactionTemplate) {
        guard let owner = getCurrentUser() else { return }
        
        let request = CDAccount.fetchRequest()
        request.predicate = NSPredicate(format: "isArchived == NO AND owner == %@", owner)
        request.fetchLimit = 1
        
        guard let firstAccount = try? container.viewContext.fetch(request).first,
              let accountId = firstAccount.id else { return }
        
        let transaction = Transaction(
            id: UUID(),
            date: Date(),
            payee: template.payee,
            categoryId: template.categoryId,
            amount: template.amount,
            note: "Created from template: \(template.name)",
            isIncome: template.isIncome,
            accountId: accountId,
            toAccountId: nil
        )
        
        addTransaction(transaction)
    }
    
    private func getCurrentUser() -> CDUser? {
        guard let userId = UserDefaults.standard.string(forKey: "currentUserId") else { return nil }
        let request = CDUser.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", userId)
        return try? container.viewContext.fetch(request).first
    }
} 

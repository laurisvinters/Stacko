import Foundation
import CoreData
import SwiftUI

class DataController: ObservableObject {
    let container: NSPersistentContainer
    private var currentUserCache: CDUser?
    private var fetchBatchSize = 20 // Default batch size
    
    // Add caching for frequently accessed data
    private var accountsCache: [Account]?
    private var accountsCacheTimestamp: Date?
    private let cacheDuration: TimeInterval = 5 // 5 seconds cache
    
    init() {
        container = NSPersistentContainer(name: "StackoModel")
        
        // Optimize Core Data configuration
        let description = container.persistentStoreDescriptions.first
        description?.setOption(true as NSNumber, forKey: NSMigratePersistentStoresAutomaticallyOption)
        description?.setOption(true as NSNumber, forKey: NSInferMappingModelAutomaticallyOption)
        description?.type = NSSQLiteStoreType
        
        // Add performance options
        description?.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        description?.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        
        container.loadPersistentStores { _, error in
            if let error = error {
                print("Core Data failed to load: \(error.localizedDescription)")
            }
        }
        
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }
    
    func save() {
        if container.viewContext.hasChanges {
            do {
                try container.viewContext.save()
                // Invalidate caches after saving
                invalidateCache()
            } catch {
                print("Error saving context: \(error)")
                // Handle the error appropriately
                container.viewContext.rollback()
            }
        }
    }
    
    private func invalidateCache() {
        accountsCache = nil
        accountsCacheTimestamp = nil
    }
    
    // MARK: - Fetch Methods with Conversion
    
    func fetchAllAccounts() -> [Account] {
        // Return cached data if valid
        if let cached = accountsCache,
           let timestamp = accountsCacheTimestamp,
           Date().timeIntervalSince(timestamp) < cacheDuration {
            return cached
        }
        
        guard let owner = getCurrentUser() else { return [] }
        
        let request: NSFetchRequest<CDAccount> = CDAccount.fetchRequest()
        request.predicate = NSPredicate(format: "owner == %@", owner)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CDAccount.name, ascending: true)]
        request.fetchBatchSize = fetchBatchSize
        
        do {
            let accounts = try container.viewContext.fetch(request)
            let result = accounts.compactMap { (cdAccount: CDAccount) -> Account? in
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
            
            // Update cache
            accountsCache = result
            accountsCacheTimestamp = Date()
            
            return result
        } catch {
            print("Error fetching accounts: \(error)")
            return []
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
        request.fetchBatchSize = 50
        
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
        
        print("Creating target of type: \(targetType)")  // Debug print
        
        switch targetType {
        case "monthly":
            return Target(type: .monthly(amount: category.targetAmount))
        case "weekly":
            return Target(type: .weekly(amount: category.targetAmount))
        case "byDate":
            guard let date = category.targetDate else { return nil }
            return Target(type: .byDate(amount: category.targetAmount, date: date))
        case "custom":
            guard let intervalType = category.targetIntervalType else { return nil }
            let interval: Target.Interval
            
            switch intervalType {
            case "days":
                interval = .days(count: Int(category.targetDays))
            case "months":
                interval = .months(count: Int(category.targetMonths))
            case "years":
                interval = .years(count: Int(category.targetYears))
            case "monthlyOnDay":
                interval = .monthlyOnDay(day: Int(category.targetMonthDay))
            default:
                return nil
            }
            
            return Target(type: .custom(amount: category.targetAmount, interval: interval))
        case "noDate":
            return Target(type: .noDate(amount: category.targetAmount))
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
    func addAccount(name: String, type: Account.AccountType, category: Account.AccountCategory = .personal, icon: String, balance: Double = 0) {
        guard let owner = getCurrentUser() else { return }
        
        let account = CDAccount(context: container.viewContext)
        account.id = UUID()
        account.name = name
        account.type = type.rawValue
        account.category = category.rawValue
        account.icon = icon
        account.balance = balance
        account.clearedBalance = balance
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
        print("Attempting to save target") // Debug print
        
        // First clear all target-related fields to avoid stale data
        category.targetType = nil
        category.targetAmount = 0
        category.targetDate = nil
        category.targetIntervalType = nil
        category.targetDays = 0
        category.targetMonths = 0
        category.targetYears = 0
        category.targetMonthDay = 0
        
        switch target.type {
        case .monthly(let amount):
            print("Saving monthly target: \(amount)") // Debug print
            category.targetType = "monthly"
            category.targetAmount = amount
            
        case .weekly(let amount):
            print("Saving weekly target: \(amount)") // Debug print
            category.targetType = "weekly"
            category.targetAmount = amount
            
        case .byDate(let amount, let date):
            print("Saving byDate target: \(amount) for \(date)") // Debug print
            category.targetType = "byDate"
            category.targetAmount = amount
            category.targetDate = date
            
        case .custom(let amount, let interval):
            print("Saving custom target: \(amount)") // Debug print
            category.targetType = "custom"
            category.targetAmount = amount
            
            switch interval {
            case .days(let count):
                category.targetIntervalType = "days"
                category.targetDays = Int16(count)
            case .months(let count):
                category.targetIntervalType = "months"
                category.targetMonths = Int16(count)
            case .years(let count):
                category.targetIntervalType = "years"
                category.targetYears = Int16(count)
            case .monthlyOnDay(let day):
                category.targetIntervalType = "monthlyOnDay"
                category.targetMonthDay = Int16(day)
            }
            
        case .noDate(let amount):
            print("Saving noDate target: \(amount)") // Debug print
            category.targetType = "noDate"
            category.targetAmount = amount
        }
        
        save()
        print("Target saved successfully") // Debug print
    }
    
    // Public method for setting targets
    func setTarget(for categoryId: UUID, target: Target?) {
        guard let category = fetchCategory(id: categoryId) else { return }
        
        if let target = target {
            saveTarget(target, for: category)
        } else {
            // Clear all target-related fields
            category.targetType = nil
            category.targetAmount = 0
            category.targetDate = nil
            category.targetIntervalType = nil
            category.targetDays = 0
            category.targetMonths = 0
            category.targetYears = 0
            category.targetMonthDay = 0
        }
        
        save()
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
    
    func getCurrentUser() -> CDUser? {
        // Return cached user if available
        if let cached = currentUserCache {
            return cached
        }
        
        guard let userId = UserDefaults.standard.string(forKey: "currentUserId") else { return nil }
        let request = CDUser.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", userId)
        
        // Cache the result before returning
        currentUserCache = try? container.viewContext.fetch(request).first
        return currentUserCache
    }
    
    // Clear cache when user changes
    func clearCache() {
        currentUserCache = nil
        accountsCache = nil
        accountsCacheTimestamp = nil
    }
    
    func deleteAccount(_ id: UUID) {
        guard let owner = getCurrentUser() else { return }
        
        let request = CDAccount.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@ AND owner == %@", id as CVarArg, owner)
        
        if let account = try? container.viewContext.fetch(request).first {
            // Delete associated transactions first
            let transactionRequest = CDTransaction.fetchRequest()
            transactionRequest.predicate = NSPredicate(format: "account == %@ OR toAccount == %@", account, account)
            
            if let transactions = try? container.viewContext.fetch(transactionRequest) {
                for transaction in transactions {
                    container.viewContext.delete(transaction)
                }
            }
            
            container.viewContext.delete(account)
            save()
        }
    }
    
    func deleteUser(_ id: UUID) {
        let request = CDUser.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        
        if let user = try? container.viewContext.fetch(request).first {
            // Delete all user data
            container.viewContext.delete(user)
            save()
            clearCache()
        }
    }
    
    func transferGuestData(from oldUserId: UUID, to newUserId: UUID) {
        let context = container.viewContext
        
        // Get old and new users
        let userRequest = CDUser.fetchRequest()
        userRequest.predicate = NSPredicate(format: "id IN %@", [oldUserId, newUserId])
        
        guard let users = try? context.fetch(userRequest),
              let oldUser = users.first(where: { $0.id == oldUserId }),
              let newUser = users.first(where: { $0.id == newUserId }) else {
            return
        }
        
        // Transfer accounts
        if let accounts = oldUser.accounts?.allObjects as? [CDAccount] {
            accounts.forEach { account in
                account.owner = newUser
            }
        }
        
        // Transfer categories and groups with their relationships
        if let groups = oldUser.categoryGroups?.allObjects as? [CDCategoryGroup] {
            groups.forEach { group in
                group.owner = newUser
                
                // Ensure categories within the group are also transferred
                if let categories = group.categories?.allObjects as? [CDCategory] {
                    categories.forEach { category in
                        category.owner = newUser
                        category.group = group  // Maintain the relationship
                    }
                }
            }
        }
        
        // Transfer transactions and maintain their category relationships
        if let transactions = oldUser.transactions?.allObjects as? [CDTransaction] {
            transactions.forEach { transaction in
                transaction.owner = newUser
                // No need to update category relationship as it remains the same
            }
        }
        
        // Transfer templates and maintain their category relationships
        if let templates = oldUser.templates?.allObjects as? [CDTemplate] {
            templates.forEach { template in
                template.owner = newUser
                // No need to update category relationship as it remains the same
            }
        }
        
        // Delete the guest user
        context.delete(oldUser)
        
        // Save changes
        do {
            try context.save()
            clearCache() // Clear cache to ensure fresh data is loaded
        } catch {
            print("Error transferring guest data: \(error)")
            context.rollback()
        }
    }
    
    func deleteGroup(_ id: UUID) {
        guard let owner = getCurrentUser() else { return }
        
        let request = CDCategoryGroup.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@ AND owner == %@", id as CVarArg, owner)
        
        if let group = try? container.viewContext.fetch(request).first {
            container.viewContext.delete(group)
            save()
        }
    }
    
    private func loadTarget(from category: CDCategory) -> Target? {
        guard let targetType = category.targetType else { 
            print("No target type found")
            return nil 
        }
        
        print("Loading target: \(targetType), amount: \(category.targetAmount), intervalType: \(category.targetIntervalType ?? "nil")")
        
        switch targetType {
        case "monthly":
            return Target(type: .monthly(amount: category.targetAmount))
        case "weekly":
            return Target(type: .weekly(amount: category.targetAmount))
        case "byDate":
            guard let date = category.targetDate else { 
                print("Missing date for byDate target")
                return nil 
            }
            return Target(type: .byDate(amount: category.targetAmount, date: date))
        case "custom":
            guard let intervalType = category.targetIntervalType else { 
                print("Missing interval type for custom target")
                return nil 
            }
            let interval: Target.Interval
            
            switch intervalType {
            case "days":
                interval = .days(count: Int(category.targetDays))
            case "months":
                interval = .months(count: Int(category.targetMonths))
            case "years":
                interval = .years(count: Int(category.targetYears))
            case "monthlyOnDay":
                interval = .monthlyOnDay(day: Int(category.targetMonthDay))
            default:
                print("Unknown interval type: \(intervalType)")
                return nil
            }
            
            return Target(type: .custom(amount: category.targetAmount, interval: interval))
        case "noDate":
            return Target(type: .noDate(amount: category.targetAmount))
        default:
            print("Unknown target type: \(targetType)")
            return nil
        }
    }
} 

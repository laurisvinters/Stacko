import Foundation
import CoreData
import SwiftUI
import FirebaseFirestore
import FirebaseAuth

class DataController: ObservableObject {
    let container: NSPersistentContainer
    private var currentUserCache: CDUser?
    private var fetchBatchSize = 20 // Default batch size
    
    // Add published properties to trigger UI updates
    @Published private(set) var categoriesLoaded = false
    @Published private(set) var lastSyncTimestamp: Date?
    
    // Add caching for frequently accessed data
    private var accountsCache: [Account]?
    private var accountsCacheTimestamp: Date?
    private let cacheDuration: TimeInterval = 5 // 5 seconds cache
    
    private let db = Firestore.firestore()
    
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
        
        // Configure merge policy to handle duplicates
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
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
        
        let request: NSFetchRequest<CDCategoryGroup> = CDCategoryGroup.fetchRequest()
        request.predicate = NSPredicate(format: "owner == %@", owner)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CDCategoryGroup.order, ascending: true)]
        
        // Add distinct by id to prevent duplicates
        request.returnsDistinctResults = true
        
        do {
            let groups = try container.viewContext.fetch(request)
            return groups
                .filter { $0.id != nil }
                .map { group in
                    // Fetch categories for this group
                    let categoryRequest: NSFetchRequest<CDCategory> = CDCategory.fetchRequest()
                    categoryRequest.predicate = NSPredicate(format: "group == %@ AND owner == %@", group, owner)
                    categoryRequest.sortDescriptors = [NSSortDescriptor(keyPath: \CDCategory.name, ascending: true)]
                
                    // Add distinct by id for categories as well
                    categoryRequest.returnsDistinctResults = true
                
                    let categories = (try? container.viewContext.fetch(categoryRequest)) ?? []
                
                    return CategoryGroup(
                        id: group.id!,  // Safe to force unwrap since we filtered nil values
                        name: group.name ?? "",
                        emoji: group.emoji,
                        categories: categories.compactMap { category in
                            guard let categoryId = category.id else { return nil }
                            return Category(
                                id: categoryId,
                                name: category.name ?? "",
                                emoji: category.emoji,
                                target: createTarget(from: category),
                                allocated: category.allocated,
                                spent: category.spent
                            )
                        }
                    )
                }
        } catch {
            print("Error fetching category groups: \(error)")
            return []
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
    func addCategoryGroup(name: String, emoji: String?) -> CDCategoryGroup? {
        guard let owner = getCurrentUser() else {
            print("⚠️ No user logged in")
            return nil
        }
        
        print("📝 Creating category group: \(name)")
        
        let group = CDCategoryGroup(context: container.viewContext)
        group.id = UUID()
        group.name = name
        group.emoji = emoji
        group.order = Int16(fetchAllCategoryGroups().count)
        group.owner = owner
        
        save()
        
        // Save to Firestore if user is authenticated
        if let userId = Auth.auth().currentUser?.uid {
            let groupData: [String: Any] = [
                "id": group.id?.uuidString ?? "",
                "name": name,
                "emoji": emoji ?? "",
                "order": group.order
            ]
            
            print("🔄 Saving group to Firestore: \(groupData)")
            
            db.collection("users").document(userId)
                .collection("categoryGroups").document(group.id?.uuidString ?? "")
                .setData(groupData) { error in
                    if let error = error {
                        print("❌ Error saving category group to Firestore: \(error)")
                    } else {
                        print("✅ Successfully saved group to Firestore")
                    }
                }
        } else {
            print("⚠️ No authenticated user, skipping Firestore save")
        }
        
        return group
    }
    
    func addCategory(name: String, emoji: String?, groupId: UUID, target: Target? = nil) {
        guard let owner = getCurrentUser(),
              let group = fetchCategoryGroup(id: groupId) else { return }
        
        print("📝 Creating category: \(name) in group: \(group.name ?? "")")
        
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
        
        // Save to Firestore if user is authenticated
        if let userId = Auth.auth().currentUser?.uid {
            var categoryData: [String: Any] = [
                "id": category.id?.uuidString ?? "",
                "name": name,
                "emoji": emoji ?? "",
                "groupId": groupId.uuidString,
                "allocated": 0,
                "spent": 0
            ]
            
            // Add target data if exists
            if let target = target {
                switch target.type {
                case .monthly(let amount):
                    categoryData["targetType"] = "monthly"
                    categoryData["targetAmount"] = amount
                case .weekly(let amount):
                    categoryData["targetType"] = "weekly"
                    categoryData["targetAmount"] = amount
                case .byDate(let amount, let date):
                    categoryData["targetType"] = "byDate"
                    categoryData["targetAmount"] = amount
                    categoryData["targetDate"] = date
                }
            }
            
            print("🔄 Saving category to Firestore: \(categoryData)")
            
            db.collection("users").document(userId)
                .collection("categories").document(category.id?.uuidString ?? "")
                .setData(categoryData) { error in
                    if let error = error {
                        print("❌ Error saving category to Firestore: \(error)")
                    } else {
                        print("✅ Successfully saved category to Firestore")
                    }
                }
        } else {
            print("⚠️ No authenticated user, skipping Firestore save")
        }
    }
    
    // Add method to fetch categories from Firestore
    func syncCategoriesFromFirestore() {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("⚠️ No user ID available for syncing")
            return
        }
        
        print("🔄 Starting Firestore sync for user: \(userId)")
        
        // Reset sync state
        categoriesLoaded = false
        
        // Create a background context for all operations
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        // Fetch category groups
        db.collection("users").document(userId)
            .collection("categoryGroups")
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("❌ Error fetching category groups: \(error)")
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    print("⚠️ No category groups found")
                    return
                }
                
                print("📦 Found \(documents.count) category groups")
                
                // Perform all operations in the background context
                context.performAndWait {
                    // First, fetch the current user in this context
                    let userRequest = CDUser.fetchRequest()
                    userRequest.predicate = NSPredicate(format: "email == %@", self.getCurrentUser()?.email ?? "")
                    guard let owner = try? context.fetch(userRequest).first else {
                        print("❌ Could not find user in context")
                        return
                    }
                    
                    // Create a mapping of group IDs to Core Data objects
                    var groupMapping: [String: CDCategoryGroup] = [:]
                    
                    do {
                        // Process all groups
                        for document in documents {
                            let data = document.data()
                            print("📝 Processing group: \(data)")
                            
                            guard let idString = data["id"] as? String,
                                  let id = UUID(uuidString: idString),
                                  let name = data["name"] as? String else {
                                print("❌ Invalid group data: \(data)")
                                continue
                            }
                            
                            // Try to find existing group or create new one
                            let groupRequest = CDCategoryGroup.fetchRequest()
                            groupRequest.predicate = NSPredicate(format: "id == %@ AND owner == %@", id as CVarArg, owner)
                            let group = try context.fetch(groupRequest).first ?? CDCategoryGroup(context: context)
                            
                            // Update group properties
                            group.id = id
                            group.name = name
                            group.emoji = data["emoji"] as? String
                            group.order = Int16(data["order"] as? Int ?? 0)
                            group.owner = owner
                            
                            // Store in mapping
                            groupMapping[idString] = group
                            
                            print("✅ Processed group: \(name)")
                        }
                        
                        // Save context after processing groups
                        try context.save()
                        print("💾 Saved category groups to Core Data")
                        
                        // After groups are saved, fetch categories
                        self.fetchCategoriesFromFirestore(userId: userId, groupMapping: groupMapping, context: context)
                    } catch {
                        print("❌ Error saving category groups: \(error)")
                        context.rollback()
                    }
                }
            }
    }
    
    private func fetchCategoriesFromFirestore(userId: String, groupMapping: [String: CDCategoryGroup], context: NSManagedObjectContext) {
        print("🔄 Starting category fetch for user: \(userId)")
        
        db.collection("users").document(userId)
            .collection("categories")
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("❌ Error fetching categories: \(error)")
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    print("⚠️ No categories found")
                    return
                }
                
                print("📦 Found \(documents.count) categories")
                
                // Perform all operations in the background context
                context.performAndWait {
                    do {
                        for document in documents {
                            let data = document.data()
                            print("📝 Processing category: \(data)")
                            
                            guard let idString = data["id"] as? String,
                                  let id = UUID(uuidString: idString),
                                  let name = data["name"] as? String,
                                  let groupIdString = data["groupId"] as? String,
                                  let group = groupMapping[groupIdString] else {
                                print("❌ Invalid category data or missing group: \(data)")
                                continue
                            }
                            
                            // Try to find existing category or create new one
                            let categoryRequest = CDCategory.fetchRequest()
                            categoryRequest.predicate = NSPredicate(format: "id == %@ AND owner == %@", id as CVarArg, group.owner!)
                            let category = try context.fetch(categoryRequest).first ?? CDCategory(context: context)
                            
                            // Update category properties
                            category.id = id
                            category.name = name
                            category.emoji = data["emoji"] as? String
                            category.allocated = data["allocated"] as? Double ?? 0
                            category.spent = data["spent"] as? Double ?? 0
                            category.group = group
                            category.owner = group.owner
                            
                            // Handle target if present
                            if let targetType = data["targetType"] as? String {
                                switch targetType {
                                case "monthly", "weekly":
                                    if let amount = data["targetAmount"] as? Double {
                                        category.targetType = targetType
                                        category.targetAmount = amount
                                    }
                                case "byDate":
                                    if let amount = data["targetAmount"] as? Double,
                                       let date = data["targetDate"] as? Date {
                                        category.targetType = targetType
                                        category.targetAmount = amount
                                        category.targetDate = date
                                    }
                                default:
                                    break
                                }
                            }
                            
                            print("✅ Processed category: \(name) in group: \(group.name ?? "")")
                        }
                        
                        // Save all changes
                        try context.save()
                        print("💾 Saved all categories to Core Data")
                        
                        // Update UI state on main thread
                        DispatchQueue.main.async {
                            self.categoriesLoaded = true
                            self.lastSyncTimestamp = Date()
                            self.objectWillChange.send()
                            
                            // Force a UI refresh by reloading data in the main context
                            self.container.viewContext.refreshAllObjects()
                            
                            // Post notification for views to refresh
                            NotificationCenter.default.post(
                                name: NSNotification.Name("RefreshCategoriesView"),
                                object: nil
                            )
                        }
                    } catch {
                        print("❌ Error saving categories: \(error)")
                        context.rollback()
                    }
                }
            }
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
    
    // MARK: - User Management
    
    func getCurrentUser() -> CDUser? {
        if let cached = currentUserCache {
            return cached
        }
        
        let request: NSFetchRequest<CDUser> = CDUser.fetchRequest()
        request.fetchLimit = 1
        
        do {
            let users = try container.viewContext.fetch(request)
            currentUserCache = users.first
            return users.first
        } catch {
            print("Error fetching current user: \(error)")
            return nil
        }
    }
    
    func createUser(id: UUID, email: String) -> CDUser {
        let user = CDUser(context: container.viewContext)
        user.id = id
        user.email = email
        user.createdAt = Date()
        
        save()
        currentUserCache = user
        return user
    }
    
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
    
    func clearUserData() {
        let context = container.viewContext
        
        // Delete all user-related data
        let requests = [
            NSFetchRequest<NSFetchRequestResult>(entityName: "CDCategoryGroup"),
            NSFetchRequest<NSFetchRequestResult>(entityName: "CDCategory"),
            NSFetchRequest<NSFetchRequestResult>(entityName: "CDAccount"),
            NSFetchRequest<NSFetchRequestResult>(entityName: "CDTransaction"),
            NSFetchRequest<NSFetchRequestResult>(entityName: "CDTemplate")
        ]
        
        for request in requests {
            if let currentUser = getCurrentUser() {
                request.predicate = NSPredicate(format: "owner == %@", currentUser)
            }
            
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
            deleteRequest.resultType = .resultTypeObjectIDs
            
            do {
                let result = try context.execute(deleteRequest) as? NSBatchDeleteResult
                let changes: [AnyHashable: Any] = [
                    NSDeletedObjectsKey: result?.result as? [NSManagedObjectID] ?? []
                ]
                NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [context])
            } catch {
                print("Error clearing user data: \(error)")
            }
        }
        
        clearCache()
        save()
    }
} 

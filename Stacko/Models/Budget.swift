import Foundation
import SwiftUI
import FirebaseFirestore
import FirebaseAuth

class Budget: ObservableObject {
    private let db = Firestore.firestore()
    @Published private(set) var accounts: [Account] = []
    @Published private(set) var categoryGroups: [CategoryGroup] = []
    @Published private(set) var transactions: [Transaction] = []
    @Published private(set) var allocations: [Allocation] = []
    @Published private(set) var isSetupComplete: Bool? = nil
    @Published private(set) var availableToBudget: Double = 0.0
    
    private var listeners: [ListenerRegistration] = []
    private var isReorderingGroups = false
    private var isDeletingGroup = false {
        didSet {
            print("Budget: isDeletingGroup set to \(isDeletingGroup)")
        }
    }
    
    init() {
        // Listeners will be set up by AuthenticationManager when user is ready
    }
    
    func reset() {
        // Remove all listeners
        listeners.forEach { $0.remove() }
        listeners.removeAll()
        
        // Clear all data
        accounts = []
        categoryGroups = []
        transactions = []
        allocations = []
        isSetupComplete = nil
    }
    
    func setupListeners() {
        // Remove any existing listeners
        listeners.forEach { $0.remove() }
        listeners.removeAll()
        
        guard let userId = Auth.auth().currentUser?.uid else {
            print("Budget: No user ID available for listeners")
            // Set default state when no user is available
            DispatchQueue.main.async { [weak self] in
                self?.isSetupComplete = false
            }
            return
        }
        
        print("Budget: Setting up listeners for user \(userId)")
        
        // Get user settings immediately and then listen for changes
        let userDocRef = db.collection("users").document(userId)
        userDocRef.getDocument { [weak self] snapshot, error in
            if let error = error {
                print("Budget: Error fetching initial user settings: \(error.localizedDescription)")
                // Set default state on error
                DispatchQueue.main.async {
                    self?.isSetupComplete = false
                }
                return
            }
            
            DispatchQueue.main.async {
                if let data = snapshot?.data() {
                    self?.isSetupComplete = data["isSetupComplete"] as? Bool ?? false
                } else {
                    // Document doesn't exist yet, set default state
                    self?.isSetupComplete = false
                }
                print("Budget: Initial setup completion state: \(self?.isSetupComplete ?? false)")
            }
        }
        
        // Listen for user settings changes
        let settingsListener = userDocRef
            .addSnapshotListener { [weak self] snapshot, error in
                if let error = error {
                    print("Budget: Error fetching user settings: \(error.localizedDescription)")
                    return
                }
                
                if let data = snapshot?.data() {
                    self?.isSetupComplete = data["isSetupComplete"] as? Bool ?? false
                    print("Budget: Setup completion state: \(self?.isSetupComplete ?? false)")
                }
            }
        listeners.append(settingsListener)
            
        // Listen for accounts changes
        let accountsListener = db.collection("users").document(userId).collection("accounts")
            .addSnapshotListener { [weak self] snapshot, error in
                if let error = error {
                    print("DEBUG: Error fetching accounts: \(error.localizedDescription)")
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    print("DEBUG: No account documents found")
                    return
                }
                
                print("DEBUG: Received \(documents.count) account documents")
                self?.accounts = documents.compactMap { document in
                    guard let account = Account.fromFirestore(document.data()) else {
                        print("DEBUG: Failed to parse account document \(document.documentID)")
                        return nil
                    }
                    print("DEBUG: Parsed account: \(account)")
                    return account
                }
                
                // Update availableToBudget to match first non-archived account's balance
                if let firstAccount = self?.accounts.first(where: { !$0.isArchived }) {
                    self?.availableToBudget = firstAccount.balance
                    print("DEBUG: Updated availableToBudget to \(firstAccount.balance)")
                }
                
                print("DEBUG: Updated accounts array with \(self?.accounts.count ?? 0) accounts: \(String(describing: self?.accounts))")
            }
        listeners.append(accountsListener)
        
        setupGroupsListener(userId: userId)
        
        // Listen for transactions changes
        let transactionsListener = db.collection("users").document(userId).collection("transactions")
            .addSnapshotListener { [weak self] snapshot, error in
                if let error = error {
                    print("Budget: Error fetching transactions: \(error.localizedDescription)")
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    print("Budget: No transaction documents found")
                    return
                }
                
                print("Budget: Received \(documents.count) transaction documents")
                self?.transactions = documents.compactMap { document in
                    guard let transaction = Transaction.fromFirestore(document.data()) else {
                        print("Budget: Failed to parse transaction document \(document.documentID)")
                        return nil
                    }
                    return transaction
                }
                print("Budget: Updated transactions array with \(self?.transactions.count ?? 0) transactions")
            }
        listeners.append(transactionsListener)
        
        // Listen for allocations changes
        let allocationsListener = db.collection("users").document(userId).collection("allocations")
            .addSnapshotListener { [weak self] snapshot, error in
                if let error = error {
                    print("Budget: Error fetching allocations: \(error.localizedDescription)")
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    print("Budget: No allocation documents found")
                    return
                }
                
                let allocations = documents.compactMap { Allocation.fromFirestore($0.data()) }
                DispatchQueue.main.async {
                    self?.allocations = allocations
                }
            }
        listeners.append(allocationsListener)
    }
    
    private func setupGroupsListener(userId: String) {
        // Listen for category groups changes
        let groupsListener = db.collection("users").document(userId).collection("categoryGroups")
            .order(by: "order")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("Budget: Error fetching category groups: \(error.localizedDescription)")
                    return
                }
                
                // Skip updates while reordering or deleting to prevent race conditions
                if self.isReorderingGroups || self.isDeletingGroup {
                    print("Budget: Skipping groups update due to reordering(\(self.isReorderingGroups)) or deleting(\(self.isDeletingGroup))")
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    print("Budget: No category group documents found")
                    return
                }
                
                print("Budget: Processing \(documents.count) group documents")
                self.categoryGroups = documents.compactMap { document in
                    guard let group = CategoryGroup.fromFirestore(document.data()) else {
                        print("Budget: Failed to parse category group document \(document.documentID)")
                        return nil
                    }
                    return group
                }
            }
        listeners.append(groupsListener)
    }
    
    func completeSetup() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        db.collection("users").document(userId)
            .setData(["isSetupComplete": true], merge: true) { error in
                if let error = error {
                    print("Budget: Error marking setup as complete: \(error.localizedDescription)")
                }
            }
    }
    
    func addAccount(name: String, type: Account.AccountType, category: Account.AccountCategory = .personal, icon: String, balance: Double = 0) {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        let account = Account(
            id: UUID(),
            name: name,
            type: type,
            category: category,
            balance: balance,
            clearedBalance: balance,
            icon: icon,
            isArchived: false,
            initialBalance: balance,
            createdAt: Date()
        )
        
        let batch = db.batch()
        
        // Add account document
        let accountRef = db.collection("users").document(userId)
            .collection("accounts")
            .document(account.id.uuidString)
        batch.setData(account.toFirestore(), forDocument: accountRef)
        
        // Add initial balance transaction if needed
        if balance != 0,
           let firstGroup = categoryGroups.first,
           let firstCategory = firstGroup.categories.first {
            let transaction = Transaction(
                id: UUID(),
                date: account.createdAt,
                payee: "Initial Balance",
                categoryId: firstCategory.id,
                amount: balance,
                note: "Initial balance for \(name)",
                isIncome: true,
                accountId: account.id,
                toAccountId: nil
            )
            
            let transactionRef = db.collection("users").document(userId)
                .collection("transactions")
                .document(transaction.id.uuidString)
            batch.setData(transaction.toFirestore(), forDocument: transactionRef)
        }
        
        // Commit the batch
        batch.commit { error in
            if let error = error {
                print("Budget: Error adding account: \(error.localizedDescription)")
            }
        }
    }
    
    @discardableResult
    func addCategoryGroup(name: String, emoji: String?) -> CategoryGroup {
        guard let userId = Auth.auth().currentUser?.uid else {
            fatalError("No user logged in")
        }
        
        let group = CategoryGroup(
            id: UUID(),
            name: name,
            emoji: emoji,
            categories: []
        )
        
        db.collection("users").document(userId)
            .collection("categoryGroups")
            .document(group.id.uuidString)
            .setData(group.toFirestore()) { error in
                if let error = error {
                    print("Error adding category group: \(error.localizedDescription)")
                }
            }
        
        return group
    }
    
    func addCategory(name: String, emoji: String?, groupId: UUID, target: Target? = nil) {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        let category = Category(
            id: UUID(),
            name: name,
            emoji: emoji,
            target: target,
            allocated: 0,
            spent: 0
        )
        
        // Get the current group document
        let groupRef = db.collection("users").document(userId)
            .collection("categoryGroups")
            .document(groupId.uuidString)
        
        // Update the categories array
        groupRef.getDocument { [weak self] document, error in
            guard let document = document,
                  var group = CategoryGroup.fromFirestore(document.data() ?? [:]) else { return }
            
            group.categories.append(category)
            
            groupRef.setData(group.toFirestore()) { error in
                if let error = error {
                    print("Error updating category group: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func deleteAccount(_ id: UUID) {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        let batch = db.batch()
        
        // Delete the account document
        let accountRef = db.collection("users").document(userId)
            .collection("accounts")
            .document(id.uuidString)
        batch.deleteDocument(accountRef)
        
        // Find all transactions related to this account
        let relatedTransactions = transactions.filter { transaction in
            transaction.accountId == id || transaction.toAccountId == id
        }
        
        // Track affected categories and their allocation adjustments
        var categoryAdjustments: [UUID: Double] = [:]
        
        // Process each transaction
        for transaction in relatedTransactions {
            // Delete the transaction
            let transactionRef = db.collection("users").document(userId)
                .collection("transactions")
                .document(transaction.id.uuidString)
            batch.deleteDocument(transactionRef)
            
            // If this is a transfer, update the other account's balance
            if let otherAccountId = transaction.toAccountId == id ? transaction.accountId : transaction.toAccountId,
               let otherAccountIndex = accounts.firstIndex(where: { $0.id == otherAccountId }) {
                var updatedAccount = accounts[otherAccountIndex]
                let adjustmentAmount = transaction.toAccountId == id ? -transaction.amount : transaction.amount
                updatedAccount.balance -= adjustmentAmount
                updatedAccount.clearedBalance -= adjustmentAmount
                
                let otherAccountRef = db.collection("users").document(userId)
                    .collection("accounts")
                    .document(otherAccountId.uuidString)
                batch.setData(updatedAccount.toFirestore(), forDocument: otherAccountRef)
            }
            
            // If this is not a transfer, track category adjustments
            if transaction.toAccountId == nil {
                let categoryId = transaction.categoryId
                categoryAdjustments[categoryId, default: 0] += transaction.amount
            }
        }
        
        // Update affected categories
        for (categoryId, adjustment) in categoryAdjustments {
            if let (groupIndex, categoryIndex) = findCategory(byId: categoryId) {
                var updatedGroup = categoryGroups[groupIndex]
                var updatedCategory = updatedGroup.categories[categoryIndex]
                
                // Update spent amount
                if !updatedCategory.spent.isZero {
                    updatedCategory.spent += adjustment
                }
                
                // Find and delete related allocations
                let categoryAllocations = allocations.filter { $0.categoryId == categoryId }
                for allocation in categoryAllocations {
                    let allocationRef = db.collection("users").document(userId)
                        .collection("allocations")
                        .document(allocation.id.uuidString)
                    batch.deleteDocument(allocationRef)
                    
                    // Update allocated amount
                    updatedCategory.allocated -= allocation.amount
                }
                
                updatedGroup.categories[categoryIndex] = updatedCategory
                
                let groupRef = db.collection("users").document(userId)
                    .collection("categoryGroups")
                    .document(updatedGroup.id.uuidString)
                batch.setData(updatedGroup.toFirestore(), forDocument: groupRef)
            }
        }
        
        // Commit all changes
        batch.commit { error in
            if let error = error {
                print("Error deleting account and related data: \(error.localizedDescription)")
            }
        }
    }
    
    func addTransaction(_ transaction: Transaction) {
        guard let userId = Auth.auth().currentUser?.uid,
              let _ = Auth.auth().currentUser else {
            print("Budget: Cannot add transaction - no user ID")
            return
        }
        
        print("Budget: Adding transaction \(transaction.id) for user \(userId)")
        
        // Find category and account indices before starting the batch
        guard let (groupIndex, categoryIndex) = findCategory(byId: transaction.categoryId),
              let accountIndex = accounts.firstIndex(where: { $0.id == transaction.accountId }) else {
            print("Budget: Cannot find category or account for transaction")
            return
        }
        
        let batch = db.batch()
        
        // Add transaction document
        let transactionRef = db.collection("users").document(userId)
            .collection("transactions")
            .document(transaction.id.uuidString)
        batch.setData(transaction.toFirestore(), forDocument: transactionRef)
        
        // Update category's spent amount for expenses or allocated amount for income
        var updatedGroup = categoryGroups[groupIndex]
        if transaction.isIncome {
            // For income, increase the allocated amount
            updatedGroup.categories[categoryIndex].allocated += transaction.amount
        } else {
            // For expenses, transaction.amount is already negative
            // We want to increase spent by the positive amount
            updatedGroup.categories[categoryIndex].spent -= transaction.amount
        }
        
        let groupRef = db.collection("users").document(userId)
            .collection("categoryGroups")
            .document(updatedGroup.id.uuidString)
        
        // Preserve all existing data and only update the categories
        let groupData: [String: Any] = [
            "categories": updatedGroup.categories.map { $0.toFirestore() }
        ]
        batch.setData(groupData, forDocument: groupRef, merge: true)
        
        // Update account balance
        var updatedAccount = accounts[accountIndex]
        updatedAccount.balance += transaction.amount
        // For now, assume all transactions affect cleared balance
        updatedAccount.clearedBalance += transaction.amount
        
        let accountRef = db.collection("users").document(userId)
            .collection("accounts")
            .document(updatedAccount.id.uuidString)
        batch.setData(updatedAccount.toFirestore(), forDocument: accountRef)
        
        // Commit all changes
        batch.commit { error in
            if let error = error {
                print("Budget: Error adding transaction: \(error.localizedDescription)")
            } else {
                print("Budget: Successfully added transaction \(transaction.id)")
            }
        }
    }
    
    func findCategory(byId id: UUID) -> (Int, Int)? {
        for (groupIndex, group) in categoryGroups.enumerated() {
            if let categoryIndex = group.categories.firstIndex(where: { $0.id == id }) {
                return (groupIndex, categoryIndex)
            }
        }
        return nil
    }
    
    func setTarget(for categoryId: UUID, target: Target) {
        guard let userId = Auth.auth().currentUser?.uid,
              let (groupIndex, categoryIndex) = findCategory(byId: categoryId) else { return }
        
        var updatedGroup = categoryGroups[groupIndex]
        updatedGroup.categories[categoryIndex].target = target
        
        // Only update the categories field to preserve other fields like order
        let groupData: [String: Any] = [
            "categories": updatedGroup.categories.map { $0.toFirestore() }
        ]
        
        db.collection("users").document(userId)
            .collection("categoryGroups")
            .document(updatedGroup.id.uuidString)
            .setData(groupData, merge: true) { error in
                if let error = error {
                    print("Error updating category target: \(error.localizedDescription)")
                }
            }
    }
    
    func allocateToBudget(amount: Double, categoryId: UUID) {
        guard let userId = Auth.auth().currentUser?.uid,
              let (groupIndex, categoryIndex) = findCategory(byId: categoryId) else { return }
        
        print("Budget: Starting allocation of \(amount) to category \(categoryId)")
        
        // Calculate total allocated amount after this allocation
        var totalAllocated = amount
        for group in categoryGroups {
            for category in group.categories {
                totalAllocated += category.allocated
            }
        }
        
        // Check if we have enough to allocate
        let totalAvailable = accounts.filter { !$0.isArchived }.reduce(0) { $0 + $1.balance }
        if totalAllocated > totalAvailable {
            print("Budget: Error - Not enough available to budget")
            return
        }
        
        // Create a new allocation record
        let allocation = Allocation(
            id: UUID(),
            date: Date(),
            categoryId: categoryId,
            amount: amount
        )
        
        let batch = db.batch()
        
        // Add allocation document
        let allocationRef = db.collection("users").document(userId)
            .collection("allocations")
            .document(allocation.id.uuidString)
        batch.setData(allocation.toFirestore(), forDocument: allocationRef)
        
        // Update category's allocated amount for tracking
        var updatedGroup = categoryGroups[groupIndex]
        updatedGroup.categories[categoryIndex].allocated += amount
        
        // Update category group in Firestore
        let groupRef = db.collection("users").document(userId)
            .collection("categoryGroups")
            .document(updatedGroup.id.uuidString)
        
        // Get the existing document to preserve the order field
        groupRef.getDocument { [weak self] (document, error) in
            guard let self = self else { return }
            
            var groupData = updatedGroup.toFirestore()
            if let document = document,
               let existingData = document.data(),
               let existingOrder = existingData["order"] as? Int {
                groupData["order"] = existingOrder
            }
            batch.setData(groupData, forDocument: groupRef, merge: true)
            
            // Update local state immediately
            categoryGroups[groupIndex] = updatedGroup
            
            // Temporarily disable reordering flag to allow the update
            let wasReordering = isReorderingGroups
            isReorderingGroups = false
            
            // Commit all changes
            batch.commit { [weak self] error in
                guard let self = self else { return }
                
                if let error = error {
                    print("Budget: Error allocating to budget: \(error.localizedDescription)")
                    // Revert local state on error
                    self.setupListeners()
                } else {
                    print("Budget: Successfully allocated \(amount) to category \(categoryId)")
                }
                
                // Restore the reordering flag
                DispatchQueue.main.async {
                    self.isReorderingGroups = wasReordering
                }
            }
        }
    }
    
    func deleteGroup(_ id: UUID) {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        guard let groupIndex = categoryGroups.firstIndex(where: { $0.id == id }) else { return }
        
        // Set flag to prevent listener updates
        isDeletingGroup = true
        print("Budget: Starting group deletion for group \(id)")
        
        // Update local state immediately
        categoryGroups.remove(at: groupIndex)
        
        // Get reference to the group document
        let groupRef = db.collection("users").document(userId)
            .collection("categoryGroups").document(id.uuidString)
        
        // Delete the group document (categories are stored within the group document)
        groupRef.delete { [weak self] error in
            guard let self = self else { return }
            
            if let error = error {
                print("Budget: Error deleting group: \(error.localizedDescription)")
            } else {
                print("Budget: Successfully deleted group \(id)")
            }
            
            // Reset the flag after a delay to ensure Firebase has processed the deletion
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self.isDeletingGroup = false
                print("Budget: Completed group deletion process")
            }
        }
    }
    
    func reconcileAccount(_ id: UUID, clearedBalance: Double) {
        guard let userId = Auth.auth().currentUser?.uid,
              let account = accounts.first(where: { $0.id == id }) else { return }
        
        var updatedAccount = account
        updatedAccount.clearedBalance = clearedBalance
        updatedAccount.lastReconciled = Date()
        
        db.collection("users").document(userId)
            .collection("accounts")
            .document(id.uuidString)
            .setData(updatedAccount.toFirestore()) { error in
                if let error = error {
                    print("Error reconciling account: \(error.localizedDescription)")
                }
            }
    }
    
    func createTransfer(fromAccountId: UUID, toAccountId: UUID, amount: Double, date: Date, note: String?) {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        let batch = db.batch()
        
        // Create withdrawal transaction
        let withdrawal = Transaction(
            id: UUID(),
            date: date,
            payee: "Transfer",
            categoryId: categoryGroups.first?.categories.first?.id ?? UUID(),
            amount: -amount,
            note: note,
            isIncome: false,
            accountId: fromAccountId,
            toAccountId: toAccountId
        )
        
        // Create deposit transaction
        let deposit = Transaction(
            id: UUID(),
            date: date,
            payee: "Transfer",
            categoryId: categoryGroups.first?.categories.first?.id ?? UUID(),
            amount: amount,
            note: note,
            isIncome: true,
            accountId: toAccountId,
            toAccountId: fromAccountId
        )
        
        // Add withdrawal transaction
        let withdrawalRef = db.collection("users").document(userId)
            .collection("transactions")
            .document(withdrawal.id.uuidString)
        batch.setData(withdrawal.toFirestore(), forDocument: withdrawalRef)
        
        // Add deposit transaction
        let depositRef = db.collection("users").document(userId)
            .collection("transactions")
            .document(deposit.id.uuidString)
        batch.setData(deposit.toFirestore(), forDocument: depositRef)
        
        // Update source account balance
        if let fromAccountIndex = accounts.firstIndex(where: { $0.id == fromAccountId }) {
            var updatedFromAccount = accounts[fromAccountIndex]
            updatedFromAccount.balance -= amount
            updatedFromAccount.clearedBalance -= amount
            
            let fromAccountRef = db.collection("users").document(userId)
                .collection("accounts")
                .document(fromAccountId.uuidString)
            batch.setData(updatedFromAccount.toFirestore(), forDocument: fromAccountRef)
        }
        
        // Update destination account balance
        if let toAccountIndex = accounts.firstIndex(where: { $0.id == toAccountId }) {
            var updatedToAccount = accounts[toAccountIndex]
            updatedToAccount.balance += amount
            updatedToAccount.clearedBalance += amount
            
            let toAccountRef = db.collection("users").document(userId)
                .collection("accounts")
                .document(toAccountId.uuidString)
            batch.setData(updatedToAccount.toFirestore(), forDocument: toAccountRef)
        }
        
        // Update categories if needed
        if let (fromGroupIndex, fromCategoryIndex) = findCategory(byId: withdrawal.categoryId) {
            var updatedGroup = categoryGroups[fromGroupIndex]
            updatedGroup.categories[fromCategoryIndex].spent -= amount
            
            let groupRef = db.collection("users").document(userId)
                .collection("categoryGroups")
                .document(updatedGroup.id.uuidString)
            batch.setData(updatedGroup.toFirestore(), forDocument: groupRef)
        }
        
        // Commit all changes
        batch.commit { error in
            if let error = error {
                print("Error creating transfer: \(error.localizedDescription)")
            }
        }
    }
    
    func saveCategoryGroups(_ groups: [CategoryGroup]) {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        print("Budget: Starting to save \(groups.count) category groups")
        
        // Set reordering flag to prevent listener updates during setup
        isReorderingGroups = true
        
        let batch = db.batch()
        
        // Add order field to each group
        for (index, group) in groups.enumerated() {
            let groupRef = db.collection("users").document(userId)
                .collection("categoryGroups")
                .document(group.id.uuidString)
            
            var groupData = group.toFirestore()
            groupData["order"] = index
            
            batch.setData(groupData, forDocument: groupRef)
            print("Budget: Added group \(group.name) with \(group.categories.count) categories to batch")
        }
        
        // Update local state immediately
        self.categoryGroups = groups
        
        batch.commit { [weak self] error in
            guard let self = self else { return }
            
            if let error = error {
                print("Budget: Error saving category groups: \(error.localizedDescription)")
            } else {
                print("Budget: Successfully saved all category groups")
            }
            
            // Reset the reordering flag after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self.isReorderingGroups = false
                print("Budget: Reset reordering flag")
            }
        }
    }
    
    func deleteTransaction(_ transaction: Transaction) {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("Budget: Cannot delete transaction - no user ID")
            return
        }
        
        print("Budget: Deleting transaction \(transaction.id) for user \(userId)")
        
        let batch = db.batch()
        
        // Delete transaction document
        let transactionRef = db.collection("users").document(userId)
            .collection("transactions")
            .document(transaction.id.uuidString)
        batch.deleteDocument(transactionRef)
        
        // Update category's spent amount
        if let (groupIndex, categoryIndex) = findCategory(byId: transaction.categoryId) {
            var updatedGroup = categoryGroups[groupIndex]
            // For income, we don't affect the spent amount
            if !transaction.isIncome {
                updatedGroup.categories[categoryIndex].spent += transaction.amount
            }
            
            let groupRef = db.collection("users").document(userId)
                .collection("categoryGroups")
                .document(updatedGroup.id.uuidString)
            batch.setData(updatedGroup.toFirestore(), forDocument: groupRef)
        }
        
        // Update account balance
        if let accountIndex = accounts.firstIndex(where: { $0.id == transaction.accountId }) {
            var updatedAccount = accounts[accountIndex]
            updatedAccount.balance -= transaction.amount
            // For now, assume all transactions affect cleared balance
            updatedAccount.clearedBalance -= transaction.amount
            
            let accountRef = db.collection("users").document(userId)
                .collection("accounts")
                .document(updatedAccount.id.uuidString)
            batch.setData(updatedAccount.toFirestore(), forDocument: accountRef)
        }
        
        // Commit all changes
        batch.commit { error in
            if let error = error {
                print("Budget: Error deleting transaction: \(error.localizedDescription)")
            } else {
                print("Budget: Successfully deleted transaction \(transaction.id)")
            }
        }
    }
    
    func updateTransaction(_ oldTransaction: Transaction, with newTransaction: Transaction) {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("Budget: Cannot update transaction - no user ID")
            return
        }
        
        print("Budget: Updating transaction \(oldTransaction.id) for user \(userId)")
        
        let batch = db.batch()
        
        // Update transaction document
        let transactionRef = db.collection("users").document(userId)
            .collection("transactions")
            .document(oldTransaction.id.uuidString)
        batch.setData(newTransaction.toFirestore(), forDocument: transactionRef)
        
        // Update category spent amounts
        if oldTransaction.categoryId == newTransaction.categoryId {
            // Same category, just update the difference
            if let (groupIndex, categoryIndex) = findCategory(byId: oldTransaction.categoryId) {
                var updatedGroup = categoryGroups[groupIndex]
                // For income, we don't affect the spent amount
                if !oldTransaction.isIncome && !newTransaction.isIncome {
                    // Remove old amount and add new amount
                    updatedGroup.categories[categoryIndex].spent = updatedGroup.categories[categoryIndex].spent - oldTransaction.amount + newTransaction.amount
                }
                
                let groupRef = db.collection("users").document(userId)
                    .collection("categoryGroups")
                    .document(updatedGroup.id.uuidString)
                batch.setData(updatedGroup.toFirestore(), forDocument: groupRef)
            }
        } else {
            // Different categories, update both
            // Update old category's spent amount
            if let (oldGroupIndex, oldCategoryIndex) = findCategory(byId: oldTransaction.categoryId) {
                var updatedOldGroup = categoryGroups[oldGroupIndex]
                // For income, we don't affect the spent amount
                if !oldTransaction.isIncome {
                    updatedOldGroup.categories[oldCategoryIndex].spent -= oldTransaction.amount
                }
                
                let oldGroupRef = db.collection("users").document(userId)
                    .collection("categoryGroups")
                    .document(updatedOldGroup.id.uuidString)
                batch.setData(updatedOldGroup.toFirestore(), forDocument: oldGroupRef)
            }
            
            // Update new category's spent amount
            if let (newGroupIndex, newCategoryIndex) = findCategory(byId: newTransaction.categoryId) {
                var updatedNewGroup = categoryGroups[newGroupIndex]
                // For income, we don't affect the spent amount
                if !newTransaction.isIncome {
                    updatedNewGroup.categories[newCategoryIndex].spent += newTransaction.amount
                }
                
                let newGroupRef = db.collection("users").document(userId)
                    .collection("categoryGroups")
                    .document(updatedNewGroup.id.uuidString)
                batch.setData(updatedNewGroup.toFirestore(), forDocument: newGroupRef)
            }
        }
        
        // If same account, update its balance with the difference
        if oldTransaction.accountId == newTransaction.accountId {
            if let accountIndex = accounts.firstIndex(where: { $0.id == oldTransaction.accountId }) {
                var updatedAccount = accounts[accountIndex]
                // Remove old transaction's effect and add new transaction's effect
                updatedAccount.balance = updatedAccount.balance - oldTransaction.amount + newTransaction.amount
                updatedAccount.clearedBalance = updatedAccount.clearedBalance - oldTransaction.amount + newTransaction.amount
                
                let accountRef = db.collection("users").document(userId)
                    .collection("accounts")
                    .document(updatedAccount.id.uuidString)
                batch.setData(updatedAccount.toFirestore(), forDocument: accountRef)
            }
        } else {
            // Different accounts, update both
            if let oldAccountIndex = accounts.firstIndex(where: { $0.id == oldTransaction.accountId }) {
                var updatedOldAccount = accounts[oldAccountIndex]
                updatedOldAccount.balance -= oldTransaction.amount
                updatedOldAccount.clearedBalance -= oldTransaction.amount
                
                let oldAccountRef = db.collection("users").document(userId)
                    .collection("accounts")
                    .document(updatedOldAccount.id.uuidString)
                batch.setData(updatedOldAccount.toFirestore(), forDocument: oldAccountRef)
            }
            
            if let newAccountIndex = accounts.firstIndex(where: { $0.id == newTransaction.accountId }) {
                var updatedNewAccount = accounts[newAccountIndex]
                updatedNewAccount.balance += newTransaction.amount
                updatedNewAccount.clearedBalance += newTransaction.amount
                
                let newAccountRef = db.collection("users").document(userId)
                    .collection("accounts")
                    .document(updatedNewAccount.id.uuidString)
                batch.setData(updatedNewAccount.toFirestore(), forDocument: newAccountRef)
            }
        }
        
        // Commit all changes
        batch.commit { error in
            if let error = error {
                print("Budget: Error updating transaction: \(error.localizedDescription)")
            } else {
                print("Budget: Successfully updated transaction \(oldTransaction.id)")
            }
        }
    }
    
    func deleteAllocation(_ allocation: Allocation) {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("Budget: Cannot delete allocation - no user ID")
            return
        }
        
        guard let (groupIndex, categoryIndex) = findCategory(byId: allocation.categoryId) else { return }
        
        print("Budget: Starting deletion of allocation \(allocation.id)")
        
        let batch = db.batch()
        
        // Delete allocation document
        let allocationRef = db.collection("users").document(userId)
            .collection("allocations")
            .document(allocation.id.uuidString)
        batch.deleteDocument(allocationRef)
        
        // Update category's allocated amount
        var updatedGroup = categoryGroups[groupIndex]
        updatedGroup.categories[categoryIndex].allocated -= allocation.amount
        
        let groupRef = db.collection("users").document(userId)
            .collection("categoryGroups")
            .document(updatedGroup.id.uuidString)
        
        // Get the existing document to preserve the order field
        groupRef.getDocument { [weak self] (document, error) in
            guard let self = self else { return }
            
            var groupData = updatedGroup.toFirestore()
            if let document = document,
               let existingData = document.data(),
               let existingOrder = existingData["order"] as? Int {
                groupData["order"] = existingOrder
            }
            batch.setData(groupData, forDocument: groupRef, merge: true)
            
            // Update local state immediately
            categoryGroups[groupIndex] = updatedGroup
            
            // Temporarily disable reordering flag to allow the update
            let wasReordering = isReorderingGroups
            isReorderingGroups = false
            
            // Commit all changes
            batch.commit { [weak self] error in
                guard let self = self else { return }
                
                if let error = error {
                    print("Budget: Error deleting allocation: \(error.localizedDescription)")
                    // Revert local state on error
                    self.setupListeners()
                } else {
                    print("Budget: Successfully deleted allocation \(allocation.id)")
                }
                
                // Restore the reordering flag
                DispatchQueue.main.async {
                    self.isReorderingGroups = wasReordering
                }
            }
        }
    }
    
    func updateAllocation(_ oldAllocation: Allocation, with newAmount: Double) {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("Budget: Cannot update allocation - no user ID")
            return
        }
        
        guard let (groupIndex, categoryIndex) = findCategory(byId: oldAllocation.categoryId) else { return }
        
        print("Budget: Starting update of allocation \(oldAllocation.id) from \(oldAllocation.amount) to \(newAmount)")
        
        let batch = db.batch()
        
        // Create new allocation with updated amount
        let updatedAllocation = Allocation(
            id: oldAllocation.id,
            date: oldAllocation.date,
            categoryId: oldAllocation.categoryId,
            amount: newAmount
        )
        
        // Update allocation document
        let allocationRef = db.collection("users").document(userId)
            .collection("allocations")
            .document(oldAllocation.id.uuidString)
        batch.setData(updatedAllocation.toFirestore(), forDocument: allocationRef)
        
        // Update category's allocated amount
        var updatedGroup = categoryGroups[groupIndex]
        updatedGroup.categories[categoryIndex].allocated = updatedGroup.categories[categoryIndex].allocated - oldAllocation.amount + newAmount
        
        let groupRef = db.collection("users").document(userId)
            .collection("categoryGroups")
            .document(updatedGroup.id.uuidString)
        
        // Get the existing document to preserve the order field
        groupRef.getDocument { [weak self] (document, error) in
            guard let self = self else { return }
            
            var groupData = updatedGroup.toFirestore()
            if let document = document,
               let existingData = document.data(),
               let existingOrder = existingData["order"] as? Int {
                groupData["order"] = existingOrder
            }
            batch.setData(groupData, forDocument: groupRef, merge: true)
            
            // Update local state immediately
            categoryGroups[groupIndex] = updatedGroup
            
            // Temporarily disable reordering flag to allow the update
            let wasReordering = isReorderingGroups
            isReorderingGroups = false
            
            // Commit all changes
            batch.commit { [weak self] error in
                guard let self = self else { return }
                
                if let error = error {
                    print("Budget: Error updating allocation: \(error.localizedDescription)")
                    // Revert local state on error
                    self.setupListeners()
                } else {
                    print("Budget: Successfully updated allocation \(oldAllocation.id) to \(newAmount)")
                }
                
                // Restore the reordering flag
                DispatchQueue.main.async {
                    self.isReorderingGroups = wasReordering
                }
            }
        }
    }
    
    func updateGroup(groupId: UUID, name: String) {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        // Find the group
        guard let groupIndex = categoryGroups.firstIndex(where: { $0.id == groupId }) else { return }
        var updatedGroup = categoryGroups[groupIndex]
        updatedGroup.name = name
        
        // Update local state
        categoryGroups[groupIndex] = updatedGroup
        
        // Update in Firestore
        let groupRef = db.collection("users").document(userId)
            .collection("categoryGroups").document(groupId.uuidString)
        
        groupRef.updateData([
            "name": name
        ]) { error in
            if let error = error {
                print("Budget: Error updating group: \(error.localizedDescription)")
            }
        }
    }
    
    func reorderGroups(from source: IndexSet, to destination: Int) {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        // Set reordering flag to prevent listener updates
        isReorderingGroups = true
        
        // Separate income group and other groups
        let incomeGroup = categoryGroups.first { $0.name == "Income" }
        var nonIncomeGroups = categoryGroups.filter { $0.name != "Income" }
        
        // Perform the move on non-income groups
        nonIncomeGroups.move(fromOffsets: source, toOffset: destination)
        
        // Reconstruct the full array with income group at the start
        var updatedGroups = [CategoryGroup]()
        if let incomeGroup = incomeGroup {
            updatedGroups.append(incomeGroup)
        }
        updatedGroups.append(contentsOf: nonIncomeGroups)
        
        // Update local state immediately
        categoryGroups = updatedGroups
        
        // Update Firestore
        let batch = db.batch()
        
        // Update all groups with their new order
        for (index, group) in updatedGroups.enumerated() {
            let groupRef = db.collection("users").document(userId)
                .collection("categoryGroups")
                .document(group.id.uuidString)
            
            var groupData = group.toFirestore()
            groupData["order"] = index
            
            batch.setData(groupData, forDocument: groupRef, merge: true)
        }
        
        // Commit the batch
        batch.commit { [weak self] error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isReorderingGroups = false
                
                if let error = error {
                    print("Error reordering groups: \(error.localizedDescription)")
                    // On error, revert to the previous state by re-fetching data
                    self.setupListeners()
                }
            }
        }
    }
    
    func reorderCategories(in groupId: UUID, from source: IndexSet, to destination: Int) {
        guard let userId = Auth.auth().currentUser?.uid,
              let groupIndex = categoryGroups.firstIndex(where: { $0.id == groupId }) else { return }
        
        print("Budget: Starting to reorder categories in group \(groupId)")
        
        // Set reordering flag to prevent listener updates
        isReorderingGroups = true
        
        // Update local state
        var updatedGroup = categoryGroups[groupIndex]
        updatedGroup.categories.move(fromOffsets: source, toOffset: destination)
        categoryGroups[groupIndex] = updatedGroup
        
        // Update Firestore
        let groupRef = db.collection("users").document(userId)
            .collection("categoryGroups")
            .document(groupId.uuidString)
        
        let groupData = updatedGroup.toFirestore()
        
        groupRef.setData(groupData, merge: true) { [weak self] error in
            guard let self = self else { return }
            
            if let error = error {
                print("Budget: Error reordering categories: \(error.localizedDescription)")
            } else {
                print("Budget: Successfully reordered categories in group \(groupId)")
            }
            
            // Reset the reordering flag after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self.isReorderingGroups = false
                print("Budget: Reset reordering flag")
            }
        }
    }
    
    func moveCategory(from sourceGroup: UUID, at sourceIndices: IndexSet, to destinationGroup: UUID, at destination: Int) {
        guard let userId = Auth.auth().currentUser?.uid,
              let sourceGroupIndex = categoryGroups.firstIndex(where: { $0.id == sourceGroup }),
              let destGroupIndex = categoryGroups.firstIndex(where: { $0.id == destinationGroup }) else { return }
        
        // Update local state
        var updatedSourceGroup = categoryGroups[sourceGroupIndex]
        var updatedDestGroup = categoryGroups[destGroupIndex]
        
        let movedCategories = sourceIndices.map { updatedSourceGroup.categories[$0] }
        updatedDestGroup.categories.insert(contentsOf: movedCategories, at: destination)
        updatedSourceGroup.categories.remove(atOffsets: sourceIndices)
        
        categoryGroups[sourceGroupIndex] = updatedSourceGroup
        categoryGroups[destGroupIndex] = updatedDestGroup
        
        // Update Firestore
        let batch = db.batch()
        
        let sourceRef = db.collection("users").document(userId)
            .collection("categoryGroups")
            .document(sourceGroup.uuidString)
        batch.setData(updatedSourceGroup.toFirestore(), forDocument: sourceRef)
        
        let destRef = db.collection("users").document(userId)
            .collection("categoryGroups")
            .document(destinationGroup.uuidString)
        batch.setData(updatedDestGroup.toFirestore(), forDocument: destRef)
        
        batch.commit { error in
            if let error = error {
                print("Error moving categories between groups: \(error.localizedDescription)")
            }
        }
    }
    
    func updateCategory(_ categoryId: UUID, name: String, emoji: String?) {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        // Find the category and its group
        for (groupIndex, group) in categoryGroups.enumerated() {
            if let categoryIndex = group.categories.firstIndex(where: { $0.id == categoryId }) {
                // Update local state
                var updatedGroup = group
                var updatedCategory = updatedGroup.categories[categoryIndex]
                updatedCategory.name = name
                updatedCategory.emoji = emoji
                updatedGroup.categories[categoryIndex] = updatedCategory
                
                // Update local state
                categoryGroups[groupIndex] = updatedGroup
                
                // Update Firestore
                let groupRef = db.collection("users").document(userId)
                    .collection("categoryGroups")
                    .document(group.id.uuidString)
                
                // Convert group to Firestore data and only update the categories field
                let groupData = updatedGroup.toFirestore()
                groupRef.updateData([
                    "categories": groupData["categories"] as Any
                ]) { error in
                    if let error = error {
                        print("Error updating category: \(error.localizedDescription)")
                    }
                }
                
                break
            }
        }
    }
    
    func deleteCategory(groupId: UUID, categoryId: UUID) {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        // Find the group
        guard let groupIndex = categoryGroups.firstIndex(where: { $0.id == groupId }) else { return }
        var updatedGroup = categoryGroups[groupIndex]
        
        // Remove the category
        updatedGroup.categories.removeAll { $0.id == categoryId }
        
        // Update local state
        categoryGroups[groupIndex] = updatedGroup
        
        // Update Firestore
        let groupRef = db.collection("users").document(userId)
            .collection("categoryGroups")
            .document(groupId.uuidString)
        
        // Convert group to Firestore data
        let groupData = updatedGroup.toFirestore()
        
        // Update only the categories field
        groupRef.updateData([
            "categories": groupData["categories"] as Any
        ]) { error in
            if let error = error {
                print("Error deleting category: \(error.localizedDescription)")
            }
        }
    }
}
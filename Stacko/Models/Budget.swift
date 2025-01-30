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
                    // For guest accounts, always start with setup
                    if data["isGuest"] as? Bool == true {
                        self?.isSetupComplete = false
                    } else {
                        self?.isSetupComplete = data["isSetupComplete"] as? Bool ?? false
                    }
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
                    // For guest accounts, always start with setup
                    if data["isGuest"] as? Bool == true {
                        self?.isSetupComplete = false
                    } else {
                        self?.isSetupComplete = data["isSetupComplete"] as? Bool ?? false
                    }
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
        
        // Listen for category groups changes
        let groupsListener = db.collection("users").document(userId).collection("categoryGroups")
            .addSnapshotListener { [weak self] snapshot, error in
                if let error = error {
                    print("Budget: Error fetching category groups: \(error.localizedDescription)")
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    print("Budget: No category group documents found")
                    return
                }
                
                print("Budget: Received \(documents.count) category group documents")
                self?.categoryGroups = documents.compactMap { document in
                    guard let group = CategoryGroup.fromFirestore(document.data()) else {
                        print("Budget: Failed to parse category group document \(document.documentID)")
                        return nil
                    }
                    return group
                }
                print("Budget: Updated categoryGroups array with \(self?.categoryGroups.count ?? 0) groups")
            }
        listeners.append(groupsListener)
            
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
            isArchived: false
        )
        
        let batch = db.batch()
        
        // Add account document
        let accountRef = db.collection("users").document(userId)
            .collection("accounts")
            .document(account.id.uuidString)
        batch.setData(account.toFirestore(), forDocument: accountRef)
        
        // Add initial balance transaction if needed
        if balance != 0,
           let incomeGroup = categoryGroups.first(where: { $0.name == "Income" }),
           let initialBalanceCategory = incomeGroup.categories.first(where: { $0.name == "Initial Balance" }) ?? incomeGroup.categories.first {
            let transaction = Transaction(
                id: UUID(),
                date: Date(),
                payee: "Initial Balance",
                categoryId: initialBalanceCategory.id,
                amount: abs(balance),
                note: "Initial balance for \(name)",
                isIncome: balance > 0,
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
                print("Error adding account: \(error.localizedDescription)")
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
        guard let userId = Auth.auth().currentUser?.uid else {
            print("Budget: Cannot add transaction - no user ID")
            return
        }
        
        print("Budget: Adding transaction \(transaction.id) for user \(userId)")
        
        let batch = db.batch()
        
        // Add transaction document
        let transactionRef = db.collection("users").document(userId)
            .collection("transactions")
            .document(transaction.id.uuidString)
        batch.setData(transaction.toFirestore(), forDocument: transactionRef)
        
        // Update only the category's spent amount
        if let (groupIndex, categoryIndex) = findCategory(byId: transaction.categoryId) {
            var updatedGroup = categoryGroups[groupIndex]
            // For income, we don't affect the spent amount
            if !transaction.isIncome {
                // For expenses, transaction.amount is already negative
                // We want to increase spent by the positive amount
                updatedGroup.categories[categoryIndex].spent -= transaction.amount
            }
            
            let groupRef = db.collection("users").document(userId)
                .collection("categoryGroups")
                .document(updatedGroup.id.uuidString)
            batch.setData(updatedGroup.toFirestore(), forDocument: groupRef)
        }
        
        // Update account balance
        if let accountIndex = accounts.firstIndex(where: { $0.id == transaction.accountId }) {
            var updatedAccount = accounts[accountIndex]
            updatedAccount.balance += transaction.amount
            // For now, assume all transactions affect cleared balance
            updatedAccount.clearedBalance += transaction.amount
            
            let accountRef = db.collection("users").document(userId)
                .collection("accounts")
                .document(updatedAccount.id.uuidString)
            batch.setData(updatedAccount.toFirestore(), forDocument: accountRef)
        }
        
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
        
        db.collection("users").document(userId)
            .collection("categoryGroups")
            .document(updatedGroup.id.uuidString)
            .setData(updatedGroup.toFirestore()) { error in
                if let error = error {
                    print("Error updating category target: \(error.localizedDescription)")
                }
            }
    }
    
    func allocateToBudget(amount: Double, categoryId: UUID) {
        guard let userId = Auth.auth().currentUser?.uid,
              let (groupIndex, categoryIndex) = findCategory(byId: categoryId) else { return }
        
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
            print("Error: Not enough available to budget")
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
        batch.setData(updatedGroup.toFirestore(), forDocument: groupRef)
        
        // Commit all changes
        batch.commit { error in
            if let error = error {
                print("Error updating budget allocation: \(error.localizedDescription)")
            }
        }
    }
    
    func deleteGroup(_ id: UUID) {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        db.collection("users").document(userId)
            .collection("categoryGroups")
            .document(id.uuidString)
            .delete() { error in
                if let error = error {
                    print("Error deleting group: \(error.localizedDescription)")
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
        
        let batch = db.batch()
        
        for group in groups {
            let groupRef = db.collection("users").document(userId)
                .collection("categoryGroups")
                .document(group.id.uuidString)
            
            batch.setData(group.toFirestore(), forDocument: groupRef)
        }
        
        batch.commit { error in
            if let error = error {
                print("Error saving category groups: \(error.localizedDescription)")
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
        batch.setData(updatedGroup.toFirestore(), forDocument: groupRef)
        
        // Commit all changes
        batch.commit { error in
            if let error = error {
                print("Budget: Error deleting allocation: \(error.localizedDescription)")
            } else {
                print("Budget: Successfully deleted allocation \(allocation.id)")
            }
        }
    }
    
    func updateAllocation(_ oldAllocation: Allocation, with newAmount: Double) {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("Budget: Cannot update allocation - no user ID")
            return
        }
        
        guard let (groupIndex, categoryIndex) = findCategory(byId: oldAllocation.categoryId) else { return }
        
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
        batch.setData(updatedGroup.toFirestore(), forDocument: groupRef)
        
        // Commit all changes
        batch.commit { error in
            if let error = error {
                print("Budget: Error updating allocation: \(error.localizedDescription)")
            } else {
                print("Budget: Successfully updated allocation \(oldAllocation.id)")
            }
        }
    }
}
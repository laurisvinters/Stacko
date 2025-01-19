import Foundation
import SwiftUI
import FirebaseFirestore
import FirebaseAuth

class Budget: ObservableObject {
    private let db = Firestore.firestore()
    @Published private(set) var accounts: [Account] = []
    @Published private(set) var categoryGroups: [CategoryGroup] = []
    @Published private(set) var transactions: [Transaction] = []
    @Published private(set) var templates: [TransactionTemplate] = []
    @Published private(set) var isSetupComplete: Bool? = nil
    
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
        templates = []
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
                    print("Budget: Error fetching accounts: \(error.localizedDescription)")
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    print("Budget: No account documents found")
                    return
                }
                
                print("Budget: Received \(documents.count) account documents")
                self?.accounts = documents.compactMap { document in
                    guard let account = Account.fromFirestore(document.data()) else {
                        print("Budget: Failed to parse account document \(document.documentID)")
                        return nil
                    }
                    return account
                }
                print("Budget: Updated accounts array with \(self?.accounts.count ?? 0) accounts")
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
            
        // Listen for templates changes
        let templatesListener = db.collection("users").document(userId).collection("templates")
            .addSnapshotListener { [weak self] snapshot, error in
                if let error = error {
                    print("Budget: Error fetching templates: \(error.localizedDescription)")
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    print("Budget: No template documents found")
                    return
                }
                
                self?.templates = documents.compactMap { document in
                    TransactionTemplate.fromFirestore(document.data())
                }
            }
        listeners.append(templatesListener)
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
        
        db.collection("users").document(userId)
            .collection("accounts")
            .document(id.uuidString)
            .delete() { error in
                if let error = error {
                    print("Error deleting account: \(error.localizedDescription)")
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
        
        // Update account balance
        if let accountIndex = accounts.firstIndex(where: { $0.id == transaction.accountId }) {
            var updatedAccount = accounts[accountIndex]
            updatedAccount.balance += transaction.isIncome ? transaction.amount : -transaction.amount
            updatedAccount.clearedBalance += transaction.isIncome ? transaction.amount : -transaction.amount
            
            let accountRef = db.collection("users").document(userId)
                .collection("accounts")
                .document(transaction.accountId.uuidString)
            batch.setData(updatedAccount.toFirestore(), forDocument: accountRef)
        }
        
        // Update only the category's spent amount
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
        
        var updatedGroup = categoryGroups[groupIndex]
        updatedGroup.categories[categoryIndex].allocated += amount
        
        db.collection("users").document(userId)
            .collection("categoryGroups")
            .document(updatedGroup.id.uuidString)
            .setData(updatedGroup.toFirestore()) { error in
                if let error = error {
                    print("Error updating category allocation: \(error.localizedDescription)")
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
    
    func addTemplate(_ template: TransactionTemplate) {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        db.collection("users").document(userId)
            .collection("templates")
            .document(template.id.uuidString)
            .setData(template.toFirestore()) { error in
                if let error = error {
                    print("Error adding template: \(error.localizedDescription)")
                }
            }
    }
    
    func createTransactionFromTemplate(_ template: TransactionTemplate, date: Date = Date()) {
        let transaction = Transaction(
            id: UUID(),
            date: date,
            payee: template.payee,
            categoryId: template.categoryId,
            amount: template.amount,
            note: nil,
            isIncome: template.isIncome,
            accountId: accounts.first?.id ?? UUID(),
            toAccountId: nil
        )
        
        addTransaction(transaction)
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
            amount: amount,
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
            updatedGroup.categories[fromCategoryIndex].spent += amount
            
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
} 
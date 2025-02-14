import Foundation
import FirebaseFirestore
import Combine

class PlannedTransactionManager: ObservableObject {
    private let db = Firestore.firestore()
    private var userId: String
    @Published var plannedTransactions: [PlannedTransaction] = []
    
    init(userId: String) {
        self.userId = userId
        setupListener()
    }
    
    private func setupListener() {
        db.collection("users").document(userId)
            .collection("plannedTransactions")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let documents = snapshot?.documents else {
                    print("Error fetching planned transactions: \(error?.localizedDescription ?? "Unknown error")")
                    return
                }
                
                self?.plannedTransactions = documents.compactMap { document in
                    PlannedTransaction.fromFirestore(document.data())
                }
            }
    }
    
    func add(_ transaction: PlannedTransaction) async throws {
        try await db.collection("users").document(userId)
            .collection("plannedTransactions")
            .document(transaction.id.uuidString)
            .setData(transaction.toFirestore())
    }
    
    func update(_ transaction: PlannedTransaction) async throws {
        try await db.collection("users").document(userId)
            .collection("plannedTransactions")
            .document(transaction.id.uuidString)
            .setData(transaction.toFirestore())
    }
    
    func delete(_ transaction: PlannedTransaction) async throws {
        try await db.collection("users").document(userId)
            .collection("plannedTransactions")
            .document(transaction.id.uuidString)
            .delete()
    }
    
    func processAutomaticTransactions() async throws {
        let now = Date()
        print("Processing automatic transactions at \(now)")
        print("Total transactions: \(plannedTransactions.count)")
        
        let dueTransactions = plannedTransactions.filter { transaction in
            transaction.isActive &&
            transaction.type == .automatic &&
            transaction.nextDueDate <= now
        }
        
        print("Due automatic transactions: \(dueTransactions.count)")
        
        for var transaction in dueTransactions {
            print("Processing transaction: \(transaction.title) due at \(transaction.nextDueDate)")
            
            // Create actual transaction
            let newTransaction = Transaction(
                id: UUID(),
                date: transaction.nextDueDate,
                payee: transaction.title,
                categoryId: transaction.categoryId ?? UUID(),
                amount: transaction.isIncome ? abs(transaction.amount) : -abs(transaction.amount),
                note: transaction.note,
                isIncome: transaction.isIncome,
                accountId: transaction.accountId,
                toAccountId: nil
            )
            
            // Update planned transaction
            transaction.lastProcessedDate = transaction.nextDueDate
            transaction.nextDueDate = transaction.calculateNextDueDate()
            
            print("Next due date calculated as: \(transaction.nextDueDate)")
            
            // Save both changes
            let batch = db.batch()
            
            // Add new transaction
            let transactionRef = db.collection("users").document(userId)
                .collection("transactions")
                .document(newTransaction.id.uuidString)
            batch.setData(newTransaction.toFirestore(), forDocument: transactionRef)
            
            // Update planned transaction
            let plannedTransactionRef = db.collection("users").document(userId)
                .collection("plannedTransactions")
                .document(transaction.id.uuidString)
            batch.setData(transaction.toFirestore(), forDocument: plannedTransactionRef)
            
            // Update account balance
            let accountRef = db.collection("users").document(userId)
                .collection("accounts")
                .document(transaction.accountId.uuidString)
            
            // Update account using a transaction to ensure atomicity
            try await db.runTransaction { transaction, errorPointer in
                let accountSnapshot: DocumentSnapshot
                do {
                    accountSnapshot = try transaction.getDocument(accountRef)
                } catch let error as NSError {
                    errorPointer?.pointee = error
                    return nil
                }
                
                guard let accountData = accountSnapshot.data(),
                      let currentBalance = accountData["balance"] as? Double,
                      let clearedBalance = accountData["clearedBalance"] as? Double else {
                    let error = NSError(domain: "AppErrorDomain", code: -1, userInfo: [
                        NSLocalizedDescriptionKey: "Unable to get account data"
                    ])
                    errorPointer?.pointee = error
                    return nil
                }
                
                // Update the balances
                let newBalance = currentBalance + newTransaction.amount
                let newClearedBalance = clearedBalance + newTransaction.amount
                
                transaction.updateData([
                    "balance": newBalance,
                    "clearedBalance": newClearedBalance
                ], forDocument: accountRef)
                
                return nil
            }
            
            // After successful transaction, commit the batch
            try await batch.commit()
            print("Transaction processed successfully")
        }
    }
    
    func processManualTransaction(_ transaction: PlannedTransaction) async throws {
        var updatedTransaction = transaction
        
        // Create actual transaction
        let newTransaction = Transaction(
            id: UUID(),
            date: transaction.nextDueDate,
            payee: transaction.title,
            categoryId: transaction.categoryId ?? UUID(),
            amount: transaction.isIncome ? abs(transaction.amount) : -abs(transaction.amount),
            note: transaction.note,
            isIncome: transaction.isIncome,
            accountId: transaction.accountId,
            toAccountId: nil
        )
        
        // Update planned transaction
        updatedTransaction.lastProcessedDate = transaction.nextDueDate
        updatedTransaction.nextDueDate = transaction.calculateNextDueDate()
        
        // Save both changes
        let batch = db.batch()
        
        // Add new transaction
        let transactionRef = db.collection("users").document(userId)
            .collection("transactions")
            .document(newTransaction.id.uuidString)
        batch.setData(newTransaction.toFirestore(), forDocument: transactionRef)
        
        // Update planned transaction
        let plannedTransactionRef = db.collection("users").document(userId)
            .collection("plannedTransactions")
            .document(transaction.id.uuidString)
        batch.setData(updatedTransaction.toFirestore(), forDocument: plannedTransactionRef)
        
        // Update account balance
        let accountRef = db.collection("users").document(userId)
            .collection("accounts")
            .document(transaction.accountId.uuidString)
        
        // Update account using a transaction to ensure atomicity
        try await db.runTransaction { transaction, errorPointer in
            let accountSnapshot: DocumentSnapshot
            do {
                accountSnapshot = try transaction.getDocument(accountRef)
            } catch let error as NSError {
                errorPointer?.pointee = error
                return nil
            }
            
            guard let accountData = accountSnapshot.data(),
                  let currentBalance = accountData["balance"] as? Double,
                  let clearedBalance = accountData["clearedBalance"] as? Double else {
                let error = NSError(domain: "AppErrorDomain", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: "Unable to get account data"
                ])
                errorPointer?.pointee = error
                return nil
            }
            
            // Update the balances
            let newBalance = currentBalance + newTransaction.amount
            let newClearedBalance = clearedBalance + newTransaction.amount
            
            transaction.updateData([
                "balance": newBalance,
                "clearedBalance": newClearedBalance
            ], forDocument: accountRef)
            
            return nil
        }
        
        // After successful transaction, commit the batch
        try await batch.commit()
    }
}

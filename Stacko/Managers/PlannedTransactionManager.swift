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
        let dueTransactions = plannedTransactions.filter { transaction in
            transaction.isActive &&
            transaction.type == .automatic &&
            transaction.nextDueDate <= now
        }
        
        for var transaction in dueTransactions {
            // Create actual transaction
            let newTransaction = Transaction(
                id: UUID(),
                date: transaction.nextDueDate,
                payee: transaction.title,
                categoryId: transaction.categoryId ?? UUID(), // You might want to handle this differently
                amount: transaction.amount,
                note: transaction.note,
                isIncome: transaction.isIncome,
                accountId: transaction.accountId,
                toAccountId: nil
            )
            
            // Update planned transaction
            transaction.lastProcessedDate = transaction.nextDueDate
            transaction.nextDueDate = transaction.calculateNextDueDate()
            
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
            
            try await batch.commit()
        }
    }
}

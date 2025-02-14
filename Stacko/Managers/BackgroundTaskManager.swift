import Foundation
import BackgroundTasks
import FirebaseAuth
import UserNotifications

class BackgroundTaskManager {
    static let shared = BackgroundTaskManager()
    private let taskIdentifier = "com.stacko.processTransactions"
    
    private init() {}
    
    func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: taskIdentifier, using: nil) { task in
            self.handleTransactionProcessing(task: task as! BGProcessingTask)
        }
    }
    
    func scheduleTransactionProcessing() {
        let request = BGProcessingTaskRequest(identifier: taskIdentifier)
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 minutes from now
        
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Could not schedule transaction processing: \(error)")
        }
    }
    
    private func handleTransactionProcessing(task: BGProcessingTask) {
        // Schedule the next background task
        scheduleTransactionProcessing()
        
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        
        task.expirationHandler = {
            queue.cancelAllOperations()
        }
        
        let operation = BlockOperation {
            guard let userId = Auth.auth().currentUser?.uid else { return }
            
            let manager = PlannedTransactionManager(userId: userId)
            
            // Create a continuation to wait for transactions to load
            Task {
                do {
                    try await withCheckedThrowingContinuation { continuation in
                        // Wait for a short time to allow transactions to load
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            continuation.resume()
                        }
                    }
                    
                    // Process transactions
                    try await manager.processAutomaticTransactions()
                    try await self.scheduleNotificationsForManualTransactions(manager: manager)
                } catch {
                    print("Error processing transactions: \(error)")
                }
            }
        }
        
        operation.completionBlock = {
            task.setTaskCompleted(success: !operation.isCancelled)
        }
        
        queue.addOperation(operation)
    }
    
    private func scheduleNotificationsForManualTransactions(manager: PlannedTransactionManager) async throws {
        let center = UNUserNotificationCenter.current()
        
        // Remove all pending notifications first
        await center.removeAllPendingNotificationRequests()
        
        // Get all active manual transactions
        let manualTransactions = manager.plannedTransactions.filter { transaction in
            transaction.isActive && transaction.type == .manual
        }
        
        for transaction in manualTransactions {
            if transaction.nextDueDate > Date() {
                let content = UNMutableNotificationContent()
                content.title = "Transaction Due"
                content.body = "\(transaction.title) - \(transaction.amount.formatted(.currency(code: "USD")))"
                content.sound = .default
                
                let dateComponents = Calendar.current.dateComponents([.year, .month, .day], from: transaction.nextDueDate)
                let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
                
                let request = UNNotificationRequest(
                    identifier: "transaction-\(transaction.id)",
                    content: content,
                    trigger: trigger
                )
                
                try await center.add(request)
            }
        }
    }
}

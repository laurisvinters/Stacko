import SwiftUI

struct ReconcileSheet: View {
    @ObservedObject var budget: Budget
    let account: Account
    @Environment(\.dismiss) private var dismiss
    
    @State private var statementBalance = ""
    @State private var statementDate = Date()
    @State private var selectedTransactions = Set<UUID>()
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("Statement Balance", text: $statementBalance)
                        .keyboardType(.decimalPad)
                    
                    DatePicker("Statement Date", selection: $statementDate, displayedComponents: .date)
                }
                
                Section {
                    ForEach(unreconciled) { transaction in
                        TransactionListRow(transaction: transaction)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                toggleTransaction(transaction.id)
                            }
                            .background {
                                if selectedTransactions.contains(transaction.id) {
                                    Color.accentColor.opacity(0.1)
                                }
                            }
                    }
                } header: {
                    HStack {
                        Text("Unreconciled Transactions")
                        Spacer()
                        Text(difference, format: .currency(code: "USD"))
                            .foregroundColor(difference == 0 ? .green : .red)
                    }
                }
            }
            .navigationTitle("Reconcile Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Finish") { reconcile() }
                        .disabled(!canReconcile)
                }
            }
        }
    }
    
    private var unreconciled: [Transaction] {
        budget.transactions
            .filter { ($0.accountId == account.id || $0.toAccountId == account.id) && $0.date <= statementDate }
            .sorted { $0.date > $1.date }
    }
    
    private var selectedBalance: Double {
        unreconciled
            .filter { selectedTransactions.contains($0.id) }
            .reduce(0) { sum, transaction in
                if transaction.accountId == account.id {
                    return sum + (transaction.isIncome ? transaction.amount : -transaction.amount)
                } else {
                    return sum + transaction.amount
                }
            }
    }
    
    private var difference: Double {
        guard let targetBalance = Double(statementBalance) else { return 0 }
        return selectedBalance - targetBalance
    }
    
    private var canReconcile: Bool {
        !statementBalance.isEmpty && difference == 0
    }
    
    private func toggleTransaction(_ id: UUID) {
        if selectedTransactions.contains(id) {
            selectedTransactions.remove(id)
        } else {
            selectedTransactions.insert(id)
        }
    }
    
    private func reconcile() {
        guard let targetBalance = Double(statementBalance) else { return }
        
        // Update cleared balance
        if let index = budget.accounts.firstIndex(where: { $0.id == account.id }) {
            budget.accounts[index].clearedBalance = targetBalance
            budget.accounts[index].lastReconciled = statementDate
        }
        
        dismiss()
    }
} 
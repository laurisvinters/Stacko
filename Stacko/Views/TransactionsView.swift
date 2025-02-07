import SwiftUI

struct TransactionsView: View {
    @ObservedObject var budget: Budget
    @State private var showingAddTransaction = false
    @State private var transactionToEdit: Transaction?
    
    var body: some View {
        NavigationStack {
            List {
                Text("Swipe left to delete, right, then click to edit")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ForEach(sortedTransactions) { transaction in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(transaction.payee)
                                Text(transaction.date.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                HStack(spacing: 4) {
                                    Text("•")
                                    if let account = budget.accounts.first(where: { $0.id == transaction.accountId }) {
                                        Text(account.name)
                                    }
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(transaction.amount, format: .currency(code: "USD"))
                                .foregroundStyle(transaction.isIncome ? .green : .primary)
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            budget.deleteTransaction(transaction)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                        Button {
                            transactionToEdit = transaction
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        .tint(.blue)
                    }
                    .swipeHint(enabled: transaction.id == sortedTransactions.first?.id)
                }
            }
            .navigationTitle("Transactions")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showingAddTransaction = true
                    } label: {
                        Label("Add", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddTransaction) {
                QuickAddTransactionSheet(budget: budget)
            }
            .sheet(item: $transactionToEdit) { transaction in
                QuickAddTransactionSheet(budget: budget, existingTransaction: transaction)
            }
        }
    }
    
    private var sortedTransactions: [Transaction] {
        budget.transactions.sorted { $0.date > $1.date }
    }
}

#Preview {
    TransactionsView(budget: Budget())
}

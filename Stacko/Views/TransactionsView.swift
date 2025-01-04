import SwiftUI

struct TransactionsView: View {
    @ObservedObject var budget: Budget
    @State private var showingAddTransaction = false
    
    var body: some View {
        NavigationStack {
            List {
                LazyVStack(spacing: 8) {
                    ForEach(sortedTransactions) { transaction in
                        TransactionRow(transaction: transaction, budget: budget)
                            .equatable()
                    }
                }
            }
            .navigationTitle("Transactions")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    NavigationLink {
                        TransactionTemplatesView(budget: budget)
                    } label: {
                        Label("Templates", systemImage: "doc.on.doc")
                    }
                }
            }
            .overlay(alignment: .bottomTrailing) {
                addButton
            }
        }
    }
    
    // Move computation to a computed property
    private var sortedTransactions: [Transaction] {
        budget.transactions.sorted { $0.date > $1.date }
    }
    
    private var addButton: some View {
        Button(action: { showingAddTransaction = true }) {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 50))
                .padding()
                .symbolRenderingMode(.hierarchical)
        }
        .tint(.blue)
        .sheet(isPresented: $showingAddTransaction) {
            QuickAddTransactionSheet(budget: budget)
        }
    }
}

#Preview {
    TransactionsView(budget: Budget(dataController: DataController()))
} 
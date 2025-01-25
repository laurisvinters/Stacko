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
                ToolbarItem(placement: .navigationBarLeading) {
                    NavigationLink {
                        TransactionTemplatesView(budget: budget)
                    } label: {
                        Label("Templates", systemImage: "doc.on.doc")
                    }
                }
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
        }
    }
    
    // Move computation to a computed property
    private var sortedTransactions: [Transaction] {
        budget.transactions.sorted { $0.date > $1.date }
    }
}

#Preview {
    TransactionsView(budget: Budget())
} 

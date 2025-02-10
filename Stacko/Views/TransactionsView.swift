import SwiftUI
import FirebaseAuth

struct TransactionsView: View {
    @ObservedObject var budget: Budget
    @State private var showingAddTransaction = false
    @State private var transactionToEdit: Transaction?
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        if let userId = Auth.auth().currentUser?.uid {
                            PlannedTransactionsView(userId: userId)
                        }
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Planned Transactions")
                                    .font(.headline)
                                Text("Set up recurring payments")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "calendar.badge.clock")
                                .foregroundColor(.blue)
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section {
                    (Text("Swipe left to ")
                        .foregroundColor(.gray) +
                     Text("delete")
                        .foregroundColor(.blue) +
                     Text(" transactions. Swipe right, then click to ")
                        .foregroundColor(.gray) +
                     Text("edit")
                        .foregroundColor(.blue) +
                     Text(" transactions")
                        .foregroundColor(.gray))
                        .font(.caption)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .listRowBackground(Color.clear)
                }
                .padding(.top, 20)
                .listSectionSpacing(0)
                
                Section {
                    ForEach(sortedTransactions) { transaction in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(transaction.payee)
                                HStack(spacing: 4) {
                                    Text(transaction.date.formatted(date: .abbreviated, time: .shortened))
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
                    }
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

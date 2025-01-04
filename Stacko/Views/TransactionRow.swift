import SwiftUI

struct TransactionRow: View, Equatable {
    let transaction: Transaction
    @ObservedObject var budget: Budget
    
    private var category: Category? {
        budget.categoryGroups
            .flatMap(\.categories)
            .first(where: { $0.id == transaction.categoryId })
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(transaction.payee)
                    .font(.headline)
                Text(category?.name ?? "Uncategorized")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Text(transaction.amount, format: .currency(code: "USD"))
                .foregroundStyle(transaction.isIncome ? .green : .primary)
        }
    }
    
    // Add Equatable conformance
    static func == (lhs: TransactionRow, rhs: TransactionRow) -> Bool {
        lhs.transaction.id == rhs.transaction.id &&
        lhs.transaction.amount == rhs.transaction.amount &&
        lhs.transaction.payee == rhs.transaction.payee &&
        lhs.transaction.categoryId == rhs.transaction.categoryId &&
        lhs.transaction.isIncome == rhs.transaction.isIncome
    }
} 
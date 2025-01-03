import SwiftUI

struct TransactionRow: View {
    let transaction: Transaction
    @ObservedObject var budget: Budget
    
    private var category: Category? {
        budget.categoryGroups
            .flatMap(\.categories)
            .first(where: { $0.id == transaction.categoryId })
    }
    
    var body: some View {
        EquatableTransactionRow(
            payee: transaction.payee,
            categoryName: category?.name ?? "Uncategorized",
            amount: transaction.amount,
            isIncome: transaction.isIncome
        )
    }
}

// Create a separate equatable view
private struct EquatableTransactionRow: View, Equatable {
    let payee: String
    let categoryName: String
    let amount: Double
    let isIncome: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(payee)
                    .font(.headline)
                Text(categoryName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Text(amount, format: .currency(code: "USD"))
                .foregroundStyle(isIncome ? .green : .primary)
        }
    }
    
    static func == (lhs: EquatableTransactionRow, rhs: EquatableTransactionRow) -> Bool {
        lhs.payee == rhs.payee &&
        lhs.categoryName == rhs.categoryName &&
        lhs.amount == rhs.amount &&
        lhs.isIncome == rhs.isIncome
    }
} 
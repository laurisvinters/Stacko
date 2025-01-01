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
} 
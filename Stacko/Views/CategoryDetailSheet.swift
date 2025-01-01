import SwiftUI

struct CategoryDetailSheet: View {
    @ObservedObject var budget: Budget
    let category: Category
    @Environment(\.dismiss) var dismiss
    @State private var showingSetTarget = false
    @State private var allocationAmount = ""
    
    private var recentTransactions: [Transaction] {
        budget.transactions
            .filter { $0.categoryId == category.id }
            .sorted { $0.date > $1.date }
            .prefix(5)
            .map { $0 }
    }
    
    // Add computed properties to get real-time values
    private var allocated: Double {
        if let (groupIndex, categoryIndex) = budget.findCategory(byId: category.id) {
            return budget.categoryGroups[groupIndex].categories[categoryIndex].allocated
        }
        return 0
    }
    
    private var spent: Double {
        if let (groupIndex, categoryIndex) = budget.findCategory(byId: category.id) {
            return budget.categoryGroups[groupIndex].categories[categoryIndex].spent
        }
        return 0
    }
    
    private var available: Double {
        allocated - spent
    }
    
    var body: some View {
        NavigationView {
            List {
                Section("Balance") {
                    HStack {
                        Text("Allocated")
                        Spacer()
                        Text(allocated, format: .currency(code: "USD"))
                    }
                    
                    HStack {
                        Text("Spent")
                        Spacer()
                        Text(spent, format: .currency(code: "USD"))
                    }
                    
                    HStack {
                        Text("Available")
                        Spacer()
                        Text(available, format: .currency(code: "USD"))
                            .foregroundColor(available >= 0 ? .primary : .red)
                    }
                }
                
                Section("Allocate Money") {
                    HStack {
                        TextField("Amount", text: $allocationAmount)
                            .keyboardType(.decimalPad)
                        
                        Button("Add") {
                            if let amount = Double(allocationAmount) {
                                budget.allocateToBudget(amount: amount, categoryId: category.id)
                                allocationAmount = ""
                            }
                        }
                        .disabled(allocationAmount.isEmpty || Double(allocationAmount) == nil)
                    }
                }
                
                Section("Quick Actions") {
                    if let target = category.target {
                        HStack {
                            Text("Target")
                            Spacer()
                            Text(target.funded, format: .currency(code: "USD"))
                            Text("of")
                            switch target.type {
                            case .monthly(let amount):
                                Text(amount, format: .currency(code: "USD"))
                            case .weekly(let amount):
                                Text(amount, format: .currency(code: "USD"))
                            case .byDate(let amount, let date):
                                Text(amount, format: .currency(code: "USD"))
                                Text("by")
                                Text(date, format: .dateTime.month().day())
                            }
                        }
                    }
                    
                    Button("Set Target") {
                        showingSetTarget = true
                    }
                }
                
                Section("Recent Transactions") {
                    if recentTransactions.isEmpty {
                        Text("No transactions yet")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(recentTransactions) { transaction in
                            TransactionListRow(transaction: transaction)
                        }
                    }
                }
            }
            .navigationTitle(category.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showingSetTarget) {
                SetTargetSheet(budget: budget, category: category)
            }
        }
    }
}

// Separate row view to avoid circular dependency
struct TransactionListRow: View {
    let transaction: Transaction
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(transaction.payee)
                    .font(.headline)
                Text(transaction.date, format: .dateTime.month().day())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Text(transaction.amount, format: .currency(code: "USD"))
                .foregroundStyle(transaction.isIncome ? .green : .primary)
        }
    }
}

#Preview {
    CategoryDetailSheet(
        budget: Budget(),
        category: Category(
            id: UUID(),
            name: "Test Category",
            emoji: "🧪",
            target: nil,
            allocated: 100,
            spent: 50
        )
    )
} 
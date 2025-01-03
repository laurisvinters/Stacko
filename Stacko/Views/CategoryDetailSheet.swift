import SwiftUI

struct CategoryDetailSheet: View {
    @ObservedObject var budget: Budget
    @State private var categoryId: UUID  // Store ID instead of Category
    
    // Add computed property to get current category state
    private var category: Category {
        if let (groupIndex, categoryIndex) = budget.findCategory(byId: categoryId) {
            return budget.categoryGroups[groupIndex].categories[categoryIndex]
        }
        return Category(id: categoryId, name: "", emoji: nil, target: nil, allocated: 0, spent: 0)
    }
    
    init(budget: Budget, category: Category) {
        self.budget = budget
        self._categoryId = State(initialValue: category.id)
    }
    
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
    
    private var targetAmount: Double {
        guard let target = category.target else { return 0 }
        switch target.type {
        case .monthly(let amount), .weekly(let amount), .byDate(let amount, _):
            return amount
        }
    }
    
    private var targetProgress: Double {
        guard let target = category.target else { return 0 }
        return allocated / targetAmount
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
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Target")
                                    .font(.headline)
                                Spacer()
                                Button("Edit") {
                                    showingSetTarget = true
                                }
                                .font(.caption)
                            }
                            
                            HStack {
                                switch target.type {
                                case .monthly(let amount):
                                    Text("Monthly target:")
                                    Spacer()
                                    Text(amount, format: .currency(code: "USD"))
                                case .weekly(let amount):
                                    Text("Weekly target:")
                                    Spacer()
                                    Text(amount, format: .currency(code: "USD"))
                                case .byDate(let amount, let date):
                                    VStack(alignment: .leading) {
                                        Text("Target by \(date.formatted(date: .abbreviated, time: .omitted)):")
                                        Text(amount, format: .currency(code: "USD"))
                                    }
                                }
                            }
                            .foregroundStyle(.secondary)
                            
                            ProgressView(value: allocated, total: targetAmount)
                                .tint(targetProgress < 1.0 ? .blue : .green)
                            
                            HStack {
                                Text("Progress:")
                                Spacer()
                                Text(allocated, format: .currency(code: "USD"))
                                Text("of")
                                Text(targetAmount, format: .currency(code: "USD"))
                                Text("(\(Int(targetProgress * 100))%)")
                            }
                            .font(.caption)
                        }
                    } else {
                        Button("Set Target") {
                            showingSetTarget = true
                        }
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
        budget: Budget(dataController: DataController()),
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
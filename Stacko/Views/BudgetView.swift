import SwiftUI

struct BudgetView: View {
    @ObservedObject var budget: Budget
    @State private var selectedCategory: Category?
    @State private var showingAddCategory = false
    @State private var showingAddGroup = false
    
    // Filter out Income group
    private var nonIncomeGroups: [CategoryGroup] {
        budget.categoryGroups.filter { $0.name != "Income" }
    }
    
    var body: some View {
        List {
            Section {
                HStack {
                    Text("Available to Budget")
                        .font(.headline)
                    Spacer()
                    Text(availableToBudget, format: .currency(code: "USD"))
                        .foregroundStyle(availableToBudget >= 0 ? Color.primary : Color.red)
                }
            }
            
            ForEach(nonIncomeGroups) { group in
                Section(group.name) {
                    ForEach(group.categories) { category in
                        CategoryRow(category: category)
                            .onTapGesture {
                                selectedCategory = category
                            }
                    }
                    
                    if !group.categories.isEmpty {
                        HStack {
                            Text("Total")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(groupTotal(group), format: .currency(code: "USD"))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Budget")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("Add Category") {
                        showingAddCategory = true
                    }
                    Button("Add Group") {
                        showingAddGroup = true
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(item: $selectedCategory) { category in
            CategoryDetailSheet(budget: budget, category: category)
        }
        .sheet(isPresented: $showingAddCategory) {
            AddCategorySheet(budget: budget)
        }
        .sheet(isPresented: $showingAddGroup) {
            AddGroupSheet(budget: budget)
        }
    }
    
    private var availableToBudget: Double {
        // Get total balance from non-credit card accounts
        let totalBalance = budget.accounts
            .filter { !$0.isArchived }
            .reduce(0.0) { sum, account in
                if account.type == .creditCard {
                    return sum + max(0, account.balance)
                }
                return sum + account.balance
            }
        
        // Subtract allocated amounts from all non-income categories
        let totalAllocated = nonIncomeGroups
            .flatMap(\.categories)
            .reduce(0.0) { sum, category in
                sum + category.allocated
            }
        
        return totalBalance - totalAllocated
    }
    
    private func groupTotal(_ group: CategoryGroup) -> Double {
        // Sum of allocated amounts in the group
        group.categories.reduce(0) { sum, category in
            sum + category.allocated
        }
    }
}

struct CategoryRow: View {
    let category: Category
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(category.emoji ?? "")
                Text(category.name)
                Spacer()
                Text(category.available, format: .currency(code: "USD"))
            }
            
            // Show target progress if target exists
            if let target = category.target {
                VStack(alignment: .leading, spacing: 2) {
                    ProgressView(value: category.allocated, total: targetAmount(for: target))
                        .tint(progressColor(for: category))
                    
                    HStack {
                        Text(targetDescription(for: target))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(Int(targetProgress(for: category) * 100))%")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
    
    private func targetAmount(for target: Target) -> Double {
        switch target.type {
        case .monthly(let amount), .weekly(let amount), .byDate(let amount, _):
            return amount
        }
    }
    
    private func targetProgress(for category: Category) -> Double {
        guard let target = category.target else { return 0 }
        let targetAmount = targetAmount(for: target)
        return targetAmount > 0 ? category.allocated / targetAmount : 0
    }
    
    private func progressColor(for category: Category) -> Color {
        let progress = targetProgress(for: category)
        if progress >= 1.0 {
            return .green
        } else if progress >= 0.7 {
            return .yellow
        } else {
            return .blue
        }
    }
    
    private func targetDescription(for target: Target) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        
        switch target.type {
        case .monthly(let amount):
            return "Monthly: \(formatter.string(from: NSNumber(value: amount)) ?? "$0")"
        case .weekly(let amount):
            return "Weekly: \(formatter.string(from: NSNumber(value: amount)) ?? "$0")"
        case .byDate(let amount, let date):
            return "Target: \(formatter.string(from: NSNumber(value: amount)) ?? "$0") by \(date.formatted(.dateTime.month().day()))"
        }
    }
} 
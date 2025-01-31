import SwiftUI

struct BudgetView: View {
    @ObservedObject var budget: Budget
    @State private var selectedCategory: Category?
    @State private var showingAddCategory = false
    @State private var showingAddGroup = false
    @State private var isRearrangingGroups = false
    @State private var editMode: EditMode = .inactive
    
    private var nonIncomeGroups: [CategoryGroup] {
        budget.categoryGroups.filter { group in
            group.name != "Income"
        }
    }
    
    private func calculateTotalBalance() -> Double {
        budget.accounts
            .filter { !$0.isArchived }
            .reduce(0.0) { sum, account in
                sum + account.balance
            }
    }
    
    private func calculateTotalAllocated() -> Double {
        var total = 0.0
        for group in nonIncomeGroups {
            for category in group.categories {
                let effectiveAllocation = max(0, category.allocated - category.spent)
                total += effectiveAllocation
            }
        }
        return total
    }
    
    private var availableToBudget: Double {
        calculateTotalBalance() - calculateTotalAllocated()
    }
    
    private func groupTotal(_ group: CategoryGroup) -> Double {
        var total = 0.0
        for category in group.categories {
            total += category.allocated
        }
        return total
    }
    
    var body: some View {
        budgetListView
            .listStyle(.insetGrouped)
            .toolbar { toolbarContent }
            .navigationTitle("Budget")
            .environment(\.editMode, .constant(isRearrangingGroups ? .active : editMode))
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
    
    private var budgetListView: some View {
        List {
            if !isRearrangingGroups {
                availableToBudgetSection
                categorySections
            } else {
                groupReorderingView
            }
        }
    }
    
    private var availableToBudgetSection: some View {
        Section {
            HStack {
                Text("Available to Budget")
                    .font(.headline)
                Spacer()
                Text(availableToBudget, format: .currency(code: "USD"))
                    .foregroundStyle(availableToBudget >= 0 ? Color.primary : Color.red)
            }
        }
    }
    
    private var categorySections: some View {
        ForEach(nonIncomeGroups) { group in
            Section {
                categoryList(for: group)
                if !group.categories.isEmpty {
                    groupTotalRow(for: group)
                }
            } header: {
                groupHeader(for: group)
            }
        }
    }
    
    private func categoryList(for group: CategoryGroup) -> some View {
        ForEach(group.categories) { category in
            CategoryRow(category: category)
                .onTapGesture {
                    if editMode == .inactive {
                        selectedCategory = category
                    }
                }
        }
        .onMove { source, destination in
            budget.reorderCategories(in: group.id, from: source, to: destination)
        }
    }
    
    private func groupHeader(for group: CategoryGroup) -> some View {
        HStack {
            if let emoji = group.emoji {
                Text(emoji)
            }
            Text(group.name)
                .font(.headline)
                .foregroundStyle(.secondary)
        }
    }
    
    private func groupTotalRow(for group: CategoryGroup) -> some View {
        HStack {
            Text("Total")
                .foregroundStyle(.secondary)
            Spacer()
            Text(groupTotal(group), format: .currency(code: "USD"))
                .foregroundStyle(.secondary)
        }
    }
    
    private var groupReorderingView: some View {
        ForEach(nonIncomeGroups) { group in
            HStack {
                if let emoji = group.emoji {
                    Text(emoji)
                }
                Text(group.name)
                    .font(.headline)
                Spacer()
                Image(systemName: "line.3.horizontal")
                    .foregroundStyle(.secondary)
            }
        }
        .onMove { source, destination in
            budget.reorderGroups(from: source, to: destination)
        }
    }
    
    private var toolbarContent: some ToolbarContent {
        Group {
            ToolbarItem(placement: .navigationBarLeading) {
                HStack(spacing: 16) {
                    if !isRearrangingGroups {
                        if editMode == .inactive {
                            Menu {
                                Button("Add Category") {
                                    showingAddCategory = true
                                }
                                Button("Add Group") {
                                    showingAddGroup = true
                                }
                            } label: {
                                Label("Add", systemImage: "plus")
                            }
                        }
                        
                        Button(editMode == .active ? "Done" : "Edit") {
                            withAnimation {
                                editMode = editMode == .active ? .inactive : .active
                                budget.isEditingBudget = editMode == .active
                            }
                        }
                    } else {
                        Button("Done") {
                            withAnimation {
                                isRearrangingGroups = false
                                editMode = .inactive
                                budget.isEditingBudget = false
                            }
                        }
                    }
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                if editMode == .active && !isRearrangingGroups {
                    Button("Rearrange Groups") {
                        withAnimation {
                            isRearrangingGroups = true
                        }
                    }
                }
            }
        }
    }
}

// Drop delegate for handling category moves between groups
struct CategoryDropDelegate: DropDelegate {
    let destinationGroupId: UUID
    let budget: Budget
    let categoryGroups: [CategoryGroup]
    
    func performDrop(info: DropInfo) -> Bool {
        guard let itemProvider = info.itemProviders(for: [.text]).first else { return false }
        
        itemProvider.loadObject(ofClass: NSString.self) { (categoryId, error) in
            guard let categoryIdString = categoryId as? String,
                  let categoryId = UUID(uuidString: categoryIdString),
                  let sourceGroup = categoryGroups.first(where: { group in
                      group.categories.contains { $0.id == categoryId }
                  }),
                  let categoryIndex = sourceGroup.categories.firstIndex(where: { $0.id == categoryId })
            else { return }
            
            DispatchQueue.main.async {
                budget.moveCategory(
                    from: sourceGroup.id,
                    at: IndexSet(integer: categoryIndex),
                    to: destinationGroupId,
                    at: 0  // Insert at the beginning of the destination group
                )
            }
        }
        return true
    }
    
    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .move)
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
        case .monthly(let amount), .weekly(let amount), .byDate(let amount, _), .custom(let amount, _), .noDate(let amount):
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
            return "\(formatter.string(from: NSNumber(value: amount)) ?? "$0") by \(date.formatted(.dateTime.month().day()))"
        case .custom(let amount, let interval):
            let amountStr = formatter.string(from: NSNumber(value: amount)) ?? "$0"
            switch interval {
            case .days(let count):
                return "Every \(count) days: \(amountStr)"
            case .months(let count):
                return "Every \(count) months: \(amountStr)"
            case .years(let count):
                return "Every \(count) years: \(amountStr)"
            case .monthlyOnDay(let day):
                return "Monthly on day \(day): \(amountStr)"
            }
        case .noDate(let amount):
            return "Target: \(formatter.string(from: NSNumber(value: amount)) ?? "$0")"
        }
    }
}
import SwiftUI

struct BudgetView: View {
    @ObservedObject var budget: Budget
    @Binding var isEditing: Bool
    @State private var selectedCategory: Category?
    @State private var showingAddCategory = false
    @State private var showingAddGroup = false
    @State private var isRearrangingGroups = false
    @State private var editMode: EditMode = .inactive
    
    // Filter out Income group
    private var nonIncomeGroups: [CategoryGroup] {
        budget.categoryGroups.filter { $0.name != "Income" }
    }
    
    var body: some View {
        List {
            if !isRearrangingGroups {
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
                    Section {
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
                        
                        if !group.categories.isEmpty {
                            HStack {
                                Text("Total")
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(groupTotal(group), format: .currency(code: "USD"))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } header: {
                        HStack {
                            if let emoji = group.emoji {
                                Text(emoji)
                            }
                            Text(group.name)
                                .font(.headline)
                                .foregroundStyle(.secondary)
                            Spacer()
                            if editMode == .active {
                                Image(systemName: "line.3.horizontal")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .listRowBackground(Color(uiColor: .systemGroupedBackground))
                        .onDrag {
                            // Enable drag between groups when in edit mode
                            if editMode == .active {
                                return NSItemProvider(object: group.id.uuidString as NSString)
                            } else {
                                return NSItemProvider()
                            }
                        }
                    }
                }
                .onMove { source, destination in
                    budget.reorderGroups(from: source, to: destination)
                }
            } else {
                // Simplified view for rearranging groups
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
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())  // Make the entire row draggable
                }
                .onMove { source, destination in
                    withAnimation {
                        budget.reorderGroups(from: source, to: destination)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .environment(\.editMode, .constant(isRearrangingGroups ? .active : editMode))
        .toolbar {
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
                        
                        Button {
                            withAnimation {
                                editMode = editMode == .active ? .inactive : .active
                                isEditing = editMode == .active
                            }
                        } label: {
                            if editMode == .active {
                                Text("Done")
                            } else {
                                Label("Edit", systemImage: "arrow.up.and.down.text.horizontal")
                                    .labelStyle(.iconOnly)
                            }
                        }
                    } else {
                        Button("Done") {
                            withAnimation {
                                isRearrangingGroups = false
                                editMode = .inactive
                                isEditing = false
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
        .navigationTitle("Budget")
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
        // Get total balance from all non-archived accounts
        let totalBalance = budget.accounts
            .filter { !$0.isArchived }
            .reduce(0.0) { sum, account in
                sum + account.balance
            }
        
        // Subtract all allocated amounts from non-income categories
        let totalAllocated = nonIncomeGroups
            .flatMap(\.categories)
            .reduce(0.0) { sum, category in
                // We need to consider both allocated and spent amounts
                // If money is spent from a category, we should reduce the allocated amount
                // to avoid double-counting (since spent money is already deducted from account balance)
                let effectiveAllocation = max(0, category.allocated - category.spent)
                return sum + effectiveAllocation
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
            
            // Show allocation status bar for all categories
            VStack(alignment: .leading, spacing: 2) {
                if let target = category.target {
                    // Category with target: show progress towards target
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
                } else {
                    // Category without target: show 0% if no allocation, 100% if any allocation
                    let progress = category.allocated > 0 ? 1.0 : 0.0
                    ProgressView(value: progress, total: 1.0)
                        .tint(category.allocated > 0 ? .green : .gray)
                    
                    HStack {
                        Text("No target set")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(Int(progress * 100))%")
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

struct BudgetView_Previews: PreviewProvider {
    static var previews: some View {
        let budget = Budget()
        return NavigationStack {
            BudgetView(budget: budget, isEditing: .constant(false))
        }
    }
}
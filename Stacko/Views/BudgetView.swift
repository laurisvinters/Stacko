import SwiftUI

struct BudgetView: View {
    @ObservedObject var budget: Budget
    @State private var showingAddCategory = false
    @State private var showingAddGroup = false
    @State private var selectedCategory: Category?
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    HStack {
                        Text("Available to Budget")
                        Spacer()
                        Text(budget.availableToBudget, format: .currency(code: "USD"))
                            .foregroundColor(budget.availableToBudget >= 0 ? .primary : .red)
                    }
                }
                
                ForEach(budget.categoryGroups) { group in
                    Section {
                        ForEach(group.categories) { category in
                            CategoryRow(category: category)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedCategory = category
                                }
                        }
                    } header: {
                        HStack {
                            Text(group.name)
                            Spacer()
                            Text(groupTotal(group), format: .currency(code: "USD"))
                                .foregroundStyle(.secondary)
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
    }
    
    private var availableToBudget: Double {
        budget.monthlyIncome - budget.categoryGroups
            .flatMap(\.categories)
            .reduce(0) { $0 + $1.allocated }
    }
    
    private func groupTotal(_ group: CategoryGroup) -> Double {
        group.categories.reduce(0) { $0 + $1.allocated }
    }
}

struct CategoryRow: View {
    let category: Category
    
    var body: some View {
        HStack {
            Text(category.emoji ?? "")
            Text(category.name)
            Spacer()
            Text(category.available, format: .currency(code: "USD"))
        }
    }
} 
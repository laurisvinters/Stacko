import SwiftUI

struct ReviewSetupView: View {
    @ObservedObject var budget: Budget
    @ObservedObject var coordinator: SetupCoordinator
    @State private var expandedGroups: Set<UUID> = []
    
    var body: some View {
        List {
            Section {
                Text("Review your accounts and categories before continuing.")
                    .foregroundStyle(.secondary)
            }
            
            // Accounts Section
            Section("Accounts") {
                ForEach(budget.accounts) { account in
                    HStack {
                        Text(account.icon.isEmpty ? "💰" : account.icon)
                            .font(.title2)
                        
                        VStack(alignment: .leading) {
                            Text(account.name)
                                .font(.headline)
                            Text(account.type.rawValue)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing) {
                            Text(account.balance, format: .currency(code: "USD"))
                                .foregroundColor(account.balance >= 0 ? .primary : .red)
                            if account.balance != account.clearedBalance {
                                Text(account.clearedBalance, format: .currency(code: "USD"))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            
            // Categories Sections - wrapped in a single section to remove spacing
            Section {
                ForEach(coordinator.setupGroups) { group in
                    DisclosureGroup(
                        isExpanded: Binding(
                            get: { expandedGroups.contains(group.id) },
                            set: { isExpanded in
                                if isExpanded {
                                    expandedGroups.insert(group.id)
                                } else {
                                    expandedGroups.remove(group.id)
                                }
                            }
                        )
                    ) {
                        ForEach(group.categories.filter { coordinator.selectedCategories.contains($0.id) }) { category in
                            HStack {
                                Text(category.emoji)
                                Text(category.name)
                                
                                if let target = category.target {
                                    Spacer()
                                    Group {
                                        switch target.type {
                                        case .monthly(let amount):
                                            Text("Monthly: \(amount, format: .currency(code: "USD"))")
                                        case .weekly(let amount):
                                            Text("Weekly: \(amount, format: .currency(code: "USD"))")
                                        case .byDate(let amount, let date):
                                            Text("\(amount, format: .currency(code: "USD")) by \(date.formatted(date: .abbreviated, time: .omitted))")
                                        case .custom(let amount, let interval):
                                            switch interval {
                                            case .days(let count):
                                                Text("Every \(count) days: \(amount, format: .currency(code: "USD"))")
                                            case .months(let count):
                                                Text("Every \(count) months: \(amount, format: .currency(code: "USD"))")
                                            case .years(let count):
                                                Text("Every \(count) years: \(amount, format: .currency(code: "USD"))")
                                            case .monthlyOnDay(let day):
                                                Text("Monthly on day \(day): \(amount, format: .currency(code: "USD"))")
                                            }
                                        case .noDate(let amount):
                                            Text("Target: \(amount, format: .currency(code: "USD"))")
                                        }
                                    }
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.leading)
                        }
                    } label: {
                        HStack {
                            Text(group.name)
                                .font(.headline)
                            Spacer()
                            Text("\(group.categories.filter { coordinator.selectedCategories.contains($0.id) }.count) categories")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Review Setup")
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    coordinator.moveToPreviousStep()
                }) {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                }
            }
            
            ToolbarItem(placement: .primaryAction) {
                Button("Complete Setup") {
                    saveSetup()
                }
            }
        }
    }
    
    private func saveSetup() {
        // Save all groups and categories to Core Data
        for group in coordinator.setupGroups {
            let createdGroup = budget.addCategoryGroup(name: group.name, emoji: nil)
            
            // Only save selected categories
            for category in group.categories where coordinator.selectedCategories.contains(category.id) {
                budget.addCategory(
                    name: category.name,
                    emoji: category.emoji,
                    groupId: createdGroup.id,
                    target: category.target
                )
            }
        }
        
        coordinator.isSetupComplete = true
    }
}
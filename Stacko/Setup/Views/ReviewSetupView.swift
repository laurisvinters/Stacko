import SwiftUI

struct ReviewSetupView: View {
    @ObservedObject var budget: Budget
    @ObservedObject var coordinator: SetupCoordinator
    
    var body: some View {
        ReviewContent(budget: budget, coordinator: coordinator)
    }
}

private struct ReviewContent: View {
    @ObservedObject var budget: Budget
    @ObservedObject var coordinator: SetupCoordinator
    
    var body: some View {
        List {
            Section {
                Text("Review your setup before finishing")
                    .foregroundStyle(.secondary)
            }
            
            ReviewCategorySection(coordinator: coordinator)
            SetupAccountSection(coordinator: coordinator)
        }
        .navigationTitle("Review Setup")
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Back") {
                    coordinator.currentStep = .accounts
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
        // Save groups and categories
        for group in coordinator.setupGroups {
            let createdGroup = budget.addCategoryGroup(name: group.name, emoji: nil)
            
            for category in group.categories where coordinator.selectedCategories.contains(category.id) {
                budget.addCategory(
                    name: category.name,
                    emoji: category.emoji,
                    groupId: createdGroup.id,
                    target: category.target
                )
            }
        }
        
        // Save accounts
        for account in coordinator.setupAccounts {
            budget.addAccount(
                name: account.name,
                type: account.type,
                category: account.category,
                icon: account.icon,
                balance: account.balance,
                notes: account.notes
            )
        }
        
        coordinator.isSetupComplete = true
    }
}

// Rename to ReviewCategorySection
private struct ReviewCategorySection: View {
    @ObservedObject var coordinator: SetupCoordinator
    
    var body: some View {
        Section("Selected Categories") {
            ForEach(coordinator.setupGroups) { group in
                ReviewCategoryGroupRow(group: group, coordinator: coordinator)
            }
        }
    }
}

// Rename to ReviewCategoryGroupRow
private struct ReviewCategoryGroupRow: View {
    let group: SetupGroup
    @ObservedObject var coordinator: SetupCoordinator
    
    private var selectedCategories: [SetupCategory] {
        group.categories.filter { 
            coordinator.selectedCategories.contains($0.id) 
        }
    }
    
    var body: some View {
        if !selectedCategories.isEmpty {
            DisclosureGroup(group.name) {
                ForEach(selectedCategories) { category in
                    ReviewCategoryRow(category: category)
                }
            }
        }
    }
}

// Rename to ReviewCategoryRow
private struct ReviewCategoryRow: View {
    let category: SetupCategory
    
    var body: some View {
        HStack {
            Text(category.emoji)
            Text(category.name)
            
            if let target = category.target {
                Spacer()
                Text(targetDescription(for: target))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private func targetDescription(for target: Target) -> String {
        switch target.type {
        case .monthly(let amount):
            return "\(amount.formatted(.currency(code: "USD"))) monthly"
        case .weekly(let amount):
            return "\(amount.formatted(.currency(code: "USD"))) weekly"
        case .byDate(let amount, _):
            return "\(amount.formatted(.currency(code: "USD"))) by date"
        case .custom(let amount, _):
            return "\(amount.formatted(.currency(code: "USD"))) custom"
        case .noDate(let amount):
            return "\(amount.formatted(.currency(code: "USD"))) no date"
        }
    }
}

private struct SetupAccountSection: View {
    @ObservedObject var coordinator: SetupCoordinator
    
    var body: some View {
        Section("Accounts") {
            ForEach(coordinator.setupAccounts) { account in
                SetupAccountRow(account: account)
            }
        }
    }
}

private struct SetupAccountRow: View {
    let account: SetupAccount
    
    var body: some View {
        HStack {
            Label {
                VStack(alignment: .leading) {
                    Text(account.name)
                    Text(account.type.rawValue.capitalized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Text(account.icon)
            }
            
            Spacer()
            
            Text(account.balance, format: .currency(code: "USD"))
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    ReviewSetupView(
        budget: Budget(dataController: DataController()),
        coordinator: SetupCoordinator()
    )
} 
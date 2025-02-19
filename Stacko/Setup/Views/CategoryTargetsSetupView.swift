import SwiftUI

struct CategoryTargetsSetupView: View {
    @ObservedObject var budget: Budget
    @ObservedObject var coordinator: SetupCoordinator
    @State private var selectedCategoryForTarget: SetupCategory?
    
    // Filter out Income group for target setup
    private var nonIncomeGroups: [SetupGroup] {
        coordinator.setupGroups.filter { $0.name != "Income" }
    }
    
    var body: some View {
        List {
            Section {
                Text("Set spending targets for your categories. It is advised to set a target for each category that you want to track. Setting up targets is optional.")
                    .foregroundStyle(.secondary)
            }
            
            ForEach(nonIncomeGroups) { group in
                Section(group.name) {
                    ForEach(group.categories.filter { coordinator.selectedCategories.contains($0.id) }) { category in
                        HStack {
                            VStack(alignment: .leading) {
                                HStack {
                                    Text(category.emoji)
                                    Text(category.name)
                                }
                                
                                if let target = category.target {
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
                            
                            Spacer()
                            
                            Button(category.target == nil ? "Set Target" : "Edit") {
                                selectedCategoryForTarget = category
                            }
                            .font(.caption)
                        }
                    }
                }
            }
        }
        .navigationTitle("Set Targets")
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
                Button("Next") {
                    coordinator.moveToNextStep()
                }
            }
        }
        .sheet(item: $selectedCategoryForTarget) { category in
            TargetPickerSheet(currentTarget: category.target) { newTarget in
                updateCategoryTarget(for: category.id, target: newTarget)
            }
        }
    }
    
    private func updateCategoryTarget(for categoryId: UUID, target: Target?) {
        for groupIndex in coordinator.setupGroups.indices {
            if let categoryIndex = coordinator.setupGroups[groupIndex].categories.firstIndex(where: { $0.id == categoryId }) {
                let category = coordinator.setupGroups[groupIndex].categories[categoryIndex]
                let updatedCategory = SetupCategory(
                    id: category.id,
                    name: category.name,
                    emoji: category.emoji,
                    target: target
                )
                coordinator.setupGroups[groupIndex].categories[categoryIndex] = updatedCategory
            }
        }
    }
} 

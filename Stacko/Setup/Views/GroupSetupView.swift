import SwiftUI

struct GroupSetupView: View {
    @ObservedObject var budget: Budget
    @ObservedObject var coordinator: SetupCoordinator
    @State private var selectedGroups: Set<UUID> = []
    @State private var showingAddGroup = false
    
    // Simplified suggested groups with categories
    private static let suggestedGroups = [
        SetupGroup(name: "Housing", categories: [
            SetupCategory(name: "Rent/Mortgage", emoji: "🏠"),
            SetupCategory(name: "Utilities", emoji: "💡"),
            SetupCategory(name: "Maintenance", emoji: "🔧"),
            SetupCategory(name: "Insurance", emoji: "🔒")
        ]),
        SetupGroup(name: "Transportation", categories: [
            SetupCategory(name: "Car Payment", emoji: "🚗"),
            SetupCategory(name: "Gas", emoji: "⛽️"),
            SetupCategory(name: "Public Transit", emoji: "🚌"),
            SetupCategory(name: "Maintenance", emoji: "🔧")
        ]),
        SetupGroup(name: "Food & Dining", categories: [
            SetupCategory(name: "Groceries", emoji: "🛒"),
            SetupCategory(name: "Restaurants", emoji: "🍽️"),
            SetupCategory(name: "Coffee Shops", emoji: "☕️"),
            SetupCategory(name: "Takeout", emoji: "🥡")
        ]),
        SetupGroup(name: "Bills & Utilities", categories: [
            SetupCategory(name: "Phone", emoji: "📱"),
            SetupCategory(name: "Internet", emoji: "🌐"),
            SetupCategory(name: "Streaming", emoji: "📺"),
            SetupCategory(name: "Subscriptions", emoji: "📦")
        ]),
        SetupGroup(name: "Shopping", categories: [
            SetupCategory(name: "Clothing", emoji: "👕"),
            SetupCategory(name: "Electronics", emoji: "🖥️"),
            SetupCategory(name: "Home Goods", emoji: "🏠"),
            SetupCategory(name: "Personal Care", emoji: "🧴")
        ]),
        SetupGroup(name: "Entertainment", categories: [
            SetupCategory(name: "Movies", emoji: "🎬"),
            SetupCategory(name: "Games", emoji: "🎮"),
            SetupCategory(name: "Sports", emoji: "⚽️"),
            SetupCategory(name: "Hobbies", emoji: "🎨")
        ])
    ]
    
    private var allGroups: [SetupGroup] {
        Self.suggestedGroups + customGroups
    }
    
    @State private var customGroups: [SetupGroup] = []
    
    var body: some View {
        List {
            Section {
                Text("Select the groups you want to track your spending in.")
                    .foregroundStyle(.secondary)
            }
            
            Section {
                ForEach(allGroups) { group in
                    Button {
                        toggleGroup(group.id)
                    } label: {
                        HStack {
                            Image(systemName: selectedGroups.contains(group.id) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(selectedGroups.contains(group.id) ? .blue : .secondary)
                                .imageScale(.large)
                                .frame(width: 44, height: 44)
                            
                            Text(group.name)
                                .font(.body)
                            
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            
            Section {
                Button {
                    showingAddGroup = true
                } label: {
                    Label("Add Custom Group", systemImage: "plus.circle")
                        .frame(height: 44)
                }
            }
        }
        .navigationTitle("Setup Groups")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Next") {
                    // Save selected groups to coordinator
                    coordinator.setupGroups = allGroups.filter { selectedGroups.contains($0.id) }
                    coordinator.currentStep = .categories
                }
                .disabled(selectedGroups.isEmpty)
            }
        }
        .sheet(isPresented: $showingAddGroup) {
            AddGroupSheet(budget: budget) { newGroup in
                let group = SetupGroup(id: newGroup.id, name: newGroup.name)
                customGroups.append(group)
                selectedGroups.insert(group.id)
                budget.deleteGroup(newGroup.id)
            }
        }
    }
    
    private func toggleGroup(_ id: UUID) {
        if selectedGroups.contains(id) {
            selectedGroups.remove(id)
        } else {
            selectedGroups.insert(id)
        }
    }
}

#Preview {
    NavigationStack {
        GroupSetupView(
            budget: Budget(dataController: DataController()),
            coordinator: SetupCoordinator()
        )
    }
} 
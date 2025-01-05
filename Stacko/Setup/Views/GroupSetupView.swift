import SwiftUI

struct GroupSetupView: View {
    @ObservedObject var budget: Budget
    @ObservedObject var coordinator: SetupCoordinator
    @State private var selectedGroups: Set<UUID> = []
    @State private var showingAddGroup = false
    
    // Simplified suggested groups without categories
    private static let suggestedGroups = [
        SetupGroup(name: "Housing"),
        SetupGroup(name: "Transportation"),
        SetupGroup(name: "Food & Dining"),
        SetupGroup(name: "Bills & Utilities"),
        SetupGroup(name: "Shopping"),
        SetupGroup(name: "Entertainment")
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
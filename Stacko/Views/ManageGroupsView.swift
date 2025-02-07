import SwiftUI

struct ManageGroupsView: View {
    @ObservedObject var budget: Budget
    @State private var editingGroup: CategoryGroup?
    @State private var showingDeleteAlert = false
    @State private var groupToDelete: UUID?
    @State private var editingName = ""
    
    var body: some View {
        List {
            Text("Swipe right to edit a group, or swipe left to delete it.")
                .font(.caption)
                .foregroundColor(.secondary)
                .listRowSeparator(.hidden)
            
            ForEach(budget.categoryGroups.filter { $0.name != "Income" }) { group in
                HStack {
                    Text(group.name)
                    Spacer()
                    Text("\(group.categories.count) categories")
                        .foregroundStyle(.secondary)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        groupToDelete = group.id
                        showingDeleteAlert = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    Button {
                        editingGroup = group
                        editingName = group.name
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    .tint(.blue)
                }
                .swipeHint(enabled: group.id == budget.categoryGroups.filter { $0.name != "Income" }.first?.id)
            }
        }
        .navigationTitle("Manage Groups")
        .sheet(item: $editingGroup) { group in
            NavigationStack {
                EditGroupView(budget: budget, group: group, name: group.name)
            }
            .presentationDetents([.medium])
        }
        .alert("Delete Group", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let groupId = groupToDelete {
                    budget.deleteGroup(groupId)
                }
            }
        } message: {
            Text("Are you sure you want to delete this group? All categories in this group will also be deleted. This action cannot be undone.")
        }
    }
}

struct EditGroupView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var budget: Budget
    let group: CategoryGroup
    @State private var name: String
    
    init(budget: Budget, group: CategoryGroup, name: String) {
        self.budget = budget
        self.group = group
        _name = State(initialValue: name)
    }
    
    var body: some View {
        Form {
            Section {
                TextField("Group Name", text: $name)
            }
        }
        .navigationTitle("Edit Group")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    budget.updateGroup(groupId: group.id, name: name)
                    dismiss()
                }
                .disabled(name.isEmpty)
            }
        }
    }
}

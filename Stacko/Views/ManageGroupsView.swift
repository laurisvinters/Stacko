import SwiftUI

struct SwipeInstructionText: View {
    var body: some View {
        (Text("Swipe left to ")
            .foregroundColor(.gray) +
         Text("delete")
            .foregroundColor(.blue) +
         Text(" transactions. Swipe right, then click to ")
            .foregroundColor(.gray) +
         Text("edit")
            .foregroundColor(.blue) +
         Text(" transactions")
            .foregroundColor(.gray))
            .font(.caption)
            .frame(maxWidth: .infinity, alignment: .leading)
            .listRowBackground(Color.clear)
    }
}

struct ManageGroupsView: View {
    @ObservedObject var budget: Budget
    @State private var editingGroup: CategoryGroup?
    @State private var showingDeleteAlert = false
    @State private var groupToDelete: UUID?
    @State private var editingName = ""
    @State private var showingAddGroup = false
    
    var body: some View {
        List {
            Section {
                SwipeInstructionText()
            }
            .listSectionSpacing(0)
            
            Section {
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
                }
            }
        }
        .navigationTitle("Manage Groups")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingAddGroup = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddGroup) {
            AddGroupSheet(budget: budget)
        }
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
            Text("Are you sure you want to delete this group? This action cannot be undone.")
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

import SwiftUI

struct GroupSetupView: View {
    @ObservedObject var budget: Budget
    @ObservedObject var coordinator: SetupCoordinator
    @State private var selectedGroups: Set<UUID> = []
    @State private var showingAddGroup = false
    @State private var customGroups: [SetupGroup] = []
    
    // Expanded suggested groups with categories
    private static let suggestedGroups = [
        SetupGroup(name: "Housing", categories: [
            SetupCategory(name: "Rent/Mortgage", emoji: "🏠"),
            SetupCategory(name: "Property Tax", emoji: "📋"),
            SetupCategory(name: "Home Insurance", emoji: "🔒"),
            SetupCategory(name: "Home Maintenance", emoji: "🔧"),
            SetupCategory(name: "Home Improvement", emoji: "🏗️"),
            SetupCategory(name: "Furniture", emoji: "🛋️")
        ]),
        SetupGroup(name: "Transportation", categories: [
            SetupCategory(name: "Car Payment", emoji: "🚗"),
            SetupCategory(name: "Car Insurance", emoji: "🔒"),
            SetupCategory(name: "Gas", emoji: "⛽️"),
            SetupCategory(name: "Car Maintenance", emoji: "🔧"),
            SetupCategory(name: "Public Transit", emoji: "🚌"),
            SetupCategory(name: "Parking", emoji: "🅿️")
        ]),
        SetupGroup(name: "Food", categories: [
            SetupCategory(name: "Groceries", emoji: "🛒"),
            SetupCategory(name: "Restaurants", emoji: "🍽️"),
            SetupCategory(name: "Coffee Shops", emoji: "☕️"),
            SetupCategory(name: "Food Delivery", emoji: "🛵"),
            SetupCategory(name: "Snacks", emoji: "🍿")
        ]),
        SetupGroup(name: "Monthly Bills", categories: [
            SetupCategory(name: "Utilities", emoji: "⚡️"),
            SetupCategory(name: "Phone & Internet", emoji: "📱"),
            SetupCategory(name: "Insurance", emoji: "📄"),
            SetupCategory(name: "Credit Card", emoji: "💳"),
            SetupCategory(name: "Loan Payments", emoji: "💰")
        ]),
        SetupGroup(name: "Shopping", categories: [
            SetupCategory(name: "Clothing", emoji: "👕"),
            SetupCategory(name: "Electronics", emoji: "🖥️"),
            SetupCategory(name: "Accessories", emoji: "👜"),
            SetupCategory(name: "Jewelry", emoji: "💍"),
            SetupCategory(name: "Equipment", emoji: "🛠"),
            SetupCategory(name: "Gifts", emoji: "🎁"),
            SetupCategory(name: "Online Shopping", emoji: "🛒")
        ]),
        SetupGroup(name: "Entertainment", categories: [
            SetupCategory(name: "Netflix", emoji: "📺"),
            SetupCategory(name: "Games", emoji: "🎮"),
            SetupCategory(name: "Sports", emoji: "⚽️"),
            SetupCategory(name: "Concerts", emoji: "🎵"),
            SetupCategory(name: "Streaming Services", emoji: "📺"),
            SetupCategory(name: "Books", emoji: "📚"),
            SetupCategory(name: "Hobbies", emoji: "🎨")
        ]),
        SetupGroup(name: "Health", categories: [
            SetupCategory(name: "Medical", emoji: "🏥"),
            SetupCategory(name: "Dental", emoji: "🦷"),
            SetupCategory(name: "Vision", emoji: "👓"),
            SetupCategory(name: "Pharmacy", emoji: "💊"),
            SetupCategory(name: "Fitness", emoji: "🏋")
        ]),
        SetupGroup(name: "Personal Care", categories: [
            SetupCategory(name: "Hair Care", emoji: "💇"),
            SetupCategory(name: "Skincare", emoji: "🧴"),
            SetupCategory(name: "Cosmetics", emoji: "💄"),
            SetupCategory(name: "Spa & Massage", emoji: "💆"),
            SetupCategory(name: "Grooming", emoji: "✂️")
        ]),
        SetupGroup(name: "Education", categories: [
            SetupCategory(name: "Tuition", emoji: "🎓"),
            SetupCategory(name: "Books", emoji: "📚"),
            SetupCategory(name: "Courses", emoji: "📝"),
            SetupCategory(name: "School Supplies", emoji: "🎒"),
            SetupCategory(name: "Student Loans", emoji: "💰")
        ]),
        SetupGroup(name: "Travel / Holidays", categories: [
            SetupCategory(name: "Flights", emoji: "✈️"),
            SetupCategory(name: "Hotels", emoji: "🏨"),
            SetupCategory(name: "Car Rental", emoji: "🚗"),
            SetupCategory(name: "Activities", emoji: "🎯"),
            SetupCategory(name: "Travel Insurance", emoji: "🔒"),
            SetupCategory(name: "Food & Dining", emoji: "🍽️"),
            SetupCategory(name: "Shopping", emoji: "🛍️"),
            SetupCategory(name: "Tours & Excursions", emoji: "🏛️"),
            SetupCategory(name: "Beach Activities", emoji: "🏖️"),
            SetupCategory(name: "Souvenirs", emoji: "🎁")
        ]),
        SetupGroup(name: "Pets", categories: [
            SetupCategory(name: "Food", emoji: "🦴"),
            SetupCategory(name: "Vet", emoji: "🏥"),
            SetupCategory(name: "Supplies", emoji: "🪮"),
            SetupCategory(name: "Grooming", emoji: "✂️"),
            SetupCategory(name: "Insurance", emoji: "📄")
        ])
    ]
    
    private var allGroups: [SetupGroup] {
        Self.suggestedGroups + customGroups
    }
    
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
                    // Clear any existing data before setting up new groups
                    coordinator.setupGroups.removeAll()
                    coordinator.selectedCategories.removeAll()
                    
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
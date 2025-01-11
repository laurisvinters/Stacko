import SwiftUI

struct GroupSetupView: View {
    @ObservedObject var budget: Budget
    @ObservedObject var coordinator: SetupCoordinator
    @ObservedObject var authManager: AuthenticationManager
    @State private var selectedGroups: Set<UUID> = []
    @State private var showingAddGroup = false
    @State private var customGroups: [SetupGroup] = []
    @State private var showingCancelAlert = false
    
    // Updated suggested groups with descriptions and example categories
    private static let suggestedGroups = [
        SetupGroup(name: "Housing", categories: [
            SetupCategory(name: "Rent/Mortgage", emoji: "🏠"),
            SetupCategory(name: "Property Tax", emoji: "📋"),
            SetupCategory(name: "Home Insurance", emoji: "🔒"),
            SetupCategory(name: "Home Maintenance", emoji: "🔧"),
            SetupCategory(name: "Home Improvement", emoji: "🏗️"),
            SetupCategory(name: "Furniture", emoji: "🛋️")
        ], description: "Track all housing-related expenses",
           examples: "Rent, utilities, maintenance, insurance"),
        
        SetupGroup(name: "Transportation", categories: [
            SetupCategory(name: "Car Payment", emoji: "🚗"),
            SetupCategory(name: "Car Insurance", emoji: "🔒"),
            SetupCategory(name: "Gas", emoji: "⛽️"),
            SetupCategory(name: "Car Maintenance", emoji: "🔧"),
            SetupCategory(name: "Public Transit", emoji: "🚌"),
            SetupCategory(name: "Parking", emoji: "🅿️")
        ], description: "All your transportation costs",
           examples: "Car payments, gas, public transit"),
        
        SetupGroup(name: "Food", categories: [
            SetupCategory(name: "Groceries", emoji: "🛒"),
            SetupCategory(name: "Restaurants", emoji: "🍽️"),
            SetupCategory(name: "Coffee Shops", emoji: "☕️"),
            SetupCategory(name: "Food Delivery", emoji: "🛵"),
            SetupCategory(name: "Snacks", emoji: "🍿")
        ], description: "Track food and dining expenses",
           examples: "Groceries, restaurants, takeout"),
        
        SetupGroup(name: "Monthly Bills", categories: [
            SetupCategory(name: "Utilities", emoji: "⚡️"),
            SetupCategory(name: "Phone & Internet", emoji: "📱"),
            SetupCategory(name: "Insurance", emoji: "📄"),
            SetupCategory(name: "Credit Card", emoji: "💳"),
            SetupCategory(name: "Loan Payments", emoji: "💰")
        ], description: "Regular monthly payments and subscriptions",
           examples: "Utilities, phone bills, insurance premiums"),
        SetupGroup(name: "Shopping", categories: [
            SetupCategory(name: "Clothing", emoji: "👕"),
            SetupCategory(name: "Electronics", emoji: "🖥️"),
            SetupCategory(name: "Accessories", emoji: "👜"),
            SetupCategory(name: "Jewelry", emoji: "💍"),
            SetupCategory(name: "Equipment", emoji: "🛠"),
            SetupCategory(name: "Gifts", emoji: "🎁"),
            SetupCategory(name: "Online Shopping", emoji: "🛒")
        ], description: "Track retail purchases and shopping expenses",
           examples: "Clothing, electronics, accessories"),
        SetupGroup(name: "Entertainment", categories: [
            SetupCategory(name: "Netflix", emoji: "📺"),
            SetupCategory(name: "Games", emoji: "🎮"),
            SetupCategory(name: "Sports", emoji: "⚽️"),
            SetupCategory(name: "Concerts", emoji: "🎵"),
            SetupCategory(name: "Streaming Services", emoji: "📺"),
            SetupCategory(name: "Books", emoji: "📚"),
            SetupCategory(name: "Hobbies", emoji: "🎨")
        ], description: "Fun and leisure activities",
           examples: "Streaming services, games, concerts"),
        SetupGroup(name: "Health", categories: [
            SetupCategory(name: "Medical", emoji: "🏥"),
            SetupCategory(name: "Dental", emoji: "🦷"),
            SetupCategory(name: "Vision", emoji: "👓"),
            SetupCategory(name: "Pharmacy", emoji: "💊"),
            SetupCategory(name: "Fitness", emoji: "🏋")
        ], description: "Medical and wellness expenses",
           examples: "Doctor visits, medications, fitness"),
        SetupGroup(name: "Personal Care", categories: [
            SetupCategory(name: "Hair Care", emoji: "💇"),
            SetupCategory(name: "Skincare", emoji: "🧴"),
            SetupCategory(name: "Cosmetics", emoji: "💄"),
            SetupCategory(name: "Spa & Massage", emoji: "💆"),
            SetupCategory(name: "Grooming", emoji: "✂️")
        ], description: "Personal grooming and self-care",
           examples: "Haircuts, skincare, spa services"),
        SetupGroup(name: "Education", categories: [
            SetupCategory(name: "Tuition", emoji: "🎓"),
            SetupCategory(name: "Books", emoji: "📚"),
            SetupCategory(name: "Courses", emoji: "📝"),
            SetupCategory(name: "School Supplies", emoji: "🎒"),
            SetupCategory(name: "Student Loans", emoji: "💰")
        ], description: "Learning and educational expenses",
           examples: "Tuition, books, courses, supplies"),
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
        ], description: "Vacation and travel expenses",
           examples: "Flights, hotels, activities, souvenirs"),
        SetupGroup(name: "Pets", categories: [
            SetupCategory(name: "Food", emoji: "🦴"),
            SetupCategory(name: "Vet", emoji: "🏥"),
            SetupCategory(name: "Supplies", emoji: "🪮"),
            SetupCategory(name: "Grooming", emoji: "✂️"),
            SetupCategory(name: "Insurance", emoji: "📄")
        ], description: "Pet care and maintenance expenses",
           examples: "Food, vet visits, supplies, grooming"),
        SetupGroup(name: "Income", categories: [
            SetupCategory(name: "Salary", emoji: "💰"),
            SetupCategory(name: "Investments", emoji: "📈"),
            SetupCategory(name: "Side Jobs", emoji: "💼"),
            SetupCategory(name: "Gifts", emoji: "🎁"),
            SetupCategory(name: "Rental Income", emoji: "🏠"),
            SetupCategory(name: "Dividends", emoji: "💵"),
            SetupCategory(name: "Refunds", emoji: "🔄")
        ], description: "Track all sources of income",
           examples: "Salary, investments, side jobs")
    ]
    
    var body: some View {
        List {
            Section {
                Text("Select the groups you want to track your spending in.")
                    .foregroundStyle(.secondary)
            }
            
            Section("Recommended Groups") {
                ForEach(Self.suggestedGroups) { group in
                    VStack(alignment: .leading, spacing: 0) {
                        GroupRow(
                            group: group,
                            isSelected: selectedGroups.contains(group.id),
                            isRequired: group.name == "Income"
                        ) {
                            if group.name != "Income" {
                        toggleGroup(group.id)
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(group.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("Examples: \(group.examples)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.leading, 32)
                        .padding(.bottom, 8)
                    }
                    .listRowInsets(EdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8))
                }
            }
            
            // Custom Groups Section (only show if there are custom groups)
            if !customGroups.isEmpty {
                Section("Custom Groups") {
                    ForEach(customGroups) { group in
                        GroupRow(
                            group: group,
                            isSelected: selectedGroups.contains(group.id),
                            isRequired: false
                        ) {
                            toggleGroup(group.id)
                        }
                    }
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
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    showingCancelAlert = true
                }
            }
            
            ToolbarItem(placement: .primaryAction) {
                Button("Next") {
                    let selectedSetupGroups = Self.suggestedGroups
                        .filter { selectedGroups.contains($0.id) }
                        .map { $0 }
                    coordinator.setInitialGroups(selectedSetupGroups + customGroups)
                    coordinator.currentStep = .categories
                }
                .disabled(selectedGroups.isEmpty)
            }
        }
        .alert("Cancel Setup", isPresented: $showingCancelAlert) {
            Button("Continue Setup", role: .cancel) { }
            Button("Cancel Setup", role: .destructive) {
                coordinator.cancelSetup()
                authManager.signOut()
            }
        } message: {
            Text("Are you sure you want to cancel the setup process? All progress will be lost.")
        }
        .sheet(isPresented: $showingAddGroup) {
            AddGroupSheet(budget: budget) { newGroup in
                // Create a new SetupGroup with empty description and examples
                let group = SetupGroup(
                    id: newGroup.id,
                    name: newGroup.name,
                    categories: [],
                    description: "Custom group",
                    examples: "Add your own categories"
                )
                customGroups.append(group)
                selectedGroups.insert(group.id)
                
                // Only try to delete if the group exists
                if newGroup.id != UUID() {
                budget.deleteGroup(newGroup.id)
                }
            }
        }
        .onAppear {
            selectedGroups = Set(Self.suggestedGroups.map { $0.id })
        }
    }
    
    private func toggleGroup(_ id: UUID) {
        if let group = Self.suggestedGroups.first(where: { $0.id == id }), group.name == "Income" {
            return
        }
        
        if selectedGroups.contains(id) {
            selectedGroups.remove(id)
        } else {
            selectedGroups.insert(id)
        }
    }
}

// Helper view for group rows
struct GroupRow: View {
    let group: SetupGroup
    let isSelected: Bool
    let isRequired: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? .blue : .secondary)
                    .imageScale(.large)
                    .frame(width: 44, height: 44)
                
                Text(group.name)
                    .font(.body)
                
                if isRequired {
                    Spacer()
                    Text("Required")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            .listRowInsets(EdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isRequired)
    }
}

#Preview {
    let dataController = DataController()
    let budget = Budget(dataController: dataController)
    let coordinator = SetupCoordinator()
    let authManager = AuthenticationManager(
        dataController: dataController,
        budget: budget,
        setupCoordinator: coordinator
    )
    
    return NavigationStack {
        GroupSetupView(
            budget: budget,
            coordinator: coordinator,
            authManager: authManager
        )
    }
} 

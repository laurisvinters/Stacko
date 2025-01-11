import SwiftUI

struct AccountSetupView: View {
    @ObservedObject var budget: Budget
    @ObservedObject var coordinator: SetupCoordinator
    @State private var showingAddAccount = false
    @State private var showingCancelAlert = false
    
    var body: some View {
        List {
            Section {
                Text("Add your accounts to start tracking your money")
                    .foregroundStyle(.secondary)
            }
            
            if coordinator.setupAccounts.isEmpty {
                Section {
                    Button(action: { showingAddAccount = true }) {
                        Label("Add Account", systemImage: "plus.circle.fill")
                    }
                }
            } else {
                Section("Your Accounts") {
                    ForEach(coordinator.setupAccounts) { account in
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
                    .onDelete { indexSet in
                        coordinator.setupAccounts.remove(atOffsets: indexSet)
                    }
                    
                    Button(action: { showingAddAccount = true }) {
                        Label("Add Another Account", systemImage: "plus.circle.fill")
                    }
                }
            }
        }
        .navigationTitle("Setup Accounts")
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Back") {
                    coordinator.currentStep = .categories
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Cancel") {
                    showingCancelAlert = true
                }
            }
            
            ToolbarItem(placement: .primaryAction) {
                Button("Next") {
                    coordinator.currentStep = .review
                }
                .disabled(coordinator.setupAccounts.isEmpty)
            }
        }
        .sheet(isPresented: $showingAddAccount) {
            SetupAddAccountSheet(coordinator: coordinator)
        }
        .alert("Cancel Setup", isPresented: $showingCancelAlert) {
            Button("Continue Setup", role: .cancel) { }
            Button("Cancel Setup", role: .destructive) {
                coordinator.cancelSetup()
            }
        } message: {
            Text("Are you sure you want to cancel the setup process? All progress will be lost.")
        }
    }
}

struct SetupAddAccountSheet: View {
    @ObservedObject var coordinator: SetupCoordinator
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var type: Account.AccountType = .checking
    @State private var category: Account.AccountCategory = .personal
    @State private var balance = ""
    @State private var selectedIcon = "🏦"
    @State private var notes = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Account Name", text: $name)
                    
                    Picker("Type", selection: $type) {
                        ForEach(Account.AccountType.allCases, id: \.self) { type in
                            Text(type.rawValue.capitalized).tag(type)
                        }
                    }
                    
                    Picker("Category", selection: $category) {
                        ForEach(Account.AccountCategory.allCases, id: \.self) { category in
                            Text(category.rawValue.capitalized).tag(category)
                        }
                    }
                    
                    TextField("Current Balance", text: $balance)
                        .keyboardType(.decimalPad)
                }
                
                Section("Icon") {
                    ScrollView(.horizontal) {
                        HStack {
                            ForEach(["🏦", "💳", "💰", "🏧", "💵", "🪙", "💹", "📊"], id: \.self) { emoji in
                                Button(action: { selectedIcon = emoji }) {
                                    Text(emoji)
                                        .font(.title)
                                        .padding(8)
                                        .background(
                                            selectedIcon == emoji ? 
                                                Color.accentColor.opacity(0.2) : Color.clear
                                        )
                                        .clipShape(Circle())
                                }
                            }
                        }
                    }
                }
                
                Section("Notes (Optional)") {
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3)
                }
            }
            .navigationTitle("Add Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { saveAccount() }
                        .disabled(!isValid)
                }
            }
        }
    }
    
    private var isValid: Bool {
        !name.isEmpty && Double(balance) != nil
    }
    
    private func saveAccount() {
        guard let balanceDouble = Double(balance) else { return }
        
        let account = SetupAccount(
            id: UUID(),
            name: name,
            type: type,
            category: category,
            balance: balanceDouble,
            icon: selectedIcon,
            notes: notes.isEmpty ? nil : notes
        )
        
        coordinator.setupAccounts.append(account)
        dismiss()
    }
} 
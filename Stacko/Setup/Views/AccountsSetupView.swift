import SwiftUI

struct AccountsSetupView: View {
    @ObservedObject var coordinator: SetupCoordinator
    @ObservedObject var budget: Budget
    @State private var showAddAccount = false
    @State private var selectedAccounts: Set<UUID> = []
    @State private var showingCancelAlert = false
    
    var body: some View {
        List {
            Section {
                Text("Add your financial accounts to start tracking your spending and saving goals.")
                    .foregroundStyle(.secondary)
            }
            
            Section("Your Accounts") {
                ForEach(budget.accounts) { account in
                    accountRow(account)
                }
                
                Button {
                    showAddAccount = true
                } label: {
                    Label("Add Account", systemImage: "plus.circle")
                        .frame(height: 44)
                }
            }
        }
        .navigationTitle("Set Up Accounts")
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
                .disabled(budget.accounts.isEmpty)
            }
        }
        .sheet(isPresented: $showAddAccount) {
            AddAccountSheet(budget: budget)
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
    
    private func accountRow(_ account: Account) -> some View {
        HStack {
            HStack(spacing: 8) {
                Text(account.icon.isEmpty ? "💰" : account.icon)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(account.name)
                        .font(.headline)
                    Text(account.type.rawValue)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
        }
        .contentShape(Rectangle())
        .frame(height: 44)
    }
}

#Preview {
    NavigationStack {
        AccountsSetupView(
            coordinator: SetupCoordinator(),
            budget: Budget(dataController: DataController())
        )
    }
}

import SwiftUI

struct AccountsView: View {
    @ObservedObject var budget: Budget
    @State private var showingAddAccount = false
    @State private var showingTransfer = false
    
    var body: some View {
        List {
            Section {
                ForEach(budget.accounts.filter { !$0.isArchived }) { account in
                    AccountRow(budget: budget, account: account)
                }
            } header: {
                HStack {
                    Text("Accounts")
                    Spacer()
                    Text(totalBalance, format: .currency(code: "USD"))
                        .foregroundStyle(.secondary)
                }
            }
            
            if !archivedAccounts.isEmpty {
                Section("Archived") {
                    ForEach(archivedAccounts) { account in
                        AccountRow(budget: budget, account: account)
                    }
                }
            }
        }
        .navigationTitle("Accounts")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        showingAddAccount = true
                    } label: {
                        Label("Add Account", systemImage: "plus")
                    }
                    
                    Button {
                        showingTransfer = true
                    } label: {
                        Label("Transfer", systemImage: "arrow.left.arrow.right")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingAddAccount) {
            AddAccountSheet(budget: budget)
        }
        .sheet(isPresented: $showingTransfer) {
            TransferSheet(budget: budget)
        }
    }
    
    private var totalBalance: Double {
        budget.accounts
            .filter { !$0.isArchived }
            .reduce(0) { $0 + $1.balance }
    }
    
    private var archivedAccounts: [Account] {
        budget.accounts.filter(\.isArchived)
    }
}

struct AccountRow: View {
    @ObservedObject var budget: Budget
    let account: Account
    
    var body: some View {
        NavigationLink {
            AccountDetailView(budget: budget, account: account)
        } label: {
            HStack {
                Text(account.icon)
                
                VStack(alignment: .leading) {
                    Text(account.name)
                    HStack {
                        Text(account.type.rawValue)
                        Text("•")
                        Text(account.category.rawValue)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text(account.balance, format: .currency(code: "USD"))
                        .foregroundColor(account.balance >= 0 ? .primary : .red)
                    if account.balance != account.clearedBalance {
                        Text(account.clearedBalance, format: .currency(code: "USD"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
} 
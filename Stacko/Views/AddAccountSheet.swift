import SwiftUI

struct AddAccountSheet: View {
    @ObservedObject var budget: Budget
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var type = Account.AccountType.cash
    @State private var currentBalance = ""
    
    var body: some View {
        NavigationStack {
            Form {
                TextField("Account Name", text: $name)
                
                Picker("Type", selection: $type) {
                    ForEach(Account.AccountType.allCases, id: \.self) { type in
                        Text(type.rawValue)
                            .tag(type)
                    }
                }
                
                TextField("Current Balance", text: $currentBalance)
                    .keyboardType(.decimalPad)
            }
            .navigationTitle("New Account")
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.interactively)
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { saveAccount() }
                        .disabled(name.isEmpty || currentBalance.isEmpty)
                }
            }
        }
    }
    
    private func saveAccount() {
        let balance = Double(currentBalance.replacingOccurrences(of: ",", with: ".")) ?? 0
        
        budget.addAccount(
            name: name,
            type: type,
            icon: type.icon,
            balance: balance
        )
        
        dismiss()
    }
}
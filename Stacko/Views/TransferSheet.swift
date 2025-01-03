import SwiftUI

struct TransferSheet: View {
    @ObservedObject var budget: Budget
    @Environment(\.dismiss) private var dismiss
    
    @State private var amount = ""
    @State private var fromAccountId: UUID?
    @State private var toAccountId: UUID?
    @State private var date = Date()
    @State private var note = ""
    
    var body: some View {
        NavigationStack {
            Form {
                TextField("Amount", text: $amount)
                    .keyboardType(.decimalPad)
                
                Picker("From Account", selection: $fromAccountId) {
                    Text("Select Account").tag(Optional<UUID>.none)
                    ForEach(budget.accounts.filter { !$0.isArchived }) { account in
                        Text(account.name)
                            .tag(Optional(account.id))
                    }
                }
                
                Picker("To Account", selection: $toAccountId) {
                    Text("Select Account").tag(Optional<UUID>.none)
                    ForEach(budget.accounts.filter { !$0.isArchived }) { account in
                        Text(account.name)
                            .tag(Optional(account.id))
                    }
                }
                
                DatePicker("Date", selection: $date, displayedComponents: .date)
                
                TextField("Note", text: $note)
            }
            .navigationTitle("Transfer Money")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Transfer") { performTransfer() }
                        .disabled(!isValid)
                }
            }
        }
    }
    
    private var isValid: Bool {
        guard let amountDouble = Double(amount),
              let from = fromAccountId,
              let to = toAccountId,
              from != to,
              amountDouble > 0 else {
            return false
        }
        return true
    }
    
    private func performTransfer() {
        guard let amountDouble = Double(amount),
              let fromId = fromAccountId,
              let toId = toAccountId else { return }
        
        budget.createTransfer(
            from: fromId,
            to: toId,
            amount: amountDouble,
            date: date,
            note: note.isEmpty ? nil : note
        )
        
        dismiss()
    }
} 
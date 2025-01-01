import SwiftUI

struct TemplateFormSheet: View {
    @ObservedObject var budget: Budget
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var amount = ""
    @State private var payee = ""
    @State private var selectedCategoryId: UUID?
    @State private var isIncome = false
    @State private var recurrence: TransactionTemplate.Recurrence?
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Template Name", text: $name)
                    TextField("Amount", text: $amount)
                        .keyboardType(.decimalPad)
                    TextField("Payee", text: $payee)
                    
                    Picker("Category", selection: $selectedCategoryId) {
                        ForEach(budget.categoryGroups) { group in
                            Section(group.name) {
                                ForEach(group.categories) { category in
                                    Text(category.name)
                                        .tag(Optional(category.id))
                                }
                            }
                        }
                    }
                    
                    Toggle("Income", isOn: $isIncome)
                }
                
                Section("Recurrence") {
                    Picker("Repeat", selection: $recurrence) {
                        Text("None").tag(Optional<TransactionTemplate.Recurrence>.none)
                        ForEach([
                            TransactionTemplate.Recurrence.daily,
                            .weekly,
                            .monthly,
                            .yearly
                        ], id: \.self) { recurrence in
                            Text(recurrence.description).tag(Optional(recurrence))
                        }
                    }
                }
            }
            .navigationTitle("New Template")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveTemplate() }
                        .disabled(!isValid)
                }
            }
        }
    }
    
    private var isValid: Bool {
        guard let amountDouble = Double(amount),
              amountDouble > 0,
              !name.isEmpty,
              !payee.isEmpty,
              selectedCategoryId != nil else {
            return false
        }
        return true
    }
    
    private func saveTemplate() {
        guard let amountDouble = Double(amount),
              let categoryId = selectedCategoryId else { return }
        
        let template = TransactionTemplate(
            id: UUID(),
            name: name,
            payee: payee,
            categoryId: categoryId,
            amount: amountDouble,
            isIncome: isIncome,
            recurrence: recurrence
        )
        
        budget.templates.append(template)
        dismiss()
    }
} 
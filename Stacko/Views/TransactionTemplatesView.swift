import SwiftUI

struct TransactionTemplatesView: View {
    @ObservedObject var budget: Budget
    @State private var showingAddTemplate = false
    @State private var selectedTemplate: TransactionTemplate?
    
    var body: some View {
        List {
            ForEach(budget.templates) { template in
                TemplateRow(template: template)
                    .swipeActions {
                        Button {
                            budget.createTransactionFromTemplate(template)
                        } label: {
                            Label("Create", systemImage: "plus.circle")
                        }
                        .tint(.green)
                    }
            }
        }
        .navigationTitle("Templates")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddTemplate = true
                } label: {
                    Label("Add Template", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddTemplate) {
            TemplateFormSheet(budget: budget)
        }
    }
}

struct TemplateRow: View {
    let template: TransactionTemplate
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(template.name)
                    .font(.headline)
                Spacer()
                Text(template.amount, format: .currency(code: "USD"))
                    .foregroundStyle(template.isIncome ? .green : .primary)
            }
            
            HStack {
                Text(template.payee)
                if let recurrence = template.recurrence {
                    Text("•")
                    Text(recurrence.description)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
} 
import SwiftUI
import Foundation

struct SetTargetSheet: View {
    @ObservedObject var budget: Budget
    let category: Category
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isAmountFocused: Bool
    
    @State private var targetType: TargetType = .monthly
    @State private var amount = ""
    @State private var targetDate = Date()
    
    enum TargetType: String, CaseIterable {
        case monthly = "Monthly"
        case weekly = "Weekly"
        case byDate = "By Date"
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Picker("Target Type", selection: $targetType) {
                    ForEach(TargetType.allCases, id: \.self) { type in
                        Text(type.rawValue)
                    }
                }
                
                TextField("Target Amount", text: $amount)
                    .keyboardType(.decimalPad)
                    .focused($isAmountFocused)
                    .toolbar {
                        ToolbarItemGroup(placement: .keyboard) {
                            Spacer()
                            Button("Done") {
                                isAmountFocused = false
                            }
                        }
                    }
                
                if targetType == .byDate {
                    DatePicker("Target Date", selection: $targetDate, displayedComponents: .date)
                }
            }
            .navigationTitle("Set Target")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveTarget() }
                        .disabled(Double(amount) == nil)
                }
            }
        }
    }
    
    private func saveTarget() {
        guard let amountDouble = Double(amount) else { return }
        
        let target: Target
        switch targetType {
        case .monthly:
            target = Target(type: .monthly(amount: amountDouble))
        case .weekly:
            target = Target(type: .weekly(amount: amountDouble))
        case .byDate:
            target = Target(type: .byDate(amount: amountDouble, date: targetDate))
        }
        
        budget.setTarget(for: category.id, target: target)
        dismiss()
    }
}

#Preview {
    SetTargetSheet(budget: Budget(dataController: DataController()), category: Category(
        id: UUID(),
        name: "Test",
        emoji: "🎯",
        target: nil,
        allocated: 0,
        spent: 0
    ))
} 
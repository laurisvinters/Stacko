import SwiftUI
import Foundation

struct SetTargetSheet: View {
    @ObservedObject var budget: Budget
    let category: Category
    @Environment(\.dismiss) private var dismiss
    
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
            target = Target(type: .monthly(amount: amountDouble), funded: 0)
        case .weekly:
            target = Target(type: .weekly(amount: amountDouble), funded: 0)
        case .byDate:
            target = Target(type: .byDate(amount: amountDouble, date: targetDate), funded: 0)
        }
        
        if let (groupIndex, categoryIndex) = budget.findCategory(byId: category.id) {
            budget.categoryGroups[groupIndex].categories[categoryIndex].target = target
        }
        
        dismiss()
    }
}

#Preview {
    SetTargetSheet(
        budget: Budget(),
        category: Category(
            id: UUID(),
            name: "Test Category",
            emoji: "🧪",
            target: nil,
            allocated: 100,
            spent: 0
        )
    )
} 
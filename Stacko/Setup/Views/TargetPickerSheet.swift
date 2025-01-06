import SwiftUI

struct TargetPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let currentTarget: Target?
    let onSave: (Target?) -> Void
    
    @State private var targetType: TargetType = .monthly
    @State private var amount = ""
    @State private var targetDate = Date()
    @FocusState private var isAmountFocused: Bool
    
    private enum TargetType: String, CaseIterable {
        case monthly = "Monthly"
        case weekly = "Weekly"
        case byDate = "By Date"
    }
    
    init(currentTarget: Target?, onSave: @escaping (Target?) -> Void) {
        self.currentTarget = currentTarget
        self.onSave = onSave
        
        // Initialize state based on current target
        if let target = currentTarget {
            switch target.type {
            case .monthly(let amount):
                _targetType = State(initialValue: .monthly)
                _amount = State(initialValue: String(amount))
            case .weekly(let amount):
                _targetType = State(initialValue: .weekly)
                _amount = State(initialValue: String(amount))
            case .byDate(let amount, let date):
                _targetType = State(initialValue: .byDate)
                _amount = State(initialValue: String(amount))
                _targetDate = State(initialValue: date)
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Target Type", selection: $targetType) {
                        ForEach(TargetType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    TextField("Target Amount", text: $amount)
                        .keyboardType(.decimalPad)
                        .focused($isAmountFocused)
                    
                    if targetType == .byDate {
                        DatePicker("Target Date", selection: $targetDate, displayedComponents: .date)
                    }
                }
                
                if currentTarget != nil {
                    Section {
                        Button("Remove Target", role: .destructive) {
                            onSave(nil)
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle("Set Target")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveTarget()
                        dismiss()
                    }
                    .disabled(amount.isEmpty || Double(amount) == nil)
                }
                
                ToolbarItem(placement: .keyboard) {
                    Button("Done") {
                        isAmountFocused = false
                    }
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
        
        onSave(target)
    }
}

#Preview {
    TargetPickerSheet(currentTarget: nil) { _ in }
} 
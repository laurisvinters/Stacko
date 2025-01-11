import SwiftUI
import Foundation

struct SetTargetSheet: View {
    @ObservedObject var budget: Budget
    let category: Category
    @Environment(\.dismiss) private var dismiss
    
    @State private var targetType: TargetType = .monthly
    @State private var amount = ""
    @State private var targetDate = Date()
    @State private var intervalType: IntervalType = .days
    @State private var intervalCount = "7"
    @State private var selectedDayOfMonth = 1
    @FocusState private var isAmountFocused: Bool
    
    private enum TargetType: String, CaseIterable {
        case monthly = "Monthly"
        case weekly = "Weekly"
        case byDate = "By Date"
        case custom = "Custom"
        case noDate = "No Date"
    }
    
    private enum IntervalType: String, CaseIterable {
        case days = "Days"
        case months = "Months"
        case years = "Years"
        case monthlyOnDay = "Monthly on Day"
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
                    
                    switch targetType {
                    case .byDate:
                        DatePicker("Target Date", selection: $targetDate, displayedComponents: .date)
                    case .custom:
                        Picker("Interval Type", selection: $intervalType) {
                            ForEach(IntervalType.allCases, id: \.self) { type in
                                Text(type.rawValue).tag(type)
                            }
                        }
                        
                        switch intervalType {
                        case .monthlyOnDay:
                            Stepper("Day of Month: \(selectedDayOfMonth)", value: $selectedDayOfMonth, in: 1...31)
                        default:
                            HStack {
                                Text("Every")
                                TextField("Count", text: $intervalCount)
                                    .keyboardType(.numberPad)
                                Text(intervalType.rawValue.lowercased())
                            }
                        }
                    default:
                        EmptyView()
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
        case .custom:
            let interval: Target.Interval
            switch intervalType {
            case .days:
                guard let count = Int(intervalCount), count > 0 else { return }
                interval = .days(count: count)
            case .months:
                guard let count = Int(intervalCount), count > 0 else { return }
                interval = .months(count: count)
            case .years:
                guard let count = Int(intervalCount), count > 0 else { return }
                interval = .years(count: count)
            case .monthlyOnDay:
                interval = .monthlyOnDay(day: selectedDayOfMonth)
            }
            target = Target(type: .custom(amount: amountDouble, interval: interval))
        case .noDate:
            target = Target(type: .noDate(amount: amountDouble))
        }
        
        budget.setTarget(for: category.id, target: target)
    }
}

#Preview {
    SetTargetSheet(
        budget: Budget(dataController: DataController()),
        category: Category(
            id: UUID(),
            name: "Test",
            emoji: "🎯",
            target: nil,
            allocated: 0,
            spent: 0
        )
    )
} 
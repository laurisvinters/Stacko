import SwiftUI

struct PlannedTransactionsView: View {
    let userId: String
    @StateObject private var manager: PlannedTransactionManager
    @State private var showingAddSheet = false
    @State private var selectedTransaction: PlannedTransaction?
    
    init(userId: String) {
        self.userId = userId
        _manager = StateObject(wrappedValue: PlannedTransactionManager(userId: userId))
    }
    
    var body: some View {
        List {
            Section {
                (Text("Swipe left to ")
                    .foregroundColor(.gray) +
                 Text("delete")
                    .foregroundColor(.blue) +
                 Text(" transactions. Swipe right, then click to ")
                    .foregroundColor(.gray) +
                 Text("edit")
                    .foregroundColor(.blue) +
                 Text(" transactions")
                    .foregroundColor(.gray))
                    .font(.caption)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .listRowBackground(Color.clear)
            }
            .listSectionSpacing(0)
            
            Section {
                ForEach(manager.plannedTransactions) { transaction in
                    PlannedTransactionRow(transaction: transaction)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                Task {
                                    try? await manager.delete(transaction)
                                }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .leading) {
                            Button {
                                selectedTransaction = transaction
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
                }
            }
        }
        .navigationTitle("Planned Transactions")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingAddSheet = true }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            NavigationView {
                PlannedTransactionFormView(userId: userId)
            }
        }
        .sheet(item: $selectedTransaction) { transaction in
            NavigationView {
                PlannedTransactionFormView(userId: userId, transaction: transaction)
            }
        }
    }
}

struct PlannedTransactionRow: View {
    let transaction: PlannedTransaction
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(transaction.title)
                    .font(.headline)
                Spacer()
                Text(transaction.amount, format: .currency(code: "USD"))
                    .foregroundColor(transaction.isIncome ? .green : .primary)
            }
            
            HStack {
                Text(recurrenceText)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Text("Next: \(transaction.nextDueDate.formatted(date: .abbreviated, time: .omitted))")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var recurrenceText: String {
        switch transaction.recurrence {
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        case .custom(let interval, let period):
            return "Every \(interval) \(period.rawValue)s"
        }
    }
}

struct PlannedTransactionFormView: View {
    let userId: String
    var transaction: PlannedTransaction?
    @Environment(\.dismiss) private var dismiss
    @StateObject private var manager: PlannedTransactionManager
    
    @State private var title = ""
    @State private var amount = 0.0
    @State private var isIncome = false
    @State private var note = ""
    @State private var type: PlannedTransactionType = .manual
    @State private var recurrence: RecurrenceType = .monthly
    @State private var nextDueDate = Date()
    @State private var isActive = true
    @State private var selectedPeriod: RecurrenceType.RecurrencePeriod = .month
    @State private var customInterval = 1
    @State private var isCustom = false
    
    init(userId: String, transaction: PlannedTransaction? = nil) {
        self.userId = userId
        self.transaction = transaction
        _manager = StateObject(wrappedValue: PlannedTransactionManager(userId: userId))
        
        if let transaction = transaction {
            _title = State(initialValue: transaction.title)
            _amount = State(initialValue: transaction.amount)
            _isIncome = State(initialValue: transaction.isIncome)
            _note = State(initialValue: transaction.note ?? "")
            _type = State(initialValue: transaction.type)
            _recurrence = State(initialValue: transaction.recurrence)
            _nextDueDate = State(initialValue: transaction.nextDueDate)
            _isActive = State(initialValue: transaction.isActive)
            
            if case .custom(let interval, let period) = transaction.recurrence {
                _customInterval = State(initialValue: interval)
                _selectedPeriod = State(initialValue: period)
                _isCustom = State(initialValue: true)
            }
        }
    }
    
    var body: some View {
        Form {
            Section("Transaction Details") {
                TextField("Title", text: $title)
                TextField("Amount", value: $amount, format: .currency(code: "USD"))
                    .keyboardType(.decimalPad)
                Toggle("Income", isOn: $isIncome)
                TextField("Note", text: $note)
            }
            
            Section("Schedule") {
                Picker("Type", selection: $type) {
                    Text("Manual").tag(PlannedTransactionType.manual)
                    Text("Automatic").tag(PlannedTransactionType.automatic)
                }
                
                Toggle("Custom Recurrence", isOn: $isCustom)
                
                if isCustom {
                    Stepper("Every \(customInterval) \(selectedPeriod.rawValue)\(customInterval == 1 ? "" : "s")", 
                           value: $customInterval, in: 1...365)
                    
                    Picker("Period", selection: $selectedPeriod) {
                        Text("Day").tag(RecurrenceType.RecurrencePeriod.day)
                        Text("Week").tag(RecurrenceType.RecurrencePeriod.week)
                        Text("Month").tag(RecurrenceType.RecurrencePeriod.month)
                        Text("Year").tag(RecurrenceType.RecurrencePeriod.year)
                    }
                } else {
                    Picker("Recurrence", selection: $recurrence) {
                        Text("Daily").tag(RecurrenceType.daily)
                        Text("Weekly").tag(RecurrenceType.weekly)
                        Text("Monthly").tag(RecurrenceType.monthly)
                    }
                }
                
                DatePicker("Next Due Date", selection: $nextDueDate, displayedComponents: .date)
            }
            
            if transaction != nil {
                Section {
                    Toggle("Active", isOn: $isActive)
                }
            }
        }
        .navigationTitle(transaction == nil ? "New Planned Transaction" : "Edit Transaction")
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    save()
                }
            }
        }
    }
    
    private func save() {
        Task {
            let finalRecurrence: RecurrenceType
            if isCustom {
                finalRecurrence = .custom(interval: customInterval, period: selectedPeriod)
            } else {
                finalRecurrence = recurrence
            }
            
            let newTransaction = PlannedTransaction(
                id: transaction?.id ?? UUID(),
                title: title,
                amount: amount,
                categoryId: transaction?.categoryId,
                accountId: transaction?.accountId ?? UUID(), // You'll need to handle this
                note: note.isEmpty ? nil : note,
                isIncome: isIncome,
                type: type,
                recurrence: finalRecurrence,
                nextDueDate: nextDueDate,
                lastProcessedDate: transaction?.lastProcessedDate,
                isActive: isActive
            )
            
            do {
                if transaction != nil {
                    try await manager.update(newTransaction)
                } else {
                    try await manager.add(newTransaction)
                }
                dismiss()
            } catch {
                print("Error saving planned transaction: \(error.localizedDescription)")
            }
        }
    }
}

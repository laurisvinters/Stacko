import SwiftUI
import Charts

struct AccountDetailView: View {
    @ObservedObject var budget: Budget
    let account: Account
    @Environment(\.dismiss) private var dismiss
    @State private var showingReconcile = false
    @State private var showingExport = false
    @State private var timeRange: TimeRange = .month
    @State private var showingDatePicker = false
    @State private var customStartDate = Date()
    @State private var customEndDate = Date()
    @State private var showingAnalytics = true
    @State private var showingDeleteConfirmation = false
    
    enum TimeRange: String, CaseIterable {
        case week = "Week"
        case month = "Month"
        case quarter = "Quarter"
        case year = "Year"
        case all = "All Time"
        case custom = "Custom"
    }
    
    var body: some View {
        List {
            // Balance Section
            balanceSection
            
            // Analytics Toggle
            Section {
                Toggle("Show Analytics", isOn: $showingAnalytics)
            }
            
            if showingAnalytics {
                // Chart Section
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        // Time Range Picker
                        timeRangePicker
                        
                        // Custom Date Range
                        if timeRange == .custom {
                            customDateRangePicker
                        }
                        
                        // Balance Chart
                        balanceChart
                            .frame(height: 200)
                        
                        // Statistics
                        statisticsView
                    }
                } header: {
                    Text("Balance History")
                }
                
                // Income/Expense Breakdown
                Section("Breakdown") {
                    breakdownView
                }
            }
            
            // Transactions Section
            Section("Transactions") {
                ForEach(filteredTransactions) { transaction in
                    TransactionListRow(transaction: transaction)
                }
            }
            
            // Add this section at the bottom
            Section {
                Button(role: .destructive) {
                    showingDeleteConfirmation = true
                } label: {
                    Label("Delete Account", systemImage: "trash")
                }
            }
        }
        .navigationTitle(account.name)
        .toolbar {
            accountToolbar
        }
        .sheet(isPresented: $showingReconcile) {
            ReconcileSheet(budget: budget, account: account)
        }
        .sheet(isPresented: $showingExport) {
            ExportSheet(account: account, transactions: filteredTransactions)
        }
        .alert("Delete Account", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteAccount()
            }
        } message: {
            Text("Are you sure you want to delete this account? This will also delete all associated transactions and cannot be undone.")
        }
    }
    
    // MARK: - View Components
    
    private var balanceSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Balance")
                    Spacer()
                    Text(account.balance, format: .currency(code: "USD"))
                        .foregroundColor(account.balance >= 0 ? .primary : .red)
                }
                
                HStack {
                    Text("Cleared")
                    Spacer()
                    Text(account.clearedBalance, format: .currency(code: "USD"))
                        .foregroundStyle(.secondary)
                }
                
                if let date = account.lastReconciled {
                    HStack {
                        Text("Last Reconciled")
                        Spacer()
                        Text(date, format: .dateTime.month().day().year())
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
    
    private var customDateRangePicker: some View {
        VStack {
            DatePicker("Start Date", selection: $customStartDate, displayedComponents: .date)
            DatePicker("End Date", selection: $customEndDate, displayedComponents: .date)
        }
        #if compiler(>=5.9) // iOS 17 and later
        .onChange(of: customStartDate) { oldValue, newValue in
            // State changes will automatically trigger view updates
        }
        .onChange(of: customEndDate) { oldValue, newValue in
            // State changes will automatically trigger view updates
        }
        #else // iOS 16 and earlier
        .onChange(of: customStartDate) { _ in
            // State changes will automatically trigger view updates
        }
        .onChange(of: customEndDate) { _ in
            // State changes will automatically trigger view updates
        }
        #endif
    }
    
    private var balanceChart: some View {
        Chart {
            ForEach(balanceHistory) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Balance", point.balance)
                )
                .foregroundStyle(.blue)
            }
            
            if let minPoint = minBalance {
                PointMark(
                    x: .value("Date", minPoint.date),
                    y: .value("Min", minPoint.balance)
                )
                .foregroundStyle(.red)
                .symbolSize(100)
            }
            
            if let maxPoint = maxBalance {
                PointMark(
                    x: .value("Date", maxPoint.date),
                    y: .value("Max", maxPoint.balance)
                )
                .foregroundStyle(.green)
                .symbolSize(100)
            }
        }
    }
    
    private var statisticsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Average Balance:")
                Spacer()
                Text(averageBalance, format: .currency(code: "USD"))
            }
            
            HStack {
                Text("Min Balance:")
                Spacer()
                Text(minBalance?.balance ?? 0, format: .currency(code: "USD"))
                    .foregroundColor(.red)
            }
            
            HStack {
                Text("Max Balance:")
                Spacer()
                Text(maxBalance?.balance ?? 0, format: .currency(code: "USD"))
                    .foregroundColor(.green)
            }
        }
        .font(.caption)
    }
    
    private var breakdownView: some View {
        VStack(spacing: 12) {
            // Income vs Expenses Pie Chart
            let income = abs(totalIncome)
            let expenses = abs(totalExpenses)
            let total = income + expenses
            
            if total > 0 {
                Chart {
                    SectorMark(
                        angle: .value("Income", income),
                        innerRadius: .ratio(0.6),
                        angularInset: 1.5
                    )
                    .foregroundStyle(.green)
                    
                    SectorMark(
                        angle: .value("Expenses", expenses),
                        innerRadius: .ratio(0.6),
                        angularInset: 1.5
                    )
                    .foregroundStyle(.red)
                }
                .frame(height: 150)
                
                // Legend
                HStack {
                    HStack {
                        Circle()
                            .fill(.green)
                            .frame(width: 10, height: 10)
                        Text("Income")
                        Text(income, format: .currency(code: "USD"))
                    }
                    
                    Spacer()
                    
                    HStack {
                        Circle()
                            .fill(.red)
                            .frame(width: 10, height: 10)
                        Text("Expenses")
                        Text(expenses, format: .currency(code: "USD"))
                    }
                }
                .font(.caption)
            } else {
                Text("No transactions in selected period")
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private var accountToolbar: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Button {
                    showingReconcile = true
                } label: {
                    Label("Reconcile", systemImage: "checkmark.circle")
                }
                
                Button {
                    showingExport = true
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
    }
    
    // MARK: - Data Calculations
    
    private var filteredTransactions: [Transaction] {
        budget.transactions
            .filter { $0.accountId == account.id || $0.toAccountId == account.id }
            .sorted { $0.date > $1.date }
    }
    
    private var balanceHistory: [BalancePoint] {
        let calendar = Calendar.current
        let now = Date()
        let startDate: Date
        let interval: Calendar.Component
        let steps: Int
        
        switch timeRange {
        case .week:
            startDate = calendar.date(byAdding: .day, value: -7, to: now) ?? now
            interval = .day
            steps = 7
        case .month:
            startDate = calendar.date(byAdding: .month, value: -1, to: now) ?? now
            interval = .day
            steps = 30
        case .quarter:
            startDate = calendar.date(byAdding: .month, value: -3, to: now) ?? now
            interval = .weekOfYear
            steps = 13
        case .year:
            startDate = calendar.date(byAdding: .year, value: -1, to: now) ?? now
            interval = .month
            steps = 12
        case .all:
            startDate = filteredTransactions.last?.date ?? now
            return calculateAllTimeHistory(from: startDate)
        case .custom:
            return calculateCustomRangeHistory()
        }
        
        return calculatePeriodicHistory(from: startDate, interval: interval, steps: steps)
    }
    
    private var movingAverages: [BalancePoint] {
        guard balanceHistory.count >= 7 else { return [] }
        
        var averages: [BalancePoint] = []
        let windowSize = 7
        
        for i in windowSize-1..<balanceHistory.count {
            let window = balanceHistory[i-windowSize+1...i]
            let average = window.reduce(0.0) { $0 + $1.balance } / Double(windowSize)
            averages.append(BalancePoint(date: balanceHistory[i].date, balance: average))
        }
        
        return averages
    }
    
    private var trendLine: (start: BalancePoint, end: BalancePoint)? {
        guard balanceHistory.count >= 2 else { return nil }
        
        let n = Double(balanceHistory.count)
        let timestamps = balanceHistory.map { $0.date.timeIntervalSince1970 }
        let balances = balanceHistory.map(\.balance)
        
        let sumX = timestamps.reduce(0, +)
        let sumY = balances.reduce(0, +)
        let sumXY = zip(timestamps, balances).map(*).reduce(0, +)
        let sumX2 = timestamps.map { $0 * $0 }.reduce(0, +)
        
        let slope = (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX)
        let intercept = (sumY - slope * sumX) / n
        
        let startBalance = slope * timestamps[0] + intercept
        let endBalance = slope * timestamps[timestamps.count - 1] + intercept
        
        return (
            start: BalancePoint(date: balanceHistory[0].date, balance: startBalance),
            end: BalancePoint(date: balanceHistory[balanceHistory.count - 1].date, balance: endBalance)
        )
    }
    
    private var minBalance: BalancePoint? {
        balanceHistory.min { $0.balance < $1.balance }
    }
    
    private var maxBalance: BalancePoint? {
        balanceHistory.max { $0.balance < $1.balance }
    }
    
    private var averageBalance: Double {
        guard !balanceHistory.isEmpty else { return 0 }
        return balanceHistory.reduce(0.0) { $0 + $1.balance } / Double(balanceHistory.count)
    }
    
    private var totalIncome: Double {
        let (start, end) = selectedDateRange
        return filteredTransactions
            .filter { transaction in
                // For credit cards, payments received are "income"
                (transaction.isIncome || transaction.toAccountId == account.id) &&
                transaction.date >= start &&
                transaction.date <= end
            }
            .reduce(0) { sum, transaction in
                if transaction.toAccountId == account.id {
                    return sum + transaction.amount // Credit card payments
                }
                return sum + (transaction.isIncome ? transaction.amount : 0)
            }
    }
    
    private var totalExpenses: Double {
        let (start, end) = selectedDateRange
        return filteredTransactions
            .filter { transaction in
                // For credit cards, charges are "expenses"
                (!transaction.isIncome && transaction.accountId == account.id && transaction.toAccountId == nil) &&
                transaction.date >= start &&
                transaction.date <= end
            }
            .reduce(0) { sum, transaction in
                return sum + transaction.amount
            }
    }
    
    private func calculateCustomRangeHistory() -> [BalancePoint] {
        let calendar = Calendar.current
        let interval: Calendar.Component = .day
        let days = calendar.dateComponents([.day], from: customStartDate, to: customEndDate).day ?? 0
        return calculatePeriodicHistory(from: customStartDate, interval: interval, steps: max(days, 1))
    }
    
    private func calculatePeriodicHistory(from startDate: Date, interval: Calendar.Component, steps: Int) -> [BalancePoint] {
        let calendar = Calendar.current
        var points: [BalancePoint] = []
        var currentDate = startDate
        
        // Get all transactions from start date
        let relevantTransactions = filteredTransactions
            .filter { $0.date >= startDate }
            .sorted { $0.date < $1.date }
        
        // Calculate initial balance (sum of all transactions before start date)
        var runningBalance = filteredTransactions
            .filter { $0.date < startDate }
            .reduce(0.0) { sum, transaction in
                if transaction.accountId == account.id {
                    return sum + (transaction.isIncome ? transaction.amount : -transaction.amount)
                } else if transaction.toAccountId == account.id {
                    return sum + transaction.amount
                }
                return sum
            }
        
        // Add point for each interval
        var transactionIndex = 0
        
        for _ in 0...steps {
            // Add all transactions up to this point
            while transactionIndex < relevantTransactions.count {
                let transaction = relevantTransactions[transactionIndex]
                
                guard calendar.compare(transaction.date, to: currentDate, toGranularity: .day) != .orderedDescending else {
                    break
                }
                
                if transaction.accountId == account.id {
                    runningBalance += transaction.isIncome ? transaction.amount : -transaction.amount
                } else if transaction.toAccountId == account.id {
                    runningBalance += transaction.amount
                }
                
                transactionIndex += 1
            }
            
            points.append(BalancePoint(date: currentDate, balance: runningBalance))
            currentDate = calendar.date(byAdding: interval, value: 1, to: currentDate) ?? currentDate
        }
        
        return points
    }
    
    private func calculateAllTimeHistory(from startDate: Date) -> [BalancePoint] {
        let calendar = Calendar.current
        var points: [BalancePoint] = []
        var runningBalance = 0.0
        
        // Group transactions by month
        let groupedTransactions = Dictionary(grouping: filteredTransactions) { transaction in
            calendar.startOfMonth(for: transaction.date)
        }
        
        // Sort months and create points
        let sortedMonths = groupedTransactions.keys.sorted()
        
        for month in sortedMonths {
            let monthTransactions = groupedTransactions[month]?.sorted { $0.date < $1.date } ?? []
            
            for transaction in monthTransactions {
                if transaction.accountId == account.id {
                    runningBalance += transaction.isIncome ? transaction.amount : -transaction.amount
                } else if transaction.toAccountId == account.id {
                    runningBalance += transaction.amount
                }
            }
            
            points.append(BalancePoint(date: month, balance: runningBalance))
        }
        
        return points
    }
    
    private var selectedDateRange: (start: Date, end: Date) {
        let calendar = Calendar.current
        let now = Date()
        
        switch timeRange {
        case .week:
            let start = calendar.date(byAdding: .day, value: -7, to: now) ?? now
            return (start, now)
        case .month:
            let start = calendar.date(byAdding: .month, value: -1, to: now) ?? now
            return (start, now)
        case .quarter:
            let start = calendar.date(byAdding: .month, value: -3, to: now) ?? now
            return (start, now)
        case .year:
            let start = calendar.date(byAdding: .year, value: -1, to: now) ?? now
            return (start, now)
        case .all:
            let start = filteredTransactions.last?.date ?? now
            return (start, now)
        case .custom:
            return (customStartDate, customEndDate)
        }
    }
    
    private var timeRangePicker: some View {
        VStack(spacing: 8) {
            // Standard ranges
            Picker("", selection: $timeRange) {
                ForEach([TimeRange.week, .month, .quarter, .year], id: \.self) { range in
                    Text(range.rawValue).tag(range)
                }
            }
            .pickerStyle(.segmented)
            
            // Custom and All Time
            Picker("", selection: $timeRange) {
                ForEach([TimeRange.custom, .all], id: \.self) { range in
                    Text(range.rawValue).tag(range)
                }
            }
            .pickerStyle(.segmented)
        }
    }
    
    private func deleteAccount() {
        budget.deleteAccount(account.id)
        dismiss()
    }
}

struct BalancePoint: Identifiable {
    let id = UUID()
    let date: Date
    let balance: Double
} 
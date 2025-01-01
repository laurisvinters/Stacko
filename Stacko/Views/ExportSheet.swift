import SwiftUI
import UniformTypeIdentifiers

struct ExportSheet: View {
    let account: Account
    let transactions: [Transaction]
    @Environment(\.dismiss) private var dismiss
    
    @State private var exportFormat: ExportFormat = .csv
    @State private var dateRange: DateRange = .all
    @State private var showingShare = false
    @State private var exportedData: Data?
    
    enum ExportFormat: String, CaseIterable {
        case csv = "CSV"
        case json = "JSON"
    }
    
    enum DateRange: String, CaseIterable {
        case month = "This Month"
        case year = "This Year"
        case all = "All Time"
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Picker("Format", selection: $exportFormat) {
                    ForEach(ExportFormat.allCases, id: \.self) { format in
                        Text(format.rawValue).tag(format)
                    }
                }
                
                Picker("Date Range", selection: $dateRange) {
                    ForEach(DateRange.allCases, id: \.self) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
                
                Button("Export") {
                    exportData()
                }
            }
            .navigationTitle("Export Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showingShare) {
                if let data = exportedData {
                    ShareSheet(items: [data])
                }
            }
        }
    }
    
    private func exportData() {
        let filteredTransactions = filterTransactions()
        
        switch exportFormat {
        case .csv:
            exportedData = generateCSV(transactions: filteredTransactions)
        case .json:
            exportedData = generateJSON(transactions: filteredTransactions)
        }
        
        if exportedData != nil {
            showingShare = true
        }
    }
    
    private func filterTransactions() -> [Transaction] {
        let calendar = Calendar.current
        let now = Date()
        
        return transactions.filter { transaction in
            switch dateRange {
            case .month:
                return calendar.isDate(transaction.date, equalTo: now, toGranularity: .month)
            case .year:
                return calendar.isDate(transaction.date, equalTo: now, toGranularity: .year)
            case .all:
                return true
            }
        }
    }
    
    private func generateCSV(transactions: [Transaction]) -> Data {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        
        var csv = "Date,Payee,Amount,Category,Type,Note\n"
        
        for transaction in transactions {
            let fields = [
                dateFormatter.string(from: transaction.date),
                escapeCsvField(transaction.payee),
                String(format: "%.2f", transaction.amount),
                transaction.categoryId.uuidString,
                transaction.isIncome ? "Income" : "Expense",
                transaction.note.map(escapeCsvField) ?? ""
            ]
            csv += fields.joined(separator: ",") + "\n"
        }
        
        return csv.data(using: .utf8) ?? Data()
    }
    
    private func escapeCsvField(_ field: String) -> String {
        if field.contains(",") || field.contains("\"") || field.contains("\n") {
            return "\"\(field.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return field
    }
    
    private func generateJSON(transactions: [Transaction]) -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        
        do {
            return try encoder.encode(transactions)
        } catch {
            print("Error encoding transactions: \(error)")
            return Data()
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
} 
import SwiftUI

struct ReportsView: View {
    @ObservedObject var budget: Budget
    
    var body: some View {
        NavigationStack {
            Text("Reports coming soon!")
                .navigationTitle("Reports")
        }
    }
} 
import SwiftUI

struct SetupCategoriesView: View {
    @ObservedObject var coordinator: SetupCoordinator
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Button(action: {
                    print("Back button tapped")
                    coordinator.moveToPreviousGroup()
                }) {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                }
                Spacer()
            }
            .padding()
            
            // Your existing categories content here
        }
        .navigationBarTitle("Setup Categories", displayMode: .inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    coordinator.moveToPreviousGroup()
                }) {
                    HStack {
                        Image(systemName: "chevron.left")
                    }
                }
            }
        }
    }
}

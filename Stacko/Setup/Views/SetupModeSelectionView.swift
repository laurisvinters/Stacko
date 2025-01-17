import SwiftUI

struct SetupModeSelectionView: View {
    @ObservedObject var coordinator: SetupCoordinator
    @ObservedObject var authManager: AuthenticationManager
    
    var body: some View {
        VStack(spacing: 24) {
            Text("How would you like to set up your budget?")
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            VStack(spacing: 16) {
                setupModeButton(
                    title: "Recommended",
                    subtitle: "Complete setup with personalized categories and targets",
                    color: .blue
                ) {
                    coordinator.setSetupMode(.recommended)
                }
                
                setupModeButton(
                    title: "Fast",
                    subtitle: "Quick setup with basic features",
                    color: .green
                ) {
                    coordinator.setSetupMode(.fast)
                }
                
                setupModeButton(
                    title: "Back",
                    subtitle: "Return to sign in",
                    color: .red
                ) {
                    authManager.signOut()
                }
            }
            .padding(.horizontal)
        }
        .navigationBarBackButtonHidden()
    }
    
    private func setupModeButton(
        title: String,
        subtitle: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                    
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(radius: 2)
        }
        .buttonStyle(.plain)
    }
}

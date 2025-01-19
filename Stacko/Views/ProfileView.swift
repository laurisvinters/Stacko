import SwiftUI
import FirebaseAuth

struct ProfileView: View {
    @ObservedObject var authManager: AuthenticationManager
    @State private var showingDeleteConfirmation = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var isLoading = false
    
    var body: some View {
        Form {
            Section {
                if let user = authManager.currentUser {
                    LabeledContent("Name", value: user.name)
                    LabeledContent("Email", value: user.email)
                }
            }
            
            Section {
                Button(role: .destructive) {
                    showingDeleteConfirmation = true
                } label: {
                    HStack {
                        Text("Delete Account")
                        Spacer()
                        Image(systemName: "trash")
                    }
                }
                
                Button(role: .destructive) {
                    signOut()
                } label: {
                    HStack {
                        Text("Sign Out")
                        Spacer()
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
        }
        .navigationTitle("Profile")
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .alert("Delete Account", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteAccount()
            }
        } message: {
            Text("Are you sure you want to delete your account? This action cannot be undone.")
        }
        .disabled(isLoading)
    }
    
    private func signOut() {
        do {
            try authManager.signOut()
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
    
    private func deleteAccount() {
        isLoading = true
        
        Task {
            do {
                // Delete the user from Firebase
                if let user = Auth.auth().currentUser {
                    try await user.delete()
                }
            } catch {
                errorMessage = error.localizedDescription
                showingError = true
            }
            isLoading = false
        }
    }
} 
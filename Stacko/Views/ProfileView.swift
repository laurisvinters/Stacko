import SwiftUI
import FirebaseAuth

struct ProfileView: View {
    @ObservedObject var authManager: AuthenticationManager
    @State private var showingDeleteConfirmation = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var isLoading = false
    @State private var password = ""
    
    var body: some View {
        Form {
            Section {
                if let user = authManager.currentUser {
                    LabeledContent("Name", value: user.name)
                    LabeledContent("Email", value: user.email)
                }
            }
            
            if authManager.isGuest {
                Section {
                    NavigationLink {
                        ConvertGuestAccountView(authManager: authManager)
                    } label: {
                        HStack {
                            Text("Create Full Account")
                            Spacer()
                            Image(systemName: "person.badge.plus")
                        }
                    }
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
        .disabled(isLoading)
        .alert("Delete Account", isPresented: $showingDeleteConfirmation) {
            SecureField("Enter Password", text: $password)
            Button("Cancel", role: .cancel) { 
                password = ""
            }
            Button("Delete", role: .destructive) {
                deleteAccount()
            }
        } message: {
            Text("Enter your password to confirm account deletion. This action cannot be undone.")
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func signOut() {
        Task {
            do {
                try await authManager.signOut()
            } catch {
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
    }
    
    private func deleteAccount() {
        guard !password.isEmpty else {
            errorMessage = "Please enter your password"
            showingError = true
            return
        }
        
        isLoading = true
        
        Task {
            do {
                try await authManager.deleteAccount(password: password)
            } catch {
                errorMessage = error.localizedDescription
                showingError = true
            }
            isLoading = false
            password = "" // Clear password field
        }
    }
} 
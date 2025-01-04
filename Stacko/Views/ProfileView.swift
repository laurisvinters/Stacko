import SwiftUI

struct ProfileView: View {
    @ObservedObject var authManager: AuthenticationManager
    @State private var showingDeleteConfirmation = false
    
    var body: some View {
        List {
            if let user = authManager.currentUser {
                Section {
                    HStack {
                        Text(String(user.name.prefix(1)))
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(width: 50, height: 50)
                            .background(Circle().fill(.blue))
                        
                        VStack(alignment: .leading) {
                            Text(user.name)
                                .font(.headline)
                            Text(user.email)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                if authManager.isGuestUser {
                    Section {
                        NavigationLink {
                            ConvertGuestAccountView(authManager: authManager)
                        } label: {
                            Label("Convert to Full Account", systemImage: "person.badge.plus")
                                .foregroundColor(.blue)
                        }
                    } footer: {
                        Text("Convert to a full account to save your data permanently.")
                            .foregroundStyle(.secondary)
                    }
                }
                
                Section {
                    Button(role: .destructive) {
                        authManager.signOut()
                    } label: {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
                
                if !authManager.isGuestUser {
                    Section {
                        Button(role: .destructive) {
                            showingDeleteConfirmation = true
                        } label: {
                            Label("Delete Account", systemImage: "trash")
                        }
                    } footer: {
                        Text("Deleting your account will permanently remove all your data including accounts, transactions, and categories.")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Profile")
        .alert("Delete Account", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                authManager.deleteAccount()
            }
        } message: {
            Text("Are you sure you want to delete your account? This action cannot be undone.")
        }
    }
} 
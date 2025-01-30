import SwiftUI
import FirebaseAuth

struct ProfileView: View {
    @ObservedObject var authManager: AuthenticationManager
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var showingDeleteConfirmation = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var isLoading = false
    @State private var password = ""
    @State private var showingResetConfirmation = false
    @State private var showingResetPasswordPrompt = false
    @State private var currentPassword = ""
    
    var body: some View {
        Form {
            Section {
                if let user = authManager.currentUser {
                    LabeledContent("Name", value: user.name)
                    LabeledContent("Email", value: user.email)
                }
            }
            
            Section("Appearance") {
                Button {
                    themeManager.toggleTheme()
                } label: {
                    HStack {
                        Text(themeManager.isDarkMode ? "Dark Mode" : "Light Mode")
                        Spacer()
                        Image(systemName: themeManager.isDarkMode ? "moon.fill" : "sun.max.fill")
                            .foregroundStyle(themeManager.isDarkMode ? .blue : .yellow)
                    }
                }
            }
            
            if !authManager.isGuest {
                Section {
                    Button {
                        currentPassword = ""  // Clear any previous password
                        showingResetPasswordPrompt = true
                    } label: {
                        HStack {
                            Text("Reset Password")
                            Spacer()
                            Image(systemName: "key")
                        }
                    }
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
        .preferredColorScheme(themeManager.colorScheme)
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
        .alert("Password Reset", isPresented: $showingResetConfirmation) {
            Button("OK") { }
        } message: {
            Text("A password reset link has been sent to your email address.")
        }
        .alert("Reset Password", isPresented: $showingResetPasswordPrompt) {
            SecureField("Current Password", text: $currentPassword)
            Button("Cancel", role: .cancel) {
                currentPassword = ""
            }
            Button("Send Reset Link") {
                resetPassword()
            }
        } message: {
            Text("Enter your current password to receive a password reset link.")
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink {
                    ProfileView(authManager: authManager)
                } label: {
                    Label("Profile", systemImage: "person.circle")
                }
            }
        }
    }
    
    private func resetPassword() {
        guard let email = authManager.currentUser?.email else { return }
        guard !currentPassword.isEmpty else {
            errorMessage = "Please enter your current password"
            showingError = true
            return
        }
        
        isLoading = true
        
        Task {
            do {
                // First verify the current password
                let credential = EmailAuthProvider.credential(withEmail: email, password: currentPassword)
                try await Auth.auth().currentUser?.reauthenticate(with: credential)
                
                // If verification succeeds, send the reset email
                try await authManager.resetPassword(email: email)
                currentPassword = "" // Clear the password field
                showingResetConfirmation = true
                print("Password reset email sent successfully to: \(email)")
            } catch {
                print("Error in password reset process: \(error)")
                if let error = error as NSError?,
                   error.domain == AuthErrorDomain {
                    switch error.code {
                    case AuthErrorCode.wrongPassword.rawValue:
                        errorMessage = "The password you entered is incorrect"
                    case AuthErrorCode.userNotFound.rawValue:
                        errorMessage = "No account found with this email address"
                    case AuthErrorCode.invalidEmail.rawValue:
                        errorMessage = "Please enter a valid email address"
                    case AuthErrorCode.invalidCredential.rawValue:
                        errorMessage = "The password you entered is incorrect"
                    default:
                        errorMessage = "Error: \(error.localizedDescription)"
                    }
                } else {
                    errorMessage = "Error: \(error.localizedDescription)"
                }
                showingError = true
            }
            isLoading = false
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
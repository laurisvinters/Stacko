import SwiftUI
import FirebaseAuth

struct SignInView: View {
    @ObservedObject var authManager: AuthenticationManager
    @State private var email = ""
    @State private var password = ""
    @State private var showingSignUp = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var isLoading = false
    @State private var showingResetPassword = false
    @State private var resetEmail = ""
    @State private var showingResetConfirmation = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .autocapitalization(.none)
                    
                    SecureField("Password", text: $password)
                        .textContentType(.password)
                }
                
                Section {
                    Button(action: signIn) {
                        if isLoading {
                            ProgressView()
                        } else {
                            Text("Sign In")
                        }
                    }
                    .disabled(isLoading || !isValid)
                    
                    Button("Forgot Password?") {
                        resetEmail = email.isEmpty ? "" : email
                        showingResetPassword = true
                    }
                }
                
                Section {
                    Button("Create Account") {
                        showingSignUp = true
                    }
                    
                    Button("Continue as Guest") {
                        signInAsGuest()
                    }
                }
            }
            .navigationTitle("Sign In")
            .disabled(isLoading)
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
            .sheet(isPresented: $showingSignUp) {
                SignUpView(authManager: authManager)
            }
            .alert("Reset Password", isPresented: $showingResetPassword) {
                TextField("Email", text: $resetEmail)
                    .textContentType(.emailAddress)
                    .autocapitalization(.none)
                Button("Cancel", role: .cancel) { }
                Button("Reset") {
                    resetPassword()
                }
            } message: {
                Text("Enter your email address and we'll send you a link to reset your password.")
            }
            .alert("Password Reset", isPresented: $showingResetConfirmation) {
                Button("OK") { }
            } message: {
                Text("If an account exists with this email, you will receive a password reset link shortly.")
            }
        }
    }
    
    private var isValid: Bool {
        !email.isEmpty && !password.isEmpty
    }
    
    private func signIn() {
        isLoading = true
        
        Task {
            do {
                try await authManager.signIn(email: email, password: password)
            } catch {
                errorMessage = error.localizedDescription
                showingError = true
            }
            isLoading = false
        }
    }
    
    private func signInAsGuest() {
        isLoading = true
        
        Task {
            do {
                try await authManager.signInAsGuest()
            } catch {
                errorMessage = error.localizedDescription
                showingError = true
            }
            isLoading = false
        }
    }
    
    private func resetPassword() {
        isLoading = true
        
        Task {
            do {
                try await authManager.resetPassword(email: resetEmail)
                showingResetConfirmation = true
                print("Password reset email sent successfully to: \(resetEmail)")
            } catch {
                print("Error sending password reset: \(error)")
                if let error = error as NSError? {
                    if error.domain == AuthErrorDomain {
                        switch error.code {
                        case AuthErrorCode.userNotFound.rawValue:
                            errorMessage = "No account found with this email address"
                        case AuthErrorCode.invalidEmail.rawValue:
                            errorMessage = "Please enter a valid email address"
                        case AuthErrorCode.invalidRecipientEmail.rawValue:
                            errorMessage = "The email address is invalid"
                        default:
                            errorMessage = "Error: \(error.localizedDescription)"
                        }
                    } else {
                        errorMessage = "Error: \(error.localizedDescription)"
                    }
                } else {
                    errorMessage = "An unknown error occurred"
                }
                showingError = true
            }
            isLoading = false
        }
    }
} 
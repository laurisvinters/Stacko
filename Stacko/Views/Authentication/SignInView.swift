import SwiftUI

struct SignInView: View {
    @ObservedObject var authManager: AuthenticationManager
    @State private var email = ""
    @State private var password = ""
    @State private var showingSignUp = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var isLoading = false
    
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
} 
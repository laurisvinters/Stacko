import SwiftUI

struct SignInView: View {
    @ObservedObject var authManager: AuthenticationManager
    @State private var email = ""
    @State private var password = ""
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showingSignUp = false
    
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
                    Button("Sign In") {
                        signIn()
                    }
                    .disabled(!isValid)
                    
                    Button("Create Account") {
                        showingSignUp = true
                    }
                }
            }
            .navigationTitle("Sign In")
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
        do {
            try authManager.signIn(email: email, password: password)
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
} 
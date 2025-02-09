import SwiftUI

struct ConvertGuestAccountView: View {
    @ObservedObject var authManager: AuthenticationManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var name = ""
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var isLoading = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                        .textContentType(.name)
                    
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .autocapitalization(.none)
                    
                    SecureField("Password", text: $password)
                        .textContentType(.newPassword)
                    
                    SecureField("Confirm Password", text: $confirmPassword)
                        .textContentType(.newPassword)
                }
                
                Section {
                    Text("Converting to a full account will preserve all your existing data.")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Create Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Convert") { convertAccount() }
                        .disabled(!isValid || isLoading)
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
            .disabled(isLoading)
        }
    }
    
    private var isValid: Bool {
        !email.isEmpty && 
        !password.isEmpty && 
        !name.isEmpty && 
        password == confirmPassword &&
        password.count >= 8
    }
    
    private func convertAccount() {
        isLoading = true
        
        Task {
            do {
                try await authManager.convertGuestAccount(email: email, password: password, name: name)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                showingError = true
            }
            isLoading = false
        }
    }
} 
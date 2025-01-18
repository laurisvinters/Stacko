import SwiftUI
import FirebaseAuth

@MainActor
class AuthenticationManager: ObservableObject {
    @Published var currentUser: User?
    
    private let budget: Budget
    private let setupCoordinator: SetupCoordinator
    
    init(budget: Budget, setupCoordinator: SetupCoordinator) {
        self.budget = budget
        self.setupCoordinator = setupCoordinator
        
        // Setup Firebase auth state listener
        Auth.auth().addStateDidChangeListener { [weak self] _, firebaseUser in
            if let firebaseUser = firebaseUser {
                self?.handleFirebaseUser(firebaseUser)
            } else {
                self?.currentUser = nil
            }
        }
    }
    
    private func handleFirebaseUser(_ firebaseUser: FirebaseAuth.User) {
        // Convert Firebase user to our User model
        currentUser = User(
            id: UUID(uuidString: firebaseUser.uid) ?? UUID(),
            email: firebaseUser.email ?? "",
            name: firebaseUser.displayName ?? "",
            createdAt: firebaseUser.metadata.creationDate ?? Date(),
            lastLoginAt: firebaseUser.metadata.lastSignInDate ?? Date()
        )
    }
    
    func signIn(email: String, password: String) async throws {
        try await Auth.auth().signIn(withEmail: email, password: password)
    }
    
    func signUp(email: String, password: String, name: String) async throws {
        // Create the user in Firebase
        let result = try await Auth.auth().createUser(withEmail: email, password: password)
        
        // Update display name
        let changeRequest = result.user.createProfileChangeRequest()
        changeRequest.displayName = name
        try await changeRequest.commitChanges()
        
        // Update local state
        handleFirebaseUser(result.user)
    }
    
    func signOut() throws {
        try Auth.auth().signOut()
        currentUser = nil
    }
} 
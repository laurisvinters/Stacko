import SwiftUI
import FirebaseAuth
import FirebaseFirestore

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
                self?.budget.setupListeners()
            } else {
                self?.currentUser = nil
                self?.budget.reset()
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
        // Create the user in Firebase Auth
        let result = try await Auth.auth().createUser(withEmail: email, password: password)
        
        // Update display name
        let changeRequest = result.user.createProfileChangeRequest()
        changeRequest.displayName = name
        try await changeRequest.commitChanges()
        
        // Create initial user document in Firestore
        let db = Firestore.firestore()
        try await db.collection("users").document(result.user.uid)
            .setData([
                "isSetupComplete": false,
                "email": email,
                "name": name,
                "createdAt": Date()
            ])
        
        // Update local state
        handleFirebaseUser(result.user)
    }
    
    func signOut() throws {
        try Auth.auth().signOut()
        currentUser = nil
        budget.reset()
        setupCoordinator.isSetupComplete = false
    }
} 
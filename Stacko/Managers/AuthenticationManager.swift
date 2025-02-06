import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import CoreData

@MainActor
class AuthenticationManager: ObservableObject {
    @Published private(set) var currentUser: User?
    
    @Published private(set) var isGuest = false
    private let db = Firestore.firestore()
    private let budget: Budget
    private let setupCoordinator: SetupCoordinator
    
    // Public accessor for budget
    var userBudget: Budget { budget }
    
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
                self?.setupCoordinator.isSetupComplete = false
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
    
    func signOut() async throws {
        if isGuest {
            // Delete guest data before signing out
            if let userId = Auth.auth().currentUser?.uid {
                try await deleteUserData(userId: userId)
            }
        }
        
        try Auth.auth().signOut()
        currentUser = nil
        budget.reset()
        setupCoordinator.reset()
        UserDefaults.standard.removeObject(forKey: "isSetupComplete")
        self.isGuest = false
    }
    
    func signInAsGuest() async throws {
        // Sign in anonymously with Firebase
        let result = try await Auth.auth().signInAnonymously()
        
        // Create initial user document in Firestore
        let db = Firestore.firestore()
        try await db.collection("users").document(result.user.uid)
            .setData([
                "isSetupComplete": false,
                "email": "",
                "name": "Guest",
                "createdAt": Date(),
                "isGuest": true
            ])
        
        // Update local state
        handleFirebaseUser(result.user)
        self.isGuest = true
        setupCoordinator.isSetupComplete = false
        UserDefaults.standard.removeObject(forKey: "isSetupComplete")
    }
    
    func deleteUserData(userId: String) async throws {
        // Delete Firestore data
        let db = Firestore.firestore()
        let batch = db.batch()
        
        // Delete all collections for the user
        let collections = ["accounts", "categoryGroups", "transactions", "templates"]
        
        for collection in collections {
            let snapshot = try await db.collection("users").document(userId).collection(collection).getDocuments()
            for document in snapshot.documents {
                batch.deleteDocument(document.reference)
            }
        }
        
        // Delete the user document itself
        batch.deleteDocument(db.collection("users").document(userId))
        
        // Commit the batch
        try await batch.commit()
        
        // Reset local state
        budget.reset()
        setupCoordinator.isSetupComplete = false
        
        // Clear Core Data
        let container = NSPersistentContainer(name: "StackoModel")
        container.loadPersistentStores { _, error in
            if let error = error {
                print("Error loading store: \(error)")
            }
        }
        let context = container.viewContext
        
        // Delete all entities
        let entities = ["CDUser", "CDAccount", "CDCategory", "CDCategoryGroup", "CDTransaction", "CDTemplate"]
        
        for entity in entities {
            let fetchRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: entity)
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            
            try context.execute(deleteRequest)
        }
        
        try context.save()
    }
    
    func deleteAccount(password: String) async throws {
        guard let user = Auth.auth().currentUser,
              let email = user.email else { return }
        
        do {
            // Re-authenticate user with password
            let credential = EmailAuthProvider.credential(withEmail: email, password: password)
            try await user.reauthenticate(with: credential)
            
            // Delete user data first
            try await deleteUserData(userId: user.uid)
            
            // Then delete the user account
            try await user.delete()
        } catch {
            // Convert Firebase auth errors to user-friendly messages
            if let error = error as? NSError,
               error.domain == AuthErrorDomain {
                switch error.code {
                case AuthErrorCode.wrongPassword.rawValue,
                     AuthErrorCode.invalidCredential.rawValue:
                    throw NSError(
                        domain: "AuthenticationManager",
                        code: error.code,
                        userInfo: [NSLocalizedDescriptionKey: "The password you entered is incorrect"]
                    )
                default:
                    throw error
                }
            } else {
                throw error
            }
        }
    }
    
    func resetPassword(email: String) async throws {
        try await Auth.auth().sendPasswordReset(withEmail: email)
    }
    
    func convertGuestAccount(email: String, password: String, name: String) async throws {
        guard let currentUser = Auth.auth().currentUser, currentUser.isAnonymous else {
            throw NSError(domain: "AuthenticationManager", code: -1, 
                userInfo: [NSLocalizedDescriptionKey: "No guest account to convert"])
        }
        
        // Create EmailAuthProvider credential
        let credential = EmailAuthProvider.credential(withEmail: email, password: password)
        
        // Link the anonymous account with the email credential
        try await currentUser.link(with: credential)
        
        // Update display name
        let changeRequest = currentUser.createProfileChangeRequest()
        changeRequest.displayName = name
        try await changeRequest.commitChanges()
        
        // Update the user document in Firestore
        try await db.collection("users").document(currentUser.uid)
            .updateData([
                "email": email,
                "name": name,
                "isGuest": false
            ])
        
        // Update local state
        self.isGuest = false
        handleFirebaseUser(currentUser)
    }
} 
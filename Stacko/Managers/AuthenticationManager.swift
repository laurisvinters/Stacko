import Foundation
import CoreData
import FirebaseAuth
import FirebaseFirestore

class AuthenticationManager: ObservableObject {
    @Published private(set) var currentUser: User?
    private let dataController: DataController
    private let budget: Budget
    private let setupCoordinator: SetupCoordinator
    private let db = Firestore.firestore()
    private var authStateHandle: AuthStateDidChangeListenerHandle?
    
    init(dataController: DataController, budget: Budget, setupCoordinator: SetupCoordinator) {
        self.dataController = dataController
        self.budget = budget
        self.setupCoordinator = setupCoordinator
        
        // Listen for Firebase Auth state changes
        let handle = Auth.auth().addStateDidChangeListener { [weak self] (_, firebaseUser) in
            if let firebaseUser = firebaseUser {
                self?.fetchUserData(for: firebaseUser)
            } else {
                self?.currentUser = nil
            }
        }
        // Store the handle if you need to remove the listener later
        self.authStateHandle = handle
    }
    
    private func fetchUserData(for firebaseUser: FirebaseAuth.User) {
        let maxRetries = 3
        var retryCount = 0
        
        func attemptFetch() {
            db.collection("users").document(firebaseUser.uid).getDocument { [weak self] (document, error) in
                if let error = error {
                    retryCount += 1
                    if retryCount < maxRetries {
                        // Exponential backoff: 2^retryCount seconds
                        DispatchQueue.main.asyncAfter(deadline: .now() + Double(pow(2, Double(retryCount)))) {
                            attemptFetch()
                        }
                        return
                    }
                    print("Failed to fetch user data after \(maxRetries) attempts: \(error)")
                    return
                }
                
                if let document = document, document.exists {
                    let data = document.data() ?? [:]
                    let user = User(
                        id: UUID(uuidString: firebaseUser.uid) ?? UUID(),
                        email: firebaseUser.email ?? "",
                        name: data["name"] as? String ?? "",
                        createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
                        lastLoginAt: (data["lastLoginAt"] as? Timestamp)?.dateValue() ?? Date()
                    )
                    DispatchQueue.main.async {
                        self?.currentUser = user
                        // Create or update Core Data user
                        if let cdUser = self?.dataController.getCurrentUser() {
                            cdUser.email = user.email
                        } else {
                            _ = self?.dataController.createUser(id: user.id, email: user.email)
                        }
                        self?.dataController.save()
                        
                        // Check setup status from Firestore
                        if data["hasCompletedSetup"] as? Bool == true {
                            self?.setupCoordinator.markSetupComplete()
                        }
                        
                        // Sync categories from Firestore
                        self?.dataController.syncCategoriesFromFirestore()
                        
                        // Reload data after user is set and categories are synced
                        self?.budget.reload()
                    }
                }
            }
        }
        
        attemptFetch()
    }
    
    func completeSetup() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        // Update Firestore to mark setup as complete
        db.collection("users").document(userId).updateData([
            "hasCompletedSetup": true
        ]) { error in
            if let error = error {
                print("Error marking setup as complete: \(error)")
            }
        }
        
        setupCoordinator.markSetupComplete()
    }
    
    func signUp(email: String, password: String, name: String) async throws {
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            let user = result.user
            
            // Create user document in Firestore with setup status
            let userData: [String: Any] = [
                "email": email,
                "name": name,
                "createdAt": Timestamp(date: Date()),
                "lastLoginAt": Timestamp(date: Date()),
                "hasCompletedSetup": false
            ]
            
            try await db.collection("users").document(user.uid).setData(userData)
            
            // Fetch updated user data
            fetchUserData(for: user)
            
        } catch {
            print("Failed to create user: \(error)")
            throw error
        }
    }
    
    func signIn(email: String, password: String) async throws {
        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            
            // First check if user document exists
            let userDoc = db.collection("users").document(result.user.uid)
            let docSnapshot = try await userDoc.getDocument()
            
            if !docSnapshot.exists {
                // Create user document if it doesn't exist
                let userData: [String: Any] = [
                    "email": email,
                    "name": email.components(separatedBy: "@").first ?? "User",
                    "createdAt": Timestamp(date: Date()),
                    "lastLoginAt": Timestamp(date: Date()),
                    "hasCompletedSetup": false
                ]
                
                try await userDoc.setData(userData)
            } else {
                // Retry updating last login with exponential backoff
                var retryCount = 0
                let maxRetries = 3
                
                while retryCount < maxRetries {
                    do {
                        try await userDoc.updateData([
                            "lastLoginAt": Timestamp(date: Date())
                        ])
                        break
                    } catch {
                        retryCount += 1
                        if retryCount == maxRetries {
                            print("Failed to update last login after \(maxRetries) attempts: \(error)")
                            break
                        }
                        // Exponential backoff: 2^retryCount seconds
                        try await Task.sleep(nanoseconds: UInt64(pow(2, Double(retryCount)) * 1_000_000_000))
                    }
                }
            }
            
            // Fetch updated user data
            fetchUserData(for: result.user)
            
        } catch {
            print("Sign in failed: \(error)")
            throw AuthError.invalidCredentials
        }
    }
    
    func signOut() {
        do {
            // Clear local data before signing out
            dataController.clearUserData()
            try Auth.auth().signOut()
            currentUser = nil
            dataController.clearCache()
            budget.reload()
            // Reset setup coordinator only on sign out
            setupCoordinator.reset()
        } catch {
            print("Error signing out: \(error)")
        }
    }
    
    func deleteAccount() async throws {
        guard let user = Auth.auth().currentUser else { return }
        
        do {
            // Delete user data from Firestore
            try await db.collection("users").document(user.uid).delete()
            
            // Delete all subcollections
            let collections = ["categoryGroups", "categories"]
            for collection in collections {
                let snapshot = try await db.collection("users").document(user.uid)
                    .collection(collection).getDocuments()
                
                for document in snapshot.documents {
                    try await document.reference.delete()
                }
            }
            
            // Clear local data
            dataController.clearUserData()
            
            // Delete Firebase user
            try await user.delete()
            
            signOut()
        } catch {
            print("Failed to delete account: \(error)")
            throw error
        }
    }
    
    func continueAsGuest() {
        Task {
            do {
                let result = try await Auth.auth().signInAnonymously()
                // Create a guest user in Core Data
                let guestId = UUID(uuidString: result.user.uid) ?? UUID()
                _ = dataController.createUser(id: guestId, email: "guest")
                dataController.save()
                // Don't reset setup for guest users
                budget.reload()
            } catch {
                print("Failed to sign in anonymously: \(error)")
            }
        }
    }
    
    var isGuestUser: Bool {
        Auth.auth().currentUser?.isAnonymous ?? false
    }
    
    func convertGuestToFullAccount(email: String, password: String, name: String) async throws {
        guard let currentFirebaseUser = Auth.auth().currentUser,
              currentFirebaseUser.isAnonymous else {
            throw AuthError.notGuestUser
        }
        
        do {
            // Create email credential
            let credential = EmailAuthProvider.credential(withEmail: email, password: password)
            
            // Link anonymous account with email credential
            let result = try await currentFirebaseUser.link(with: credential)
            
            // Update user profile
            let userData: [String: Any] = [
                "email": email,
                "name": name,
                "createdAt": Timestamp(date: Date()),
                "lastLoginAt": Timestamp(date: Date())
            ]
            
            try await db.collection("users").document(result.user.uid).setData(userData)
            
            // Fetch updated user data
            fetchUserData(for: result.user)
            
        } catch {
            print("Failed to convert guest account: \(error)")
            throw error
        }
    }
    
    enum AuthError: LocalizedError {
        case emailAlreadyExists
        case invalidCredentials
        case notGuestUser
        
        var errorDescription: String? {
            switch self {
            case .emailAlreadyExists:
                return "An account with this email already exists"
            case .invalidCredentials:
                return "Invalid email or password"
            case .notGuestUser:
                return "This operation is only available for guest accounts"
            }
        }
    }
} 
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
    
    init(dataController: DataController, budget: Budget, setupCoordinator: SetupCoordinator) {
        self.dataController = dataController
        self.budget = budget
        self.setupCoordinator = setupCoordinator
        
        // Listen for Firebase Auth state changes
        Auth.auth().addStateDidChangeListener { [weak self] (_, firebaseUser) in
            if let firebaseUser = firebaseUser {
                self?.fetchUserData(for: firebaseUser)
            } else {
                self?.currentUser = nil
            }
        }
    }
    
    private func fetchUserData(for firebaseUser: FirebaseAuth.User) {
        db.collection("users").document(firebaseUser.uid).getDocument { [weak self] (document, error) in
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
                }
            }
        }
    }
    
    func signUp(email: String, password: String, name: String) async throws {
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            let user = result.user
            
            // Create user document in Firestore
            let userData: [String: Any] = [
                "email": email,
                "name": name,
                "createdAt": Timestamp(date: Date()),
                "lastLoginAt": Timestamp(date: Date())
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
            
            // Update last login
            try await db.collection("users").document(result.user.uid).updateData([
                "lastLoginAt": Timestamp(date: Date())
            ])
            
            // Fetch updated user data
            fetchUserData(for: result.user)
            
        } catch {
            print("Sign in failed: \(error)")
            throw AuthError.invalidCredentials
        }
    }
    
    func signOut() {
        do {
            try Auth.auth().signOut()
            currentUser = nil
            dataController.clearCache()
            budget.reload()
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
                try await Auth.auth().signInAnonymously()
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
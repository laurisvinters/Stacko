import Foundation
import CoreData

class AuthenticationManager: ObservableObject {
    @Published private(set) var currentUser: User?
    private let dataController: DataController
    private let budget: Budget
    
    init(dataController: DataController, budget: Budget) {
        self.dataController = dataController
        self.budget = budget
        loadSavedUser()
    }
    
    private func loadSavedUser() {
        if let userData = UserDefaults.standard.data(forKey: "currentUser"),
           let user = try? JSONDecoder().decode(User.self, from: userData) {
            self.currentUser = user
        }
    }
    
    private func saveUser(_ user: User) {
        if let encoded = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(encoded, forKey: "currentUser")
            UserDefaults.standard.set(user.id.uuidString, forKey: "currentUserId")
        }
        self.currentUser = user
        budget.reload()
    }
    
    func signUp(email: String, password: String, name: String) throws {
        do {
            // Check if email already exists
            let request = CDUser.fetchRequest()
            request.predicate = NSPredicate(format: "email == %@", email)
            
            if let _ = try dataController.container.viewContext.fetch(request).first {
                throw AuthError.emailAlreadyExists
            }
            
            // Create new user
            let user = CDUser(context: dataController.container.viewContext)
            user.id = UUID()
            user.email = email
            user.passwordHash = User.hashPassword(password)
            user.name = name
            user.createdAt = Date()
            user.lastLoginAt = Date()
            
            try dataController.container.viewContext.save()
            
            saveUser(User(
                id: user.id!,
                email: user.email!,
                name: user.name!,
                createdAt: user.createdAt!,
                lastLoginAt: user.lastLoginAt!
            ))
        } catch {
            print("Failed to create user: \(error)")
            throw error
        }
    }
    
    func signIn(email: String, password: String) throws {
        do {
            let request = CDUser.fetchRequest()
            request.predicate = NSPredicate(format: "email == %@", email)
            
            guard let user = try dataController.container.viewContext.fetch(request).first else {
                throw AuthError.invalidCredentials
            }
            
            guard user.passwordHash == User.hashPassword(password) else {
                throw AuthError.invalidCredentials
            }
            
            user.lastLoginAt = Date()
            try dataController.container.viewContext.save()
            
            saveUser(User(
                id: user.id!,
                email: user.email!,
                name: user.name!,
                createdAt: user.createdAt!,
                lastLoginAt: user.lastLoginAt!
            ))
        } catch {
            print("Sign in failed: \(error)")
            throw AuthError.invalidCredentials
        }
    }
    
    func signOut() {
        UserDefaults.standard.removeObject(forKey: "currentUser")
        UserDefaults.standard.removeObject(forKey: "currentUserId")
        currentUser = nil
        budget.reload()
    }
    
    enum AuthError: LocalizedError {
        case emailAlreadyExists
        case invalidCredentials
        
        var errorDescription: String? {
            switch self {
            case .emailAlreadyExists:
                return "An account with this email already exists"
            case .invalidCredentials:
                return "Invalid email or password"
            }
        }
    }
} 
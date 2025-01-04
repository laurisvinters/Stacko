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
        dataController.clearCache()
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
        dataController.clearCache()
        budget.reload()
    }
    
    func deleteAccount() {
        guard let user = currentUser else { return }
        dataController.deleteUser(user.id)
        signOut()  // This will clear UserDefaults and currentUser
    }
    
    func continueAsGuest() {
        // Create a unique guest identifier
        let guestId = UUID()
        let guestEmail = "guest-\(guestId.uuidString)@temporary.com"
        
        // Create a temporary guest user
        let guestUser = User(
            id: guestId,
            email: guestEmail,
            name: "Guest",
            createdAt: Date(),
            lastLoginAt: Date()
        )
        
        // Create guest user in Core Data
        let user = CDUser(context: dataController.container.viewContext)
        user.id = guestUser.id
        user.email = guestUser.email
        user.name = guestUser.name
        user.createdAt = guestUser.createdAt
        user.lastLoginAt = guestUser.lastLoginAt
        user.passwordHash = "" // No password for guest
        
        try? dataController.container.viewContext.save()
        
        // Save guest user
        saveUser(guestUser)
    }
    
    var isGuestUser: Bool {
        currentUser?.email.contains("@temporary.com") ?? false
    }
    
    func convertGuestToFullAccount(email: String, password: String, name: String) throws {
        guard let guestUser = currentUser, isGuestUser else {
            throw AuthError.notGuestUser
        }
        
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
            
            // Transfer data from guest to new user
            dataController.transferGuestData(from: guestUser.id, to: user.id!)
            
            // Sign in as new user
            saveUser(User(
                id: user.id!,
                email: user.email!,
                name: user.name!,
                createdAt: user.createdAt!,
                lastLoginAt: user.lastLoginAt!
            ))
            
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
import SwiftUI
import FirebaseCore
import FirebaseAuth
import BackgroundTasks
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Only configure Firebase if it hasn't been configured yet
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        
        // Register background tasks
        BackgroundTaskManager.shared.registerBackgroundTasks()
        
        // Request notification permissions
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("Notification permission granted")
            } else if let error = error {
                print("Error requesting notification permission: \(error)")
            }
        }
        
        // Process transactions immediately
        if let userId = Auth.auth().currentUser?.uid {
            Task {
                let manager = PlannedTransactionManager(userId: userId)
                try? await manager.processAutomaticTransactions()
            }
        }
        
        return true
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        BackgroundTaskManager.shared.scheduleTransactionProcessing()
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        if let userId = Auth.auth().currentUser?.uid {
            Task {
                let manager = PlannedTransactionManager(userId: userId)
                try? await manager.processAutomaticTransactions()
            }
        }
    }
}

@main
struct StackoApp: App {
    private let budget: Budget
    private let setupCoordinator: SetupCoordinator
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var themeManager = ThemeManager()
    @StateObject private var authManager: AuthenticationManager
    
    init() {
        // Configure Firebase first
        FirebaseApp.configure()
        
        // Create instances after Firebase is configured
        self.budget = Budget()
        self.setupCoordinator = SetupCoordinator()
        
        // Then initialize auth manager with those instances
        let auth = AuthenticationManager(
            budget: self.budget,
            setupCoordinator: self.setupCoordinator
        )
        _authManager = StateObject(wrappedValue: auth)
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView(
                authManager: authManager,
                budget: budget,
                setupCoordinator: setupCoordinator
            )
            .environmentObject(themeManager)
            .environmentObject(authManager)
            .preferredColorScheme(themeManager.colorScheme)
            .onAppear {
                BackgroundTaskManager.shared.scheduleTransactionProcessing()
            }
        }
    }
}

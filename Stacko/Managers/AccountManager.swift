import Foundation
import FirebaseFirestore
import FirebaseAuth

class AccountManager: ObservableObject {
    static let shared = AccountManager()
    private let db = Firestore.firestore()
    @Published var accounts: [Account] = []
    
    private init() {
        if let userId = Auth.auth().currentUser?.uid {
            setupListener(userId: userId)
        }
    }
    
    private func setupListener(userId: String) {
        db.collection("users").document(userId)
            .collection("accounts")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let documents = snapshot?.documents else {
                    print("Error fetching accounts: \(error?.localizedDescription ?? "Unknown error")")
                    return
                }
                
                self?.accounts = documents.compactMap { document in
                    Account.fromFirestore(document.data())
                }
            }
    }
    
    func updateUserId(_ userId: String) {
        setupListener(userId: userId)
    }
}

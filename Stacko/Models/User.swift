import Foundation
import CryptoKit

struct User: Identifiable, Codable {
    let id: UUID
    var email: String
    var name: String
    var createdAt: Date
    var lastLoginAt: Date
    
    static func hashPassword(_ password: String) -> String {
        let inputData = Data(password.utf8)
        let hashed = SHA256.hash(data: inputData)
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }
} 
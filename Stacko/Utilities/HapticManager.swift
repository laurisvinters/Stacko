import UIKit

class HapticManager {
    static let shared = HapticManager()
    private var feedbackGenerator: UIImpactFeedbackGenerator?
    
    private init() {
        feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)
        feedbackGenerator?.prepare()
    }
    
    func impact() {
        feedbackGenerator?.impactOccurred()
    }
    
    func prepare() {
        feedbackGenerator?.prepare()
    }
} 
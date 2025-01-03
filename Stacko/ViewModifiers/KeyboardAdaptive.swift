import SwiftUI

struct KeyboardAdaptive: ViewModifier {
    @State private var keyboardHeight: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .ignoresSafeArea(.keyboard)
            .onAppear {
                setupKeyboardNotifications()
            }
            .onDisappear {
                removeKeyboardNotifications()
            }
            .padding(.bottom, keyboardHeight)
    }
    
    private func setupKeyboardNotifications() {
        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillShowNotification,
            object: nil,
            queue: .main
        ) { notification in
            if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                keyboardHeight = keyboardFrame.height
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillHideNotification,
            object: nil,
            queue: .main
        ) { _ in
            keyboardHeight = 0
        }
    }
    
    private func removeKeyboardNotifications() {
        NotificationCenter.default.removeObserver(self)
    }
}

extension View {
    func keyboardAdaptive() -> some View {
        modifier(KeyboardAdaptive())
    }
} 
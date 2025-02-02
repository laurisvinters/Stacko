import SwiftUI

class ThemeManager: ObservableObject {
    @AppStorage("isDarkMode") private(set) var isDarkMode: Bool = false
    
    func toggleTheme() {
        isDarkMode.toggle()
    }
    
    var colorScheme: ColorScheme {
        isDarkMode ? .dark : .light
    }
} 
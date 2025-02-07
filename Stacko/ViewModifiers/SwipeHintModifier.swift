import SwiftUI

struct SwipeHintModifier: ViewModifier {
    let enabled: Bool
    @State private var offset: CGFloat = 0
    @State private var hasShownHint = false
    
    // Custom timing curve that starts very fast and slows down dramatically
    private var slideAnimation: Animation {
        Animation.timingCurve(0.1, 0, 0.2, 1, duration: 0.5)
    }
    
    private var returnAnimation: Animation {
        Animation.timingCurve(0.1, 0, 0.2, 1, duration: 1.0)
    }
    
    func body(content: Content) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .trailing) {
                content
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemBackground))
                    .offset(x: offset)
                
                // Delete action background and icon
                ZStack {
                    Rectangle()
                        .fill(Color.red)
                    
                    Image(systemName: "trash")
                        .font(.title3)
                        .foregroundColor(.white)
                        .padding(.trailing, 25)
                }
                .frame(width: -offset)
                .opacity(offset < -1 ? 1 : 0) // Only show when offset is more than 1 point
            }
            .frame(maxWidth: .infinity)
            .clipped()
        }
        .onAppear {
            guard enabled && !hasShownHint else { return }
            
            // Initial delay before starting animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                // Slide left with custom timing curve
                withAnimation(slideAnimation) {
                    offset = -80
                }
                
                // Hold position for 0.3 seconds, then bounce back
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    withAnimation(returnAnimation) {
                        offset = 0
                    }
                    hasShownHint = true
                }
            }
        }
    }
}

extension View {
    func swipeHint(enabled: Bool = true) -> some View {
        modifier(SwipeHintModifier(enabled: enabled))
    }
}

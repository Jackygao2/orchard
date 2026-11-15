import SwiftUI

/// Removes app-owned animations while macOS Reduce Motion is enabled.
struct ReduceMotionModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.transaction { transaction in
            configureMotionTransaction(&transaction, reduceMotion: reduceMotion)
        }
    }
}

func configureMotionTransaction(_ transaction: inout Transaction, reduceMotion: Bool) {
    guard reduceMotion else { return }
    transaction.animation = nil
    transaction.disablesAnimations = true
}

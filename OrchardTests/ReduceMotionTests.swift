import SwiftUI
import Testing
@testable import Orchard

@Test("Reduce Motion removes and suppresses animations")
func reduceMotionDisablesAnimations() {
    var transaction = Transaction(animation: .easeInOut)
    configureMotionTransaction(&transaction, reduceMotion: true)
    #expect(transaction.animation == nil)
    #expect(transaction.disablesAnimations)
}

@Test("Without Reduce Motion existing animation settings remain")
func motionPreferencePreservesAnimations() {
    var transaction = Transaction(animation: .easeInOut)
    configureMotionTransaction(&transaction, reduceMotion: false)
    #expect(transaction.animation != nil)
    #expect(!transaction.disablesAnimations)
}

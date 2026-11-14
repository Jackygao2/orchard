import Combine
import Sparkle
import SwiftUI

/// Wraps Sparkle's updater so SwiftUI views can trigger update checks and
/// observe whether a check is currently allowed.
///
/// ContainerDesk 1.0 has no feed or public key and never starts the updater.
/// Sparkle remains linked for a possible future, separately configured channel.
final class UpdaterService: ObservableObject {
    private let updaterController: SPUStandardUpdaterController

    /// Mirrors Sparkle's `canCheckForUpdates` so menu items can disable
    /// themselves while a check is already in flight.
    @Published var canCheckForUpdates = false

    init() {
        // The disabled policy applies to every build, not only UI tests.
        updaterController = SPUStandardUpdaterController(
            startingUpdater: false,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )

    }

    /// Presents Sparkle's standard "Check for Updates" flow.
    func checkForUpdates() {
        // In-app updates are disabled until ContainerDesk has its own update channel.
    }
}

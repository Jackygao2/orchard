import AppKit
import Foundation

/// Observes workspace power/session events. Notifications never start or stop workloads.
@MainActor
final class PowerEventsObserver: ObservableObject {
    @Published private(set) var isSleeping = false
    @Published private(set) var refreshRevision: UInt64 = 0
    private(set) var epoch: UInt64 = 0
    var onSleep: () -> Void = {}
    var onWake: () -> Void = {}
    var onRefresh: () -> Void = {}
    private var pollingToken: UUID?
    var isPolling: Bool { pollingToken != nil }

    func beginPoll() -> UUID? {
        guard !isSleeping, pollingToken == nil else { return nil }
        let token = UUID()
        pollingToken = token
        return token
    }

    func endPoll(_ token: UUID) {
        if pollingToken == token { pollingToken = nil }
    }
    private let center: NotificationCenter
    private var observers: [NSObjectProtocol] = []

    init(center: NotificationCenter = NSWorkspace.shared.notificationCenter) {
        self.center = center
        for name in [NSWorkspace.willSleepNotification, NSWorkspace.didWakeNotification, NSWorkspace.sessionDidBecomeActiveNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
                MainActor.assumeIsolated { self?.receive(note.name) }
            })
        }
    }

    private func receive(_ name: Notification.Name) {
        if name == NSWorkspace.willSleepNotification {
            guard !isSleeping else { return }
            epoch &+= 1
            isSleeping = true
            pollingToken = nil
            onSleep()
        } else if name == NSWorkspace.didWakeNotification {
            guard isSleeping else { return }
            epoch &+= 1
            isSleeping = false
            onWake()
            onRefresh()
            refreshRevision &+= 1
        } else if name == NSWorkspace.sessionDidBecomeActiveNotification, !isSleeping {
            epoch &+= 1
            pollingToken = nil
            onRefresh()
            refreshRevision &+= 1
        }
    }

    deinit { for observer in observers { center.removeObserver(observer) } }
}

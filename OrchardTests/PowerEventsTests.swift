import AppKit
import Foundation
import Testing
@testable import Orchard

@MainActor
@Test("Sleep and wake notifications pause and resume once, and activation requests refresh")
func powerNotifications() {
    let center = NotificationCenter()
    let observer = PowerEventsObserver(center: center)
    var sleeps = 0
    var wakes = 0
    observer.onSleep = { sleeps += 1 }
    observer.onWake = { wakes += 1 }
    let first = observer.beginPoll()
    #expect(first != nil && observer.beginPoll() == nil)
    center.post(name: NSWorkspace.willSleepNotification, object: nil)
    center.post(name: NSWorkspace.willSleepNotification, object: nil)
    #expect(observer.beginPoll() == nil)
    #expect(observer.isSleeping && sleeps == 1)
    center.post(name: NSWorkspace.sessionDidBecomeActiveNotification, object: nil)
    #expect(observer.refreshRevision == 0)
    center.post(name: NSWorkspace.didWakeNotification, object: nil)
    center.post(name: NSWorkspace.didWakeNotification, object: nil)
    #expect(!observer.isSleeping && wakes == 1 && observer.refreshRevision == 1)
    let second = observer.beginPoll()
    #expect(second != nil)
    if let first { observer.endPoll(first) }
    #expect(observer.beginPoll() == nil)
    if let second { observer.endPoll(second) }
    center.post(name: NSWorkspace.sessionDidBecomeActiveNotification, object: nil)
    #expect(observer.refreshRevision == 2)
}

@MainActor
@Test("Power events and disconnect recovery never stop workloads")
func powerRecoveryDoesNotStop() async {
    let backend = MockContainerBackend()
    let runner = MockCommandRunner()
    let services = makeService(backend: backend, runner: runner)
    let center = NotificationCenter()
    let observer = PowerEventsObserver(center: center)
    observer.onSleep = {
        services.systemService.invalidatePolls()
        services.containerListService.invalidatePolls()
        services.statsService.setSleeping(true)
    }
    observer.onWake = { services.statsService.setSleeping(false) }
    backend.pingError = NotConfigured()
    await services.systemService.checkSystemStatus()
    #expect(services.systemService.systemStatus != .running)
    center.post(name: NSWorkspace.willSleepNotification, object: nil)
    center.post(name: NSWorkspace.didWakeNotification, object: nil)
    backend.pingError = nil
    await services.systemService.checkSystemStatus()
    #expect(services.systemService.systemStatus == .running)
    #expect(!runner.calls.contains { $0.starts(with: ["system", "stop"]) })
    #expect(backend.deletedContainers.isEmpty && backend.stoppedContainers.isEmpty && backend.deletedVolumeNames.isEmpty)
}

@MainActor
@Test("Sleep invalidates a list started before the notification")
func powerDiscardsStaleList() async throws {
    let backend = MockContainerBackend()
    backend.containers = [try makeContainer(id: "before-sleep", status: "running")]
    let services = makeService(backend: backend)
    let center = NotificationCenter()
    let observer = PowerEventsObserver(center: center)
    observer.onSleep = { services.containerListService.invalidatePolls() }
    let entered = TestGate()
    let release = TestGate()
    backend.listContainersHandler = { entered.open(); await release.wait() }
    let load = Task { await services.containerListService.loadContainers() }
    await entered.wait()
    center.post(name: NSWorkspace.willSleepNotification, object: nil)
    release.open()
    await load.value
    #expect(services.containerListService.containers.isEmpty)
    backend.listContainersHandler = nil
    backend.containers = [try makeContainer(id: "after-wake", status: "running")]
    center.post(name: NSWorkspace.didWakeNotification, object: nil)
    await services.containerListService.loadContainers()
    #expect(services.containerListService.containers.map(\.configuration.id) == ["after-wake"])
}

@MainActor
@Test("Wake refreshes backend status and containers without an open window")
func wakeRefreshesServices() async throws {
    let backend = MockContainerBackend()
    backend.containers = [try makeContainer(id: "awake", status: "running")]
    let center = NotificationCenter()
    let entered = TestGate()
    backend.listContainersHandler = { entered.open() }
    let services = AppServices(backend: backend, machineBackend: MockMachineBackend(), runner: MockCommandRunner(),
                               defaults: ephemeralDefaults(), secrets: InMemorySecretsStore(),
                               isContainerInstalled: { true }, rosettaService: RosettaService(probe: { .installed }, installer: {}),
                               powerNotificationCenter: center)
    center.post(name: NSWorkspace.willSleepNotification, object: nil)
    center.post(name: NSWorkspace.didWakeNotification, object: nil)
    await entered.wait()
    for _ in 0..<10 where services.containerListService.containers.isEmpty { await Task.yield() }
    #expect(backend.pingCount >= 1)
    #expect(services.containerListService.containers.map(\.configuration.id) == ["awake"])
}

@MainActor
@Test("Sleep discards a health response that began before sleep")
func powerDiscardsStalePing() async {
    let backend = MockContainerBackend()
    let services = makeService(backend: backend)
    let center = NotificationCenter()
    let observer = PowerEventsObserver(center: center)
    observer.onSleep = { services.systemService.invalidatePolls() }
    let entered = TestGate()
    let release = TestGate()
    backend.pingHandler = {
        entered.open()
        await release.wait()
        return SystemHealthInfo(apiServerVersion: "old")
    }
    let ping = Task { await services.systemService.checkSystemStatus() }
    await entered.wait()
    center.post(name: NSWorkspace.willSleepNotification, object: nil)
    backend.pingHandler = { SystemHealthInfo(apiServerVersion: "new") }
    center.post(name: NSWorkspace.didWakeNotification, object: nil)
    await services.systemService.checkSystemStatus()
    release.open()
    await ping.value
    #expect(services.systemService.containerVersion == "new")
}

@MainActor
@Test("A pre-sleep network read cannot overwrite the wake snapshot")
func powerDiscardsStaleNetwork() async {
    let backend = MockContainerBackend()
    backend.networks = [makeNetwork(id: "old")]
    let center = NotificationCenter()
    let observer = PowerEventsObserver(center: center)
    let service = NetworkService(backend: backend, alertCenter: AlertCenter())
    service.powerEpoch = { observer.epoch }
    let entered = TestGate()
    let release = TestGate()
    backend.listNetworksHandler = { entered.open(); await release.wait() }
    let old = Task { await service.load(showLoading: false) }
    await entered.wait()
    center.post(name: NSWorkspace.willSleepNotification, object: nil)
    center.post(name: NSWorkspace.didWakeNotification, object: nil)
    backend.listNetworksHandler = nil
    backend.networks = [makeNetwork(id: "new")]
    await service.load(showLoading: false)
    release.open()
    await old.value
    #expect(service.networks.map(\.id) == ["new"])
}

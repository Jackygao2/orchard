import Foundation
import Testing
@testable import Orchard

@MainActor
private func setupCoordinator(runtime: OnboardingCoordinator.Runtime, plugin: Bool = false, verify: @escaping () async throws -> Void = {}, install: @escaping () async -> Bool = { true }, start: @escaping (Bool) async -> Bool = { _ in true }, installPlugin: @escaping () async -> Bool = { true }) -> OnboardingCoordinator {
    OnboardingCoordinator(defaults: ephemeralDefaults(), operations: .init(detect: { runtime }, install: install, installFailure: { "Install failed" }, acceptNewer: {}, start: start, startFailure: { nil }, verify: verify, pluginInstalled: { plugin }, installPlugin: installPlugin, pluginFailure: { "Plugin failed" }))
}

@MainActor
@Test("Version policy classifies older, newer, incompatible and unknown versions")
func onboardingVersions() {
    #expect(OnboardingCoordinator.policy(version: "1.7.1") == .compatible)
    #expect(OnboardingCoordinator.policy(version: "1.6.0") == .older)
    #expect(OnboardingCoordinator.policy(version: "1.8.0") == .newer)
    #expect(OnboardingCoordinator.policy(version: "2.0.0") == .incompatible)
    #expect(OnboardingCoordinator.policy(version: nil) == .unknown)
}

@MainActor
@Test("Runtime states route to the appropriate setup step")
func onboardingDetection() async {
    let cases: [(OnboardingCoordinator.Runtime, OnboardingCoordinator.Stage)] = [
        (.init(installed: false, running: false, version: nil), .install),
        (.init(installed: true, running: false, version: "1.7.1"), .start),
        (.init(installed: true, running: true, version: "1.6.0"), .older("1.6.0")),
        (.init(installed: true, running: true, version: "1.8.0"), .newer("1.8.0")),
        (.init(installed: true, running: true, version: "2.0.0"), .blocked("2.0.0")),
        (.init(installed: true, running: true, version: "1.7.1"), .plugin),
    ]
    for (runtime, expected) in cases {
        let coordinator = setupCoordinator(runtime: runtime)
        await coordinator.detect()
        #expect(coordinator.stage == expected)
    }
}

@MainActor
@Test("Install never starts the Runtime without first-start approval")
func onboardingRequiresFirstStart() async {
    var starts = 0
    var gotFresh = false
    let coordinator = setupCoordinator(runtime: .init(installed: false, running: false, version: nil), start: { fresh in starts += 1; gotFresh = fresh; return true })
    await coordinator.detect()
    coordinator.install()
    for _ in 0..<100 where coordinator.stage != .start { await Task.yield() }
    #expect(coordinator.stage == .start && starts == 0)
    coordinator.start()
    for _ in 0..<100 where coordinator.stage != .plugin { await Task.yield() }
    #expect(starts == 1 && gotFresh && coordinator.stage == .plugin)
    coordinator.skipPlugin()
    #expect(coordinator.stage == .done)
    coordinator.finish()
    #expect(!coordinator.isPresented)
    coordinator.runSetupAgain()
    #expect(coordinator.isPresented && coordinator.stage == .welcome)
}

@MainActor
@Test("Installation, verification and optional plugin failures remain recoverable")
func onboardingFailures() async {
    let missing = OnboardingCoordinator.Runtime(installed: false, running: false, version: nil)
    let install = setupCoordinator(runtime: missing, install: { false })
    await install.detect()
    install.install()
    for _ in 0..<100 { if case .failure = install.stage { break }; await Task.yield() }
    #expect(install.stage == .failure("Install failed"))
    let running = OnboardingCoordinator.Runtime(installed: true, running: true, version: "1.7.1")
    let verify = setupCoordinator(runtime: running, verify: { throw NotConfigured() })
    await verify.detect()
    if case .failure = verify.stage {} else { Issue.record("Expected verification failure") }
    let plugin = setupCoordinator(runtime: running, installPlugin: { false })
    await plugin.detect()
    plugin.installPlugin()
    for _ in 0..<100 { if case .failure = plugin.stage { break }; await Task.yield() }
    #expect(plugin.pluginFailed && plugin.stage == .failure("Plugin failed"))
    plugin.skipPlugin()
    #expect(plugin.stage == .done)
}

@MainActor
@Test("Runtime status gates newer versions and refuses a different major")
func onboardingRuntimeVersionGate() async {
    let backend = MockContainerBackend()
    let services = makeService(backend: backend)
    backend.pingHandler = { SystemHealthInfo(apiServerVersion: "1.8.0") }
    await services.systemService.checkSystemStatus()
    #expect(services.systemService.systemStatus == .newerVersion)
    await services.systemService.checkSystemStatusIgnoreVersion()
    #expect(services.systemService.systemStatus == .running)
    backend.pingHandler = { SystemHealthInfo(apiServerVersion: "2.0.0") }
    await services.systemService.checkSystemStatus()
    #expect(services.systemService.systemStatus == .unsupportedVersion)
}

@MainActor
@Test("Cancellation ignores a late installation result")
func onboardingCancelInstall() async {
    let entered = TestGate()
    let release = TestGate()
    let coordinator = setupCoordinator(runtime: .init(installed: false, running: false, version: nil), install: {
        entered.open()
        await release.wait()
        return true
    })
    await coordinator.detect()
    coordinator.install()
    await entered.wait()
    coordinator.cancelInstallation()
    release.open()
    for _ in 0..<20 { await Task.yield() }
    #expect(coordinator.stage == .install)
}

@MainActor
@Test("Older and newer stopped Runtimes ask before the first start")
func onboardingVersionWarningsRespectStartConsent() async {
    for version in ["1.6.0", "1.8.0"] {
        var starts = 0
        let coordinator = setupCoordinator(runtime: .init(installed: true, running: false, version: version), start: { _ in starts += 1; return true })
        await coordinator.detect()
        coordinator.continueVersion()
        for _ in 0..<100 where coordinator.stage != .start { await Task.yield() }
        #expect(coordinator.stage == .start && starts == 0)
    }
}

@MainActor
@Test("A completed setup persists and rerunning setup clears completion")
func onboardingCompletionPersistence() async {
    let defaults = ephemeralDefaults()
    let operations = OnboardingCoordinator.Operations(detect: { .init(installed: true, running: true, version: "1.7.1") }, install: { true }, installFailure: { nil }, acceptNewer: {}, start: { _ in true }, startFailure: { nil }, verify: {}, pluginInstalled: { true }, installPlugin: { true }, pluginFailure: { nil })
    let first = OnboardingCoordinator(defaults: defaults, operations: operations)
    await first.detect()
    #expect(first.stage == .done)
    first.finish()
    let second = OnboardingCoordinator(defaults: defaults, operations: operations)
    #expect(!second.isPresented)
    second.runSetupAgain()
    #expect(second.isPresented)
    let third = OnboardingCoordinator(defaults: defaults, operations: operations)
    #expect(third.isPresented)
}

@MainActor
@Test("Settings reads an installed Runtime CLI version without starting it")
func settingsReadsRuntimeVersion() async {
    let runner = MockCommandRunner()
    runner.runHandler = { _, _ in ProcessResult(exitCode: 0, stdout: "container version 1.7.1", stderr: nil) }
    let services = makeService(runner: runner)
    #expect(await services.systemService.installedCLIVersion() == "1.7.1")
    #expect(runner.calls == [["--version"]])
    #expect(OnboardingCoordinator.extractVersion("no version") == nil)
}

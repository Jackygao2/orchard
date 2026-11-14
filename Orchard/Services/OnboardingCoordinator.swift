import Foundation

/// The setup state machine uses injected operations; it never starts or installs by itself.
@MainActor
final class OnboardingCoordinator: ObservableObject {
    enum CompletionAction { case overview, nginx, compose }
    enum Stage: Equatable {
        case welcome, checking, install, installing, start, starting, older(String), newer(String)
        case blocked(String), verifying, plugin, pluginInstalling, done, failure(String)
    }
    struct Runtime: Equatable {
        let installed: Bool
        let running: Bool
        let version: String?
    }
    enum VersionPolicy: Equatable { case compatible, older, newer, incompatible, unknown }
    struct Operations {
        var detect: () async throws -> Runtime
        var install: () async -> Bool
        var installFailure: () -> String?
        var acceptNewer: () -> Void
        var start: (Bool) async -> Bool
        var startFailure: () -> String?
        var verify: () async throws -> Void
        var pluginInstalled: () async -> Bool
        var installPlugin: () async -> Bool
        var pluginFailure: () -> String?
    }
    @Published private(set) var stage: Stage = .welcome
    @Published private(set) var isPresented: Bool
    private let defaults: UserDefaults
    private let operations: Operations
    private let completedKey = "ContainerDeskOnboardingCompleted"
    private(set) var freshInstall = false
    private enum FailureOrigin { case detect, install, start, verify, plugin }
    private var failureOrigin: FailureOrigin = .detect
    private var runtimeRunning = false
    private(set) var completionAction: CompletionAction = .overview
    @Published private(set) var pluginFailed = false
    private var operation: Task<Void, Never>?

    init(defaults: UserDefaults, operations: Operations, forceShow: Bool = false) {
        self.defaults = defaults
        self.operations = operations
        isPresented = forceShow || !defaults.bool(forKey: completedKey)
    }

    nonisolated static func extractVersion(_ output: String) -> String? {
        guard let range = output.range(of: #"[0-9]+\.[0-9]+(?:\.[0-9]+)?"#, options: .regularExpression) else { return nil }
        return String(output[range])
    }

    static func policy(version: String?) -> VersionPolicy {
        guard let version, let parsed = ComposePluginVersion(version),
              let major = parsed.components.first else { return .unknown }
        guard major == 1 else { return .incompatible }
        guard let linked = ComposePluginVersion(supportedContainerVersion) else { return .unknown }
        if parsed < linked { return .older }
        if parsed > linked { return .newer }
        return .compatible
    }

    #if DEBUG
    func skipForUITest() { isPresented = false }
    #endif

    func recordStartApproval() { defaults.set(true, forKey: "ContainerDeskApprovedRuntimeStart") }
    func runSetupAgain() {
        if case .installing = stage { return }
        if case .pluginInstalling = stage { return }
        operation?.cancel(); defaults.set(false, forKey: completedKey); stage = .welcome; isPresented = true
    }
    func begin() { operation?.cancel(); operation = Task { await detect() } }
    func detect() async {
        stage = .checking
        do {
            let runtime = try await operations.detect()
            guard !Task.isCancelled else { return }
            freshInstall = false
            pluginFailed = false
            runtimeRunning = runtime.running
            guard runtime.installed else { stage = .install; return }
            switch Self.policy(version: runtime.version) {
            case .compatible: if runtime.running { await verify() } else { await offerOrStart() }
            case .older: stage = .older(runtime.version ?? "unknown")
            case .newer: stage = .newer(runtime.version ?? "unknown")
            case .incompatible: stage = .blocked(runtime.version ?? "unknown")
            case .unknown: failureOrigin = .detect; stage = .failure("Could not determine the installed Runtime version. Check the installation and retry.")
            }
        } catch { failureOrigin = .detect; stage = .failure("Could not check the Runtime: \(error.localizedDescription)") }
    }
    func continueVersion() {
        if case .newer = stage { operations.acceptNewer() }
        operation = Task { if runtimeRunning { await verify() } else { await offerOrStart() } }
    }
    private func offerOrStart() async {
        if defaults.bool(forKey: "ContainerDeskApprovedRuntimeStart") { await performStart() }
        else { stage = .start }
    }
    func install() {
        operation?.cancel()
        operation = Task {
            stage = .installing
            let ok = await operations.install()
            guard !Task.isCancelled else { return }
            if ok { freshInstall = true; runtimeRunning = false; await offerOrStart() }
            else { failureOrigin = .install; stage = .failure(operations.installFailure() ?? "The Runtime installation did not finish. Try again or use the manual instructions.") }
        }
    }
    func cancelInstallation() { operation?.cancel(); operation = nil; stage = .install }
    func start() { operation = Task { await performStart() } }
    private func performStart() async {
            stage = .starting
            let ok = await operations.start(freshInstall)
            guard !Task.isCancelled else { return }
            if ok { defaults.set(true, forKey: "ContainerDeskApprovedRuntimeStart"); runtimeRunning = true; await verify() }
            else { failureOrigin = .start; stage = .failure(operations.startFailure() ?? "The Runtime could not start. Check the manual instructions and retry.") }
    }
    func verify() async {
        stage = .verifying
        do {
            try await operations.verify()
            guard !Task.isCancelled else { return }
            let installed = await operations.pluginInstalled()
            guard !Task.isCancelled else { return }
            stage = installed ? .done : .plugin
        } catch { failureOrigin = .verify; stage = .failure("The Runtime did not pass verification: \(error.localizedDescription)") }
    }
    func installPlugin() {
        operation = Task {
            stage = .pluginInstalling
            let ok = await operations.installPlugin()
            guard !Task.isCancelled else { return }
            pluginFailed = !ok
            if !ok { failureOrigin = .plugin }
            stage = ok ? .done : .failure(operations.pluginFailure() ?? "The optional plugin could not be installed. Retry or skip it.")
        }
    }
    func retry() {
        switch failureOrigin {
        case .detect: begin()
        case .install: install()
        case .start: start()
        case .verify: operation = Task { await verify() }
        case .plugin: installPlugin()
        }
    }
    func skipPlugin() { operation?.cancel(); stage = .done }
    func finish(action: CompletionAction = .overview) { completionAction = action; defaults.set(true, forKey: completedKey); isPresented = false }
}

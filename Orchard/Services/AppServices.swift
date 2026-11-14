import Foundation
import Combine
import AppKit

/// App version, read once from the bundle. (Previously `ContainerService.currentVersion`.)
enum AppInfo {
    static let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
}

/// Constructs and wires the per-domain services and owns their lifetime. Not a facade - 
/// views observe the individual services directly; this only holds them and the
/// cross-service callbacks that were previously set up in `ContainerService.init`.
@MainActor
final class AppServices: ObservableObject {
    let alertCenter: AlertCenter
    let settings: SettingsStore
    let terminalLauncher: TerminalLauncher
    let builderService: BuilderService
    let networkService: NetworkService
    let volumeService: VolumeService
    let imageService: ImageService
    let imageBuildService: ImageBuildService
    let statsService: StatsService
    let powerEvents: PowerEventsObserver
    let dnsService: DNSService
    let systemService: SystemService
    let diskPurgeService: DiskPurgeService
    let containerListService: ContainerListService
    let machineService: MachineService
    let clusterService: ClusterService
    let composeService: ComposeService
    let composePluginService: ComposePluginService
    let containerInstallService: ContainerInstallService
    let modelService: ModelService
    let modelServerService: ModelServerService
    let rosettaService: RosettaService

    /// The services for app launch: normally the live backend, or (Debug + launch arg) an
    /// in-memory stub seeded with fixtures for the XCUITest smoke suite.
    static func forLaunch() -> AppServices {
        #if DEBUG
        if isUITestMockBackendRequested {
            // The stub backend is the container install; whether the machine running the
            // suite has one is beside the point.
            let testRecords = FileManager.default.temporaryDirectory
                .appendingPathComponent("containerdesk-ui-\(UUID().uuidString)", isDirectory: true)
                .appendingPathComponent("compose-projects.json")
            return AppServices(backend: UITestBackend(), machineBackend: UITestMachineBackend(), modelBackend: UITestModelBackend(), modelServerEngine: UITestModelServerEngine(), runner: UITestCommandRunner(), isContainerInstalled: { true }, rosettaService: RosettaService(probe: { .installed }, installer: {}), simulateTerminal: true, composePersistence: ComposeProjectsPersistence(fileURL: testRecords))
        }
        #endif
        let services = AppServices()
        // Start always-on stats sampling + restore persisted history (real launch only).
        services.statsService.activate()
        return services
    }

    #if DEBUG
    private static var isUITestMockBackendRequested: Bool {
        ProcessInfo.processInfo.arguments.contains(uiTestMockBackendArgument)
            || ProcessInfo.processInfo.environment["ORCHARD_UITEST_MOCK_BACKEND"] == "1"
    }
    #endif

    init(
        backend: ContainerBackend = LiveContainerBackend(),
        machineBackend: MachineBackend = LiveMachineBackend(),
        modelBackend: ModelBackend = LiveModelBackend(),
        modelServerEngine: ModelServerEngine = MLXServerEngine(),
        runner: CommandRunner = SystemCommandRunner(),
        defaults: UserDefaults = .standard,
        secrets: SecretsStore = KeychainSecretsStore(),
        isContainerInstalled: (@MainActor () -> Bool)? = nil,
        rosettaService: RosettaService? = nil,
        simulateTerminal: Bool = false,
        composePersistence: ComposeProjectsPersistence = ComposeProjectsPersistence(),
        powerNotificationCenter: NotificationCenter = NSWorkspace.shared.notificationCenter
    ) {
        let alertCenter = AlertCenter()
        self.alertCenter = alertCenter
        let settings = SettingsStore(alertCenter: alertCenter, defaults: defaults, secrets: secrets)
        self.settings = settings
        self.terminalLauncher = TerminalLauncher(settings: settings, alertCenter: alertCenter, terminalOverride: simulateTerminal ? { id in
            alertCenter.error("UI test: terminal requested for \(id)")
        } : nil)
        let builderService = BuilderService(runner: runner, settings: settings, alertCenter: alertCenter)
        self.builderService = builderService
        let clusterService = ClusterService(runner: runner, settings: settings, alertCenter: alertCenter, defaults: defaults)
        self.clusterService = clusterService
        let networkService = NetworkService(backend: backend, alertCenter: alertCenter)
        self.networkService = networkService
        let volumeService = VolumeService(backend: backend, alertCenter: alertCenter)
        self.volumeService = volumeService
        let imageService = ImageService(backend: backend, alertCenter: alertCenter)
        self.imageService = imageService
        let imageBuildService = ImageBuildService(runner: runner, settings: settings)
        self.imageBuildService = imageBuildService
        // A finished build produces a new image; refresh the list that shows it.
        imageBuildService.onImageBuilt = { [weak imageService] in await imageService?.load() }
        let dnsService = DNSService(runner: runner, settings: settings, alertCenter: alertCenter)
        self.dnsService = dnsService
        let systemService = SystemService(backend: backend, runner: runner, settings: settings, alertCenter: alertCenter, isContainerInstalled: isContainerInstalled)
        self.systemService = systemService
        let diskPurgeService = DiskPurgeService(backend: backend)
        self.diskPurgeService = diskPurgeService
        // ContainerListService is built before StatsService, which depends on it.
        let containerListService = ContainerListService(backend: backend, alertCenter: alertCenter)
        self.containerListService = containerListService
        let statsService = StatsService(backend: backend, alertCenter: alertCenter, containerList: containerListService)
        self.statsService = statsService
        let machineService = MachineService(backend: machineBackend, alertCenter: alertCenter)
        self.machineService = machineService
        let powerEvents = PowerEventsObserver(center: powerNotificationCenter)
        self.powerEvents = powerEvents
        powerEvents.onSleep = { [weak systemService, weak containerListService, weak statsService] in
            systemService?.invalidatePolls()
            containerListService?.invalidatePolls()
            statsService?.setSleeping(true)
        }
        powerEvents.onWake = { [weak statsService] in statsService?.setSleeping(false) }
        powerEvents.onRefresh = { [weak powerEvents, weak systemService, weak containerListService, weak imageService, weak builderService, weak dnsService, weak networkService, weak volumeService, weak machineService, weak statsService] in
            guard let powerEvents, let systemService, let containerListService else { return }
            systemService.invalidatePolls()
            containerListService.invalidatePolls()
            let revision = powerEvents.refreshRevision &+ 1
            Task { @MainActor in
                guard !powerEvents.isSleeping, !systemService.isSystemLoading, let token = powerEvents.beginPoll() else { return }
                defer { powerEvents.endPoll(token) }
                await systemService.checkSystemStatus()
                guard !powerEvents.isSleeping, revision == powerEvents.refreshRevision, systemService.systemStatus == .running else { return }
                await containerListService.loadContainers(showLoading: false)
                guard !powerEvents.isSleeping, revision == powerEvents.refreshRevision else { return }
                await imageService?.load()
                guard !powerEvents.isSleeping, revision == powerEvents.refreshRevision else { return }
                await builderService?.loadBuilders()
                guard !powerEvents.isSleeping, revision == powerEvents.refreshRevision else { return }
                await dnsService?.load(showLoading: false)
                guard !powerEvents.isSleeping, revision == powerEvents.refreshRevision else { return }
                await networkService?.load(showLoading: false)
                guard !powerEvents.isSleeping, revision == powerEvents.refreshRevision else { return }
                await volumeService?.load(showLoading: false)
                guard !powerEvents.isSleeping, revision == powerEvents.refreshRevision else { return }
                await machineService?.load(showLoading: false)
                guard !powerEvents.isSleeping, revision == powerEvents.refreshRevision else { return }
                await statsService?.load(showLoading: false)
            }
        }
        self.modelService = ModelService(backend: modelBackend, settings: settings)
        self.modelServerService = ModelServerService(engine: modelServerEngine, alertCenter: alertCenter)
        self.rosettaService = rosettaService ?? RosettaService()
        // Compose runs plans through the same backend as everything else, and its builds
        // through the same build service as the Images tab, so a compose build shows up in
        // the Builds tab with its log.
        let composeService = ComposeService(
            backend: backend,
            buildService: imageBuildService,
            alertCenter: alertCenter,
            persistence: composePersistence
        )
        self.composeService = composeService
        // Only ever informs: a missing CLI plugin changes nothing about what the window can do.
        let composePluginService = ComposePluginService(commandRunner: runner, containerBinaryPath: { settings.safeContainerBinaryPath() }, defaults: defaults)
        composePluginService.runtimeVersion = { [weak systemService] in systemService?.containerVersion }
        self.composePluginService = composePluginService
        let containerInstallService = ContainerInstallService(commandRunner: runner)
        self.containerInstallService = containerInstallService

        containerListService.reloadBuilders = { [weak builderService] in await builderService?.loadBuilders() }
        // A commit adds an image, or replaces one.
        containerListService.reloadImages = { [weak imageService] in await imageService?.load() }
        // Reclaiming a container's free blocks changes what the daemon reports as used.
        containerListService.reloadDiskUsage = { [weak systemService] in
            await systemService?.loadSystemDiskUsage(showLoading: false)
        }
        // A purge removes containers, images and volumes, and frees what the tiles report.
        diskPurgeService.onPurged = { [weak systemService, weak imageService, weak containerListService, weak volumeService] in
            await systemService?.loadSystemDiskUsage(showLoading: false)
            await imageService?.load()
            await containerListService?.loadContainers(showLoading: false)
            await volumeService?.load(showLoading: false)
        }
        // Compose containers are created under the domain chosen in Settings, as the Run form's
        // are; without one, ComposeService reads the daemon's itself when it creates each.
        composeService.chosenDNSDomain = { [weak settings] in settings?.defaultDNSDomain }
        // A compose run creates and removes containers; refresh the list projects derive from.
        composeService.reloadContainers = { [weak containerListService] in
            await containerListService?.loadContainers(showLoading: false)
        }
        composeService.reloadNetworks = { [weak networkService] in
            await networkService?.load(showLoading: false)
        }
        composeService.reloadVolumes = { [weak volumeService] in
            await volumeService?.load(showLoading: false)
        }
        // Cluster lifecycle actions change node containers; refresh the list they derive from.
        clusterService.reloadContainers = { [weak containerListService] in await containerListService?.loadContainers(showLoading: false) }
        clusterService.existingContainerIDs = { [weak containerListService] in
            Set(containerListService?.containers.map(\.configuration.id) ?? [])
        }
        clusterService.currentClusters = { [weak clusterService, weak containerListService] in
            clusterService?.clusters(from: containerListService?.containers ?? []) ?? []
        }
        clusterService.containerVersion = { [weak systemService] in systemService?.containerVersion }
        // Stats samples running machines through their backing container (re-keyed to the
        // stable machine id). Supplied lazily so the sampler always sees the current machines.
        statsService.machineStatTargets = { [weak machineService] in
            (machineService?.machines ?? [])
                .filter { $0.isRunning }
                .compactMap { machine in
                    machine.containerId.map { (machineId: machine.id, backingId: $0, cpus: machine.cpus) }
                }
        }
        // DNS → System: the daemon's `dns.domain` stands in when no default is chosen in Orchard.
        dnsService.refreshSystemProperties = { [weak systemService] in await systemService?.loadSystemProperties(showLoading: false) }
        dnsService.readContainerDNSDefaults = { try await backend.containerDNSDefaults() }
        dnsService.readHostDNSDomain = { try await backend.daemonDNSDomain() }
        dnsService.daemonDefaultDomain = { [weak systemService] in
            systemService?.systemProperties
                .first(where: { $0.id == "dns.domain" && !$0.isUndefined && !$0.value.isEmpty })?.value
        }
        // A fresh install has no kernel yet: start with the default one.
        containerInstallService.onInstalled = { [weak systemService] in
            await systemService?.startSystem(installKernel: true)
        }
        // System → containers side effects.
        systemService.onSystemStarted = { [weak containerListService] in await containerListService?.loadContainers() }
        systemService.onSystemStopped = { [weak containerListService, weak clusterService] in
            containerListService?.containers.removeAll()
            // Stopped clusters' nodes leave the list with everything else; their records must
            // not read as clusters whose nodes are gone.
            clusterService?.resetStoredConfigurations()
        }
    }
}

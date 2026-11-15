import SwiftUI

@main
struct OrchardApp: App {
    @StateObject private var services = AppServices.forLaunch()
    @StateObject private var menuBarManager = MenuBarManager()
    @StateObject private var updater = UpdaterService()

    init() {
        // Apply the persisted Dock-icon preference before any window appears. Read
        // straight from defaults: the services aren't built yet. .always needs no
        // applying - the app launches as .regular, the policy's starting mode is
        // .always, and applying it here would trigger the restore-activation dance at
        // every launch.
        let mode = DockIconMode.stored(in: .standard)
        if mode != .always {
            DockIconPolicy.applyAtLaunch(mode)
        }
    }

    var body: some Scene {
        WindowGroup(id: "main") {
            ContentView()
                .injectServices(services)
                .environmentObject(updater)
                .modifier(ReduceMotionModifier())
        }
        .defaultSize(width: 1200, height: 800)
        .windowToolbarStyle(.unified(showsTitle: false))
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About \(AppBrand.name)") {
                    NSApplication.shared.orderFrontStandardAboutPanel(options: [
                        .credits: NSAttributedString(string: AppBrand.orchardCredit + "\nContainerDesk contributors")
                    ])
                }
            }
            CommandGroup(after: .sidebar) {
                Divider()
                ForEach(Array([TabSelection.dashboard, .containers, .compose, .images, .volumes, .networks].enumerated()), id: \.offset) { index, tab in
                    Button(tab.title) {
                        NotificationCenter.default.post(name: NSNotification.Name("NavigatePrimaryTab"), object: tab.rawValue)
                    }
                    .keyboardShortcut(KeyEquivalent(Character(String(index + 1))), modifiers: .command)
                }
                Divider()
                Button("Search") {
                    NotificationCenter.default.post(name: NSNotification.Name("FocusNavigationSearch"), object: nil)
                }
                .keyboardShortcut("f", modifiers: .command)
                Button("Open Compose Project…") {
                    NotificationCenter.default.post(name: NSNotification.Name("OpenComposeProject"), object: nil)
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])
                Button("Command Palette...") {
                    NotificationCenter.default.post(
                        name: NSNotification.Name("ToggleCommandPalette"), object: nil)
                }
                .keyboardShortcut("k", modifiers: .command)
            }
            CommandGroup(replacing: .help) {
                Button("Orchard Documentation") {
                    if let url = URL(string: "https://github.com/andrew-waters/orchard") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
        }



        WindowGroup(id: "logs", for: LogTarget.self) { $target in
            MultiLogView(initialTarget: target)
                .injectServices(services)
                .modifier(ReduceMotionModifier())
        }
        .defaultSize(width: 900, height: 600)
        .windowToolbarStyle(.unified(showsTitle: false))

        MenuBarExtra {
            MenuBarView()
                .injectServices(services)
                .modifier(ReduceMotionModifier())
        } label: {
            SwiftUI.Image("MenuBarLogo")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 18, height: 18)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .injectServices(services)
                .environmentObject(updater)
                .modifier(ReduceMotionModifier())
        }
    }
}

/// Injects every per-domain service as an environment object at a scene root.
extension View {
    func injectServices(_ s: AppServices) -> some View {
        environmentObject(s.alertCenter)
            .environmentObject(s.settings)
            .environmentObject(s.terminalLauncher)
            .environmentObject(s.builderService)
            .environmentObject(s.networkService)
            .environmentObject(s.volumeService)
            .environmentObject(s.imageService)
            .environmentObject(s.imageBuildService)
            .environmentObject(s.statsService)
            .environmentObject(s.powerEvents)
            .environmentObject(s.dnsService)
            .environmentObject(s.systemService)
            .environmentObject(s.diskPurgeService)
            .environmentObject(s.containerListService)
            .environmentObject(s.machineService)
            .environmentObject(s.clusterService)
            .environmentObject(s.composeService)
            .environmentObject(s.composePluginService)
            .environmentObject(s.containerInstallService)
            .environmentObject(s.onboarding)
            .environmentObject(s.modelService)
            .environmentObject(s.modelServerService)
            .environmentObject(s.rosettaService)
    }
}

class MenuBarManager: ObservableObject {
    // Manager for menu bar state if needed
}

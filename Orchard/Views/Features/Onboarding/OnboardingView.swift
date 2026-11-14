import AppKit
import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var onboarding: OnboardingCoordinator
    @EnvironmentObject var installer: ContainerInstallService
    @EnvironmentObject var plugin: ComposePluginService
    @State private var showingDetails = false
    @State private var showingManual = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label("ContainerDesk Setup", systemImage: "shippingbox")
                .font(.title.weight(.semibold))
            content
            Spacer(minLength: 10)
            Divider()
            HStack {
                Button("What gets installed?") { showingDetails = true }
                Spacer()
                if !isBusy { Button("Quit") { NSApplication.shared.terminate(nil) } }
            }
        }
        .padding(32)
        .frame(maxWidth: 720, maxHeight: .infinity, alignment: .topLeading)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $showingManual) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Manual installation").font(.title2)
                Text("Download Apple's signed package, then run:")
                Text(ContainerInstallService.manualCommands).font(.system(.body, design: .monospaced)).textSelection(.enabled)
                HStack {
                    Link("Download and instructions", destination: ContainerInstallService.instructionsURL)
                    Button("Copy Commands") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(ContainerInstallService.manualCommands, forType: .string)
                    }
                    Spacer()
                    Button("Done") { showingManual = false }
                }
            }.padding().frame(width: 530)
        }
        .sheet(isPresented: $showingDetails) {
            VStack(alignment: .leading, spacing: 12) {
                Text("What gets installed?").font(.title2)
                Text("Apple's signed container Runtime is installed under /usr/local. The optional community Compose plugin enables the terminal command; Compose projects work in ContainerDesk without it.")
                Button("Done") { showingDetails = false }
            }.padding().frame(width: 480)
        }
    }

    private var isBusy: Bool {
        switch onboarding.stage {
        case .checking, .installing, .starting, .verifying, .pluginInstalling: return true
        default: return false
        }
    }

    @ViewBuilder private var content: some View {
        switch onboarding.stage {
        case .welcome:
            heading("Welcome to ContainerDesk", "Run Linux containers and Compose projects on your Mac using Apple's container Runtime.")
            Button("Get Started") { onboarding.begin() }.buttonStyle(.borderedProminent).accessibilityIdentifier("onboarding-begin")
        case .checking:
            ProgressView("Checking for Apple container…")
        case .install:
            heading("Install Apple container", "ContainerDesk uses Apple's open-source Runtime. Version \(supportedContainerVersion) is installed under /usr/local after verifying Apple's signature.")
            Text("macOS will ask for an administrator password. ContainerDesk never sees your password.").foregroundStyle(.secondary)
            HStack {
                Button("Install") { onboarding.install() }.buttonStyle(.borderedProminent).accessibilityIdentifier("onboarding-install")
                manualLink
            }
        case .installing:
            Text("Installing Apple container").font(.headline)
            ForEach(ContainerInstallService.Step.allCases, id: \.rawValue) { step in
                HStack {
                    if installer.currentStep == step { ProgressView().controlSize(.small) }
                    else if let current = installer.currentStep, step.rawValue < current.rawValue { SwiftUI.Image(systemName: "checkmark.circle.fill").foregroundStyle(.green) }
                    else { SwiftUI.Image(systemName: "circle").foregroundStyle(.secondary) }
                    Text(step.title)
                    if installer.currentStep == step, let note = step.note { Text(note).foregroundStyle(.secondary) }
                }
            }
            if installer.canCancel { Button("Cancel") { onboarding.cancelInstallation() } }
        case .start:
            heading("Start Apple container", "The Runtime is installed but not running. Start it now? Your choice is remembered for future starts.")
            Button("Start") { onboarding.start() }.buttonStyle(.borderedProminent).accessibilityIdentifier("onboarding-start")
            manualLink
        case .starting:
            ProgressView("Starting the Runtime…")
        case .older(let version):
            heading("An older Runtime is installed", "Version \(version) is older than \(supportedContainerVersion). Upgrade is recommended; supported features can continue with version gates.")
            HStack {
                Button("Upgrade") { onboarding.install() }.buttonStyle(.borderedProminent)
                Button("Continue") { onboarding.continueVersion() }.accessibilityIdentifier("onboarding-continue-version")
            }
        case .newer(let version):
            heading("A newer Runtime is installed", "Version \(version) is newer than the version linked with ContainerDesk. Continue if you want to try it; some features may not work.")
            Button("Continue Anyway") { onboarding.continueVersion() }.buttonStyle(.borderedProminent).accessibilityIdentifier("onboarding-continue-version")
        case .blocked(let version):
            heading("Runtime version not supported", "ContainerDesk works with Apple container 1.x. Version \(version) is installed. Change it manually; ContainerDesk will not downgrade it.")
            manualLink
        case .verifying:
            ProgressView("Verifying the Runtime…")
            Text("Checking service response, container and image lists, and version compatibility.").foregroundStyle(.secondary)
        case .plugin:
            heading("Compose in Terminal (optional)", "Compose projects work in ContainerDesk without a plugin. Install the community plugin to use container compose in Terminal. Version \(ComposePluginService.linkedVersion) is verified with a pinned SHA-256 before installation.")
            HStack {
                Button("Install Plugin") { onboarding.installPlugin() }.buttonStyle(.borderedProminent)
                Button("Skip") { onboarding.skipPlugin() }.accessibilityIdentifier("onboarding-skip-plugin")
            }
        case .pluginInstalling:
            ProgressView(plugin.currentStep?.title ?? "Installing the optional plugin…")
        case .done:
            heading("You're set up", "The Runtime is ready. You can run a container or open a Compose project from Overview.")
            HStack {
                Button("Go to Overview") { onboarding.finish() }.buttonStyle(.borderedProminent).accessibilityIdentifier("onboarding-finish")
                Button("Run nginx") { onboarding.finish(action: .nginx) }
                Button("Open Compose Project") { onboarding.finish(action: .compose) }
            }
        case .failure(let message):
            heading("Setup needs attention", message)
            HStack {
                Button("Retry") { onboarding.retry() }.buttonStyle(.borderedProminent)
                if onboarding.pluginFailed { Button("Skip Plugin") { onboarding.skipPlugin() } }
                if message.localizedCaseInsensitiveContains("not signed") {
                    Link("Report a Problem", destination: URL(string: "https://github.com/andrew-waters/orchard/issues/new")!)
                }
                Button("Open Console") {
                    if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Console") {
                        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
                    }
                }
                manualLink
            }
        }
    }

    private func heading(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.title2.weight(.medium))
            Text(detail).fixedSize(horizontal: false, vertical: true)
        }
    }

    private var manualLink: some View {
        Button("Manual instructions…") { showingManual = true }
    }
}

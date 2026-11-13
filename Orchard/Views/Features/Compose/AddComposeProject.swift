import AppKit
import ComposeModel
import SwiftUI
import UniformTypeIdentifiers

/// Choosing a compose file. Main-actor, because a panel is a window.
@MainActor
enum ComposeAddFlow {
    static func present(service: ComposeService) {
        let panel = NSOpenPanel()
        panel.message = "Choose a Compose file or folder"
        panel.prompt = "Choose"
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        var types: [UTType] = [.yaml]
        if let yml = UTType(filenameExtension: "yml") { types.append(yml) }
        panel.allowedContentTypes = types
        guard panel.runModal() == .OK, let url = panel.url else { return }
        service.beginAdd(selectionURL: url)
    }
}

/// What a file asks for that Orchard will not do, put in front of someone before anything is
/// created.
///
/// The plugin refuses a file like this outright, because a command in a script has nobody to
/// ask. A window does have somebody to ask, so this asks, and the project then carries what
/// was accepted for as long as it exists. Three weeks later nobody remembers what they agreed
/// to, and the containers cannot tell them.
struct ComposeReviewSheet: View {
    @EnvironmentObject var composeService: ComposeService
    @Environment(\.dismiss) private var dismiss

    @State private var acknowledgedBehavioural = false

    let preview: ComposeFilePreview
    /// True when the project is already known and the file has simply moved on.
    let isRevision: Bool

    private var blocking: [Finding] { preview.blockingFindings }
    private var cosmetic: [Finding] { preview.cosmeticFindings }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if !blocking.isEmpty {
                        section(
                            title: "Will not be honoured",
                            note: "These change what your services do. ContainerDesk will create everything else and leave these out.",
                            findings: blocking,
                            tint: .orange
                        )
                    }
                    if !cosmetic.isEmpty {
                        section(
                            title: "Ignored",
                            note: "Read and stepped over. Nothing about the running services depends on them.",
                            findings: cosmetic,
                            tint: .secondary
                        )
                    }
                    if !preview.warnings.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Variables with no value")
                                .font(.headline)
                            Text("Substituted with an empty string, which is what compose does.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            ForEach(preview.warnings) { warning in
                                Text(warning.message)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                            }
                        }
                    }
                    if blocking.isEmpty && cosmetic.isEmpty && preview.warnings.isEmpty {
                        Label(
                            "Everything in this file is supported.",
                            systemImage: "checkmark.circle"
                        )
                        .foregroundStyle(.green)
                    }
                    servicesSection
                    differencesSection
                }
                .padding()
            }
            Divider()
            footer
        }
        .frame(width: 620, height: 460)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(preview.identity.name)
                .font(.title2.weight(.semibold))
            Text(preview.fileURL.path)
                .font(.caption)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
    }

    private func section(title: String, note: String, findings: [Finding], tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(note)
                .font(.caption)
                .foregroundStyle(.secondary)
            ForEach(findings) { finding in
                HStack(alignment: .top, spacing: 8) {
                    SwiftUI.Image(systemName: finding.severity == .behavioural ? "exclamationmark.triangle.fill" : "minus.circle")
                        .foregroundStyle(tint)
                        .font(.caption)
                        .padding(.top, 2)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("\(finding.supportLabel) · \(preview.fileURL.lastPathComponent):\(finding.mark?.description ?? "location unavailable")")
                            .font(.caption.weight(.semibold))
                        Text(finding.message)
                            .font(.callout)
                            .accessibilityIdentifier("compose-finding-\(finding.key)")
                        if let suggestion = ComposeImportPolicy.suggestion(for: finding.key) {
                            Text("Suggestion: \(suggestion)").font(.caption)
                                .accessibilityIdentifier("compose-suggestion-\(finding.key)")
                        }
                    }
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var servicesSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Services")
                .font(.headline)
            ForEach(preview.file.orderedServices) { service in
                VStack(alignment: .leading, spacing: 3) {
                    Text(service.name).font(.subheadline.weight(.medium))
                    Text("Ports: \(service.ports.isEmpty ? "None" : service.ports.map(\.description).joined(separator: ", "))")
                    Text("Networks: \(service.networks.isEmpty ? "Default" : service.networks.joined(separator: ", "))")
                    Text("Volumes: \(service.mounts.isEmpty ? "None" : service.mounts.map(\.description).joined(separator: ", "))")
                }
                .font(.callout)
                .textSelection(.enabled)
            }
        }
    }

    private var differencesSection: some View {
        DisclosureGroup("Differences from Docker Compose") {
            VStack(alignment: .leading, spacing: 5) {
                Text("Services use <project>-<service> names, with the DNS domain when configured.")
                Text("Dependencies start first, but readiness is not checked.")
                Text("Volumes attach to one container at a time; use a bind mount to share files. They contain lost+found; set PostgreSQL PGDATA to a subdirectory.")
                Text("Anonymous volumes survive Down and are reused. Each container has its own IP; published ports are available on localhost.")
                Text("Restart policies and health checks are not supported.")
            }.font(.callout).padding(.top, 4)
        }
    }

    private var footer: some View {
        VStack(alignment: .leading) {
            if !blocking.isEmpty {
                Toggle("I understand these behavioural differences", isOn: $acknowledgedBehavioural)
                    .accessibilityIdentifier("compose-acknowledge")
            }
            HStack {
            Spacer()
            Button("Cancel") { dismiss() }
                .keyboardShortcut(.cancelAction)
            Button(addTitle) {
                if isRevision {
                    composeService.acknowledgeFindings(for: preview.identity.name)
                } else {
                    composeService.add(preview)
                    composeService.selectedProject = preview.identity.name
                }
                composeService.clearPendingPreview()
                dismiss()
            }
            .keyboardShortcut(.defaultAction)
            .disabled(!blocking.isEmpty && !acknowledgedBehavioural)
            .accessibilityIdentifier("compose-confirm-import")
            }
        }
        .padding()
    }

    private var addTitle: String {
        if isRevision { return blocking.isEmpty ? "Got It" : "Accept Changes" }
        return blocking.isEmpty ? "Add Project" : "Add Anyway"
    }
}

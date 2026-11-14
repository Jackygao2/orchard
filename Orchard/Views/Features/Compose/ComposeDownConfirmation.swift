import ComposePlanner
import SwiftUI

struct VolumeRemovalRequest: Identifiable {
    let id = UUID()
    let project: ComposeProject
    let names: [String]
    let message: String
}

struct ComposeDownConfirmation: ViewModifier {
    @Binding var request: VolumeRemovalRequest?
    @EnvironmentObject var composeService: ComposeService

    func body(content: Content) -> some View {
        content.confirmationDialog("Remove project volumes?", isPresented: Binding(
            get: { request != nil }, set: { if !$0 { request = nil } }
        ), presenting: request) { request in
            if !request.names.isEmpty {
                Button("Remove Volumes", role: .destructive) {
                    Task { await composeService.down(project: request.project, options: DownOptions(removeVolumes: true), confirmedVolumes: Set(request.names)) }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: { request in
            Text(request.message)
        }
    }
}

enum ComposeDown {
    static func isAvailable(for project: ComposeProject, volumes: [ContainerVolume]) -> Bool {
        !project.containers.isEmpty || !ComposeProjectVolume.labelled(project.name, in: volumes).isEmpty
    }

    static func removalRequest(project: ComposeProject, volumes: [ContainerVolume], containers: [Container], sizes: [String: MeasuredSize]) -> VolumeRemovalRequest {
        let projectIDs = Set(project.containers.map(\.configuration.id))
        let eligible = volumes.filter { volume in
            VolumeUsage.composeProject(of: volume) == project.name &&
                VolumeUsage.users(of: volume, in: containers).allSatisfy { projectIDs.contains($0.configuration.id) }
        }.sorted { $0.name < $1.name }
        let lines = eligible.map { volume -> String in
            let size: String
            if case .known(let bytes) = sizes[volume.name] { size = ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file) }
            else { size = "size unavailable" }
            return "\(volume.name) — \(size)"
        }
        let message = lines.isEmpty ? "No eligible project volumes were found." :
            "Down will remove the project's containers and these volumes and their data permanently:\n" + lines.joined(separator: "\n") + "\nVolumes used by other containers are kept."
        return VolumeRemovalRequest(project: project, names: eligible.map(\.name), message: message)
    }

    @MainActor
    static func request(_ project: ComposeProject, composeService: ComposeService, volumeService: VolumeService, pending: Binding<VolumeRemovalRequest?>) {
        Task { await composeService.down(project: project) }
    }

    @MainActor
    static func requestRemoval(_ project: ComposeProject, volumeService: VolumeService, pending: Binding<VolumeRemovalRequest?>) {
        Task {
            guard await volumeService.load(showLoading: true, readsContainers: true) else { return }
            let request = removalRequest(project: project, volumes: volumeService.volumes, containers: volumeService.containers, sizes: volumeService.sizes)
            pending.wrappedValue = request
        }
    }
}

extension View {
    func composeDownConfirmation(_ request: Binding<VolumeRemovalRequest?>) -> some View {
        modifier(ComposeDownConfirmation(request: request))
    }
}

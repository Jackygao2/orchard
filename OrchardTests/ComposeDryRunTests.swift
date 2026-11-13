import ComposePlanner
import Foundation
import Testing
@testable import Orchard

@Suite("Compose dry run")
@MainActor
struct ComposeDryRunTests {
    @Test("Plans read fresh state and do not mutate the backend")
    func snapshotsAreReadOnly() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("compose.yaml")
        try """
        name: shop
        services:
          web:
            image: nginx
            volumes: ["data:/data"]
        volumes:
          data:
        """.write(to: file, atomically: true, encoding: .utf8)
        let backend = MockContainerBackend()
        let service = ComposeService(backend: backend, buildService: nil, alertCenter: AlertCenter(),
                                     persistence: ComposeProjectsPersistence(fileURL: root.appendingPathComponent("records.json")))
        service.add(try service.preview(fileURL: file))
        let project = try #require(ComposeProject.group(containers: [], records: service.records).first)
        let first = try #require(await service.dryRun(project: project))
        #expect(first.operations.contains { if case .pullImage = $0 { return true }; return false })
        #expect(first.operations.contains { if case .createVolume = $0 { return true }; return false })
        backend.images = [makeImage(reference: "docker.io/library/nginx:latest")]
        let second = try #require(await service.dryRun(project: project))
        #expect(!second.operations.contains { if case .pullImage = $0 { return true }; return false })
        #expect(backend.listContainersCount == 2)
        #expect(backend.pulledReferences.isEmpty)
        #expect(backend.createdNetworks.isEmpty && backend.deletedNetworkIds.isEmpty)
        #expect(backend.createdVolumes.isEmpty && backend.deletedVolumeNames.isEmpty)
        #expect(backend.createdSpecs.isEmpty && backend.deletedContainers.isEmpty)
        #expect(backend.stoppedContainers.isEmpty && backend.bootstrapAndStartCount == 0)
        #expect(backend.ranProcesses.isEmpty && service.run == nil)
    }
}

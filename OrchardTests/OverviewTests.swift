import Foundation
import Testing
@testable import Orchard

@MainActor
@Test("Overview counts and activity reflect observed state changes")
func overviewCountsAndTransitions() throws {
    let service = ContainerListService(backend: MockContainerBackend(), alertCenter: AlertCenter())
    let running = try makeContainer(id: "web", status: "running")
    let stopped = try makeContainer(id: "db", status: "stopped")
    service.containers = [running, stopped]
    #expect(service.recentActivity.isEmpty)
    let counts = OverviewCounts(containers: service.containers, imageCount: 2, projectCount: 3, volumeCount: 4)
    #expect(counts.running == 1 && counts.stopped == 1 && counts.images == 2 && counts.projects == 3 && counts.volumes == 4)
    service.containers = [try makeContainer(id: "web", status: "stopped"), stopped]
    #expect(service.recentActivity.count == 1)
    #expect(service.recentActivity.first?.containerID == "web")
    #expect(service.recentActivity.first?.from == "running")
    #expect(service.recentActivity.first?.to == "stopped")
    service.containers = [stopped]
    #expect(service.recentActivity.count == 1)
}

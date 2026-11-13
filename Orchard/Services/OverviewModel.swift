import Foundation

struct ContainerTransition: Identifiable, Equatable {
    let id: UUID
    let containerID: String
    let from: String
    let to: String
    let observedAt: Date
}

struct OverviewCounts: Equatable {
    let running: Int
    let stopped: Int
    let images: Int
    let projects: Int
    let volumes: Int

    init(containers: [Container], imageCount: Int, projectCount: Int, volumeCount: Int) {
        running = containers.filter { $0.status.lowercased() == "running" }.count
        stopped = containers.filter { $0.status.lowercased() == "stopped" }.count
        images = imageCount
        projects = projectCount
        volumes = volumeCount
    }
}

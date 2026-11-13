import SwiftUI

struct NewerVersionView: View {
    @EnvironmentObject var systemService: SystemService
    var body: some View {
        VStack(spacing: 30) {
            SwiftUI.Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundColor(.orange)

            VStack(spacing: 16) {
                Text("Container's Version is not yet supported")
                    .font(.title)
                    .fontWeight(.semibold)

                if let installedVersion = systemService.parsedContainerVersion {
                    Text("We require Apple Container version \(systemService.parsedContainerVersion ?? "unknown"), but you are running version \(installedVersion)")
                        .padding(.horizontal)
                        .multilineTextAlignment(.center)
                } else if let rawVersion = systemService.containerVersion {
                    Text("Detected version: \(rawVersion)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                        .multilineTextAlignment(.center)

                    Text("We require Apple Container version \(systemService.parsedContainerVersion ?? "unknown")")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else {
                    Text("We require Apple Container version \(systemService.parsedContainerVersion ?? "unknown")")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Text("Check for a newer ContainerDesk download.")
                    .font(.body)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            HStack(spacing: 16) {
                Button("Proceed Anyway") {
                    Task { @MainActor in
                        await systemService.checkSystemStatusIgnoreVersion()
                    }
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .task {
            await systemService.checkSystemStatus()
        }
    }
}

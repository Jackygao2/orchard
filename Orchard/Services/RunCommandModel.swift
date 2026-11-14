import Foundation

/// One non-interactive process. Closing or cancelling stops waiting, not necessarily the
/// process: the Runtime may have already accepted it and may not support interruption.
@MainActor
final class RunCommandModel: ObservableObject {
    enum Phase: Equatable { case idle, running, exited(Int32), failed(String), cancelled }
    @Published private(set) var phase: Phase = .idle
    @Published private(set) var output = ""
    private let backend: ContainerBackend
    private var task: Task<Void, Never>?
    private var generation: UInt64 = 0

    init(backend: ContainerBackend) { self.backend = backend }

    func start(containerID: String, input: String) {
        guard phase != .running else { return }
        guard let arguments = TerminalLauncher.shellArguments(input), !arguments[0].isEmpty else {
            phase = .failed("Enter a command with balanced quotes and escapes.")
            return
        }
        generation &+= 1
        let runID = generation
        output = ""
        phase = .running
        let backend = self.backend
        task = Task {
            do {
                let status = try await backend.runProcess(in: containerID, command: arguments, environment: [], workingDirectory: nil, user: nil) { [weak self] line in
                    Task { @MainActor [weak self] in
                        guard let self, self.generation == runID else { return }
                        self.output += line + "\n"
                    }
                }
                guard generation == runID else { return }
                phase = .exited(status)
            } catch {
                guard generation == runID else { return }
                phase = .failed(error.localizedDescription)
            }
            task = nil
        }
    }

    func cancel() {
        guard phase == .running else { return }
        generation &+= 1
        task?.cancel()
        task = nil
        phase = .cancelled
    }
}

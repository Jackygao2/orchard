import Foundation
import Testing
@testable import Orchard

@MainActor
@Test("Run Command sends literal arguments and shows streamed output and exit status")
func runCommandArguments() async {
    let backend = MockContainerBackend()
    backend.runProcessHandler = { _, output in output("line one"); return 7 }
    let model = RunCommandModel(backend: backend)
    model.start(containerID: "web", input: "echo 'a b' '; touch /tmp/nope' \"$(unsafe)\"")
    for _ in 0..<100 where model.phase == .running { await Task.yield() }
    for _ in 0..<100 where model.output.isEmpty { await Task.yield() }
    #expect(backend.ranProcesses.first?.command == ["echo", "a b", "; touch /tmp/nope", "$(unsafe)"])
    #expect(model.phase == .exited(7))
    #expect(model.output.contains("line one"))
    model.start(containerID: "web", input: "echo 'unfinished")
    if case .failed = model.phase {} else { Issue.record("Expected input error") }
    #expect(backend.ranProcesses.count == 1)
}

@MainActor
@Test("Stop Waiting ignores a late process result")
func runCommandCancellation() async {
    let backend = MockContainerBackend()
    let entered = TestGate()
    let release = TestGate()
    backend.runProcessAsyncHandler = { _, output in
        entered.open()
        await release.wait()
        output("late")
        return 0
    }
    let model = RunCommandModel(backend: backend)
    model.start(containerID: "web", input: "echo test")
    await entered.wait()
    model.cancel()
    release.open()
    for _ in 0..<10 { await Task.yield() }
    #expect(model.phase == .cancelled)
    #expect(model.output.isEmpty)
}

@MainActor
@Test("Backend failures are reported without treating the command as successful")
func runCommandBackendFailure() async {
    let backend = MockContainerBackend()
    backend.runProcessHandler = { _, _ in throw NotConfigured() }
    let model = RunCommandModel(backend: backend)
    model.start(containerID: "web", input: "false")
    for _ in 0..<100 where model.phase == .running { await Task.yield() }
    if case .failed(let message) = model.phase { #expect(!message.isEmpty) }
    else { Issue.record("Expected backend failure") }
}

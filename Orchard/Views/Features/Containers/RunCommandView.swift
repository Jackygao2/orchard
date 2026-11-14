import SwiftUI

struct RunCommandView: View {
    let containerID: String
    @StateObject var model: RunCommandModel
    @Environment(\.dismiss) private var dismiss
    @State private var input = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Run Command in \(containerID)").font(.title2.weight(.semibold))
            Text("Runs a non-interactive process. Arguments support quotes; shell operators are literal unless you explicitly run a shell.")
                .foregroundStyle(.secondary)
            TextField("Command and arguments", text: $input)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("run-command-input")
                .disabled(model.phase == .running)
            ScrollView {
                Text(model.output.isEmpty ? "Output appears here." : model.output)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("run-command-output")
            }.frame(minHeight: 150)
            status
            HStack {
                if model.phase == .running {
                    Button("Stop Waiting") { model.cancel() }
                        .help("The process may continue in the container")
                }
                Spacer()
                Button("Close") { model.cancel(); dismiss() }.keyboardShortcut(.cancelAction)
                Button("Run") { model.start(containerID: containerID, input: input) }
                    .keyboardShortcut(.defaultAction)
                    .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.phase == .running)
                    .accessibilityIdentifier("run-command-submit")
            }
        }
        .padding()
        .frame(width: 600, height: 380)
        .onDisappear { model.cancel() }
    }

    @ViewBuilder private var status: some View {
        switch model.phase {
        case .idle: EmptyView()
        case .running: Label("Running…", systemImage: "hourglass")
        case .exited(let code): Text(code == 0 ? "Completed successfully." : "Exited with status \(code).")
        case .failed(let message): Text("Could not run command: \(message)").foregroundStyle(.red)
        case .cancelled: Text("Stopped waiting. The process may still be running in the container.").foregroundStyle(.secondary)
        }
    }
}

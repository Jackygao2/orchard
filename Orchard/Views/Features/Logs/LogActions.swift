import AppKit
import SwiftUI

/// Copy selected text or the visible filtered lines; export always saves visible filtered lines.
struct LogActions: View {
    let lines: [String]
    let selectedText: String
    @State private var errorMessage: String?
    @State private var showError = false

    var body: some View {
        HStack {
            Button("Copy") {
                let text = selectedText.isEmpty ? LogExport.text(lines) : selectedText
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(text, forType: .string)
            }
            .accessibilityIdentifier("logs-copy")
            .disabled(lines.isEmpty)
            Button("Export…") { export() }
                .keyboardShortcut("e", modifiers: [.command, .shift])
                .accessibilityIdentifier("logs-export")
                .disabled(lines.isEmpty)
        }
        .alert("Could not export logs", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: { Text(errorMessage ?? "Please try another location.") }
    }

    private func export() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "container-logs.log"
        panel.allowedContentTypes = [.init(filenameExtension: "log") ?? .plainText]
        guard panel.runModal() == .OK, let destination = panel.url else { return }
        let text = LogExport.text(lines)
        Task {
            do { try await Task.detached { try LogExport.write(text, to: destination) }.value }
            catch { errorMessage = error.localizedDescription; showError = true }
        }
    }
}

enum LogExport {
    static func text(_ lines: [String]) -> String { lines.map(ANSIText.plain).joined(separator: "\n") }
    nonisolated static func write(_ text: String, to destination: URL) throws {
        try text.write(to: destination, atomically: true, encoding: .utf8)
    }
}

import AppKit

@MainActor
enum ComposeFileActions {
    static func open(_ file: URL, alertCenter: AlertCenter,
                     exists: (String) -> Bool = FileManager.default.fileExists,
                     opener: (URL) -> Bool = { NSWorkspace.shared.open($0) }) {
        guard exists(file.path) else {
            alertCenter.error("The Compose file is missing. Restore it or add the project again.")
            return
        }
        guard opener(file) else {
            alertCenter.error("Could not open the Compose file. Choose an editor with Open With… or check its installation.")
            return
        }
    }

    static func reveal(_ file: URL, alertCenter: AlertCenter,
                       exists: (String) -> Bool = FileManager.default.fileExists,
                       reveal: (URL) -> Void = { NSWorkspace.shared.activateFileViewerSelecting([$0]) }) {
        guard exists(file.path) else {
            alertCenter.error("The Compose file is missing. Restore it or add the project again.")
            return
        }
        reveal(file)
    }

    static func chooseEditor(for file: URL, alertCenter: AlertCenter) {
        guard FileManager.default.fileExists(atPath: file.path) else {
            alertCenter.error("The Compose file is missing. Restore it or add the project again.")
            return
        }
        let panel = NSOpenPanel()
        panel.message = "Choose an editor"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.application]
        guard panel.runModal() == .OK, let editor = panel.url else { return }
        NSWorkspace.shared.open([file], withApplicationAt: editor, configuration: NSWorkspace.OpenConfiguration()) { _, error in
            if let error {
                Task { @MainActor in
                    alertCenter.error("Could not open the editor: \(error.localizedDescription). Choose another editor with Open With…")
                }
            }
        }
    }
}

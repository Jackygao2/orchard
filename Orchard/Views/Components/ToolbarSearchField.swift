import AppKit
import SwiftUI

struct ToolbarSearchField: NSViewRepresentable {
    @Binding var text: String

    func makeCoordinator() -> Coordinator { Coordinator(text: $text) }

    func makeNSView(context: Context) -> NSSearchField {
        let field = NSSearchField()
        field.placeholderString = "Search"
        field.setAccessibilityIdentifier("toolbar-search")
        field.delegate = context.coordinator
        context.coordinator.field = field
        return field
    }

    func updateNSView(_ field: NSSearchField, context: Context) {
        context.coordinator.text = $text
        if field.stringValue != text { field.stringValue = text }
    }

    final class Coordinator: NSObject, NSSearchFieldDelegate {
        var text: Binding<String>
        weak var field: NSSearchField?
        private var observer: NSObjectProtocol?

        init(text: Binding<String>) {
            self.text = text
            super.init()
            observer = NotificationCenter.default.addObserver(
                forName: NSNotification.Name("FocusNavigationSearch"), object: nil, queue: .main
            ) { [weak self] _ in
                guard let field = self?.field, let window = field.window, window.isKeyWindow else { return }
                window.makeFirstResponder(field)
            }
        }

        deinit {
            if let observer { NotificationCenter.default.removeObserver(observer) }
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSSearchField else { return }
            text.wrappedValue = field.stringValue
        }
    }
}

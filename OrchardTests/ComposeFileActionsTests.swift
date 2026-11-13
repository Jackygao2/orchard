import Foundation
import Testing
@testable import Orchard

@Suite("Compose file actions") @MainActor
struct ComposeFileActionsTests {
    @Test func openAndReveal() {
        let url = URL(fileURLWithPath: "/tmp/example/compose.yaml")
        let alerts = AlertCenter()
        var opened: URL?
        var revealed: URL?
        ComposeFileActions.open(url, alertCenter: alerts, exists: { _ in true }, opener: { opened = $0; return true })
        ComposeFileActions.reveal(url, alertCenter: alerts, exists: { _ in true }, reveal: { revealed = $0 })
        #expect(opened == url && revealed == url && alerts.current == nil)
        ComposeFileActions.open(url, alertCenter: alerts, exists: { _ in false }, opener: { _ in Issue.record("Opened missing file"); return true })
        #expect(alerts.current?.message.contains("missing") == true)
        ComposeFileActions.open(url, alertCenter: alerts, exists: { _ in true }, opener: { _ in false })
        #expect(alerts.current?.message.contains("Choose an editor") == true)
    }
}

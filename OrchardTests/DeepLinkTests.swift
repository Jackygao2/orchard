import Foundation
import Testing
@testable import Orchard

private func link(_ string: String) -> DeepLink? {
    URL(string: string).flatMap(DeepLink.parse)
}

@Test("DeepLink: bare tab links resolve case-insensitively")
func deepLinkTabs() {
    #expect(link("containerdesk://containers") == .tab(.containers))
    #expect(link("containerdesk://Dashboard") == .tab(.dashboard))
    #expect(link("containerdesk://systemlogs") == .tab(.systemLogs))
    #expect(link("containerdesk://nonsense") == nil)
}

@Test("DeepLink: resource links carry their identifier")
func deepLinkResources() {
    #expect(link("containerdesk://container/web-1") == .container("web-1"))
    #expect(link("containerdesk://machine/dev-box") == .machine("dev-box"))
    #expect(link("containerdesk://dns/test.local") == .dnsDomain("test.local"))
    #expect(link("containerdesk://network/mynet") == .network("mynet"))
    #expect(link("containerdesk://mount/abc123") == .mount("abc123"))
}

@Test("DeepLink: image references keep interior slashes and tags")
func deepLinkImageReference() {
    #expect(link("containerdesk://image/docker.io/library/nginx:latest")
        == .image("docker.io/library/nginx:latest"))
}

@Test("DeepLink: a resource noun without an identifier falls back to its tab")
func deepLinkNounFallsBackToTab() {
    #expect(link("containerdesk://container") == .tab(.containers))
    #expect(link("containerdesk://container/") == .tab(.containers))
    #expect(link("containerdesk://image") == .tab(.images))
    #expect(link("containerdesk://dns") == .tab(.dns))
}

@Test("DeepLink: percent-encoded identifiers decode")
func deepLinkPercentDecoding() {
    #expect(link("containerdesk://container/web%2D1") == .container("web-1"))
}

@Test("DeepLink: foreign schemes are rejected")
func deepLinkForeignScheme() {
    #expect(link("https://container/web") == nil)
    #expect(link("docker://container/web") == nil)
    #expect(link("orchard://container/web") == nil)
}

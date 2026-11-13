import Foundation
import Testing
@testable import Orchard

@Test("Product persistence and secrets do not share Orchard's identity")
func productIdentityIsolation() {
    #expect(AppBrand.applicationSupportDirectory().lastPathComponent == "ContainerDesk")
    #expect(BuildsPersistence.defaultURL().deletingLastPathComponent() == AppBrand.applicationSupportDirectory())
    #expect(StatsPersistence.defaultURL().deletingLastPathComponent() == AppBrand.applicationSupportDirectory())
    #expect(ComposeProjectsPersistence.defaultURL().deletingLastPathComponent() == AppBrand.applicationSupportDirectory())
    #expect(KeychainSecretsStore().service == "local.containerdesk.model-api-keys")
    #expect(SandboxMarker.orchardOwner == "dev.andon.orchard")
    #expect(SandboxMarker.sandboxLabelKey == "com.orchard.sandbox")
}

@Test("Product bundle does not contain Orchard update configuration")
func productHasNoUpdateFeed() {
    #expect(Bundle.main.bundleIdentifier == "local.containerdesk")
    #expect(Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") == nil)
    #expect(Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") == nil)
}

@Test("Product credits preserve Orchard's copyright and license")
func productCredits() {
    #expect(AppBrand.orchardCredit.contains("Andrew Waters"))
    #expect(AppBrand.orchardCredit.contains("MIT License"))
}

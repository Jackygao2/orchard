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

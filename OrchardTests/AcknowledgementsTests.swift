import Foundation
import Testing
@testable import Orchard

@Test("Bundled acknowledgements cover all resolved packages and retain Orchard's licence")
func acknowledgementsCoverResolvedPackages() throws {
    let bundleURL = try #require(Bundle.main.url(forResource: "THIRD_PARTY_NOTICES", withExtension: "txt"))
    let text = try String(contentsOf: bundleURL, encoding: .utf8)
    let project = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    let path = project.appendingPathComponent("Orchard.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved")
    struct Resolved: Decodable { struct Pin: Decodable { let identity: String }; let pins: [Pin] }
    let pins = try JSONDecoder().decode(Resolved.self, from: Data(contentsOf: path)).pins
    #expect(text.contains("Copyright (c) 2026 Andrew Waters"))
    for pin in pins { #expect(text.contains("\n## \(pin.identity) "), "Missing \(pin.identity)") }
}

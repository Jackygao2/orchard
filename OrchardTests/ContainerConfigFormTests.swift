import Testing
import Foundation
@testable import Orchard

@MainActor
@Test("Editing prepopulates published port mappings")
func editFormPreservesPublishedPorts() throws {
    let ports = #"[{"hostPort":8080,"containerPort":80,"proto":"tcp","hostAddress":"127.0.0.1"}]"#
    let container = try makeContainer(id: "web", status: "stopped", environment: ["EMPTY=", "TOKEN=a=b"], publishedPortsJSON: ports)
    let config = EditContainerView.initialConfig(for: container)
    #expect(config.portMappings.count == 1)
    #expect(config.portMappings.first?.hostPort == "8080")
    #expect(config.portMappings.first?.containerPort == "80")
    #expect(config.portMappings.first?.hostAddress == "127.0.0.1")
    #expect(config.environmentVariables.contains { $0.key == "EMPTY" && $0.value == "" })
    #expect(config.environmentVariables.contains { $0.key == "TOKEN" && $0.value == "a=b" })
}
// Pure container-name validation extracted from the Run/Edit form.

@MainActor
@Test("Name validation: empty name is treated as not-yet-an-error")
func nameValidationEmpty() throws {
    #expect(ContainerConfigForm.validationError(for: "", existing: []) == nil)
}

@MainActor
@Test("Name validation: valid names (letters/digits/._- , starting alphanumeric) pass")
func nameValidationValid() {
    for name in ["web", "web-1", "my.app_2", "1container"] {
        #expect(ContainerConfigForm.validationError(for: name, existing: []) == nil, "\(name) should be valid")
    }
}

@MainActor
@Test("Name validation: illegal characters or leading punctuation are rejected")
func nameValidationIllegal() {
    for name in ["-web", ".app", "web!", "a b", "café"] {
        #expect(ContainerConfigForm.validationError(for: name, existing: []) != nil, "\(name) should be rejected")
    }
}

@MainActor
@Test("Name validation: names longer than 63 characters are rejected")
func nameValidationTooLong() {
    let ok = String(repeating: "a", count: 63)
    let tooLong = String(repeating: "a", count: 64)
    #expect(ContainerConfigForm.validationError(for: ok, existing: []) == nil)
    #expect(ContainerConfigForm.validationError(for: tooLong, existing: [])?.contains("63 characters") == true)
}

@MainActor
@Test("Name validation: a name matching an existing container is rejected")
func nameValidationDuplicate() throws {
    let existing = [try makeContainer(id: "web", status: "running")]
    #expect(ContainerConfigForm.validationError(for: "web", existing: existing)?.contains("already exists") == true)
    #expect(ContainerConfigForm.validationError(for: "other", existing: existing) == nil)
}

// MARK: - Labels

@Test("effectiveLabels: form rows merge over programmatic labels, trimmed, empty keys dropped")
func effectiveLabelsMerge() {
    var config = ContainerRunConfig(name: "t", image: "img")
    config.labels = ["com.orchard.sandbox": "true", "env": "prod"]
    config.labelPairs = [
        .init(key: "  team ", value: " infra "),
        .init(key: "env", value: "dev"),       // row wins over programmatic
        .init(key: "   ", value: "ignored"),   // empty key dropped
    ]

    let merged = config.effectiveLabels
    #expect(merged["team"] == "infra")
    #expect(merged["env"] == "dev")
    #expect(merged["com.orchard.sandbox"] == "true")
    #expect(merged.count == 3)
}

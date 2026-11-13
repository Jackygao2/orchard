import ComposeParser
import Foundation
import Testing
@testable import Orchard

@Suite("Compose import review")
struct ComposeImportTests {
    @Test("Folder discovery honors precedence and ignores directories")
    func discovery() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        #expect(throws: ComposeImportPolicy.ImportError.self) { try ComposeImportPolicy.resolve(folder) }
        for name in ComposeImportPolicy.filenames.reversed() {
            let file = folder.appendingPathComponent(name)
            try "services: {}".write(to: file, atomically: true, encoding: .utf8)
            #expect(try ComposeImportPolicy.resolve(folder) == file)
            #expect(try ComposeImportPolicy.resolve(file) == file)
        }
        try FileManager.default.removeItem(at: folder.appendingPathComponent("compose.yaml"))
        try FileManager.default.createDirectory(at: folder.appendingPathComponent("compose.yaml"), withIntermediateDirectories: false)
        #expect(try ComposeImportPolicy.resolve(folder).lastPathComponent == "compose.yml")
    }

    @Test("Known keys have suggestions without inventing one for unknown keys")
    func suggestions() {
        for key in ["restart", "healthcheck", "depends_on.condition", "user", "tmpfs", "extra_hosts", "network_mode", "networks", "secrets", "configs", "entrypoint", "profiles", "include"] {
            #expect(ComposeImportPolicy.suggestion(for: key) != nil)
        }
        #expect(ComposeImportPolicy.suggestion(for: "unknown") == nil)
    }

    @Test("Supported and unsupported fixtures use the linked parser")
    func fixtures() throws {
        let options = ParseOptions(projectDirectory: "/project", environment: [:], dotEnvPath: nil)
        let supported = try ComposeFileParser.parse(yaml: """
        services:
          web:
            image: nginx:alpine
            ports: ["8080:80"]
            depends_on: [db]
          db:
            image: postgres:16-alpine
            volumes: ["pgdata:/var/lib/postgresql/data"]
            environment:
              PGDATA: /var/lib/postgresql/data/pgdata
        volumes:
          pgdata:
        """, options: options)
        #expect(supported.file.orderedServices.map(\.name) == ["db", "web"])
        #expect(supported.findings.filter { $0.severity == .behavioural }.isEmpty)
        let unsupported = try ComposeFileParser.parse(yaml: """
        services:
          web:
            image: nginx
            restart: always
            user: "1000"
        """, options: options)
        let findings = unsupported.findings.filter { $0.severity == .behavioural }
        #expect(Set(findings.map(\.key)) == Set(["restart", "user"]))
        #expect(findings.allSatisfy { $0.service == "web" && $0.mark != nil && ComposeImportPolicy.suggestion(for: $0.key) != nil })
    }
}

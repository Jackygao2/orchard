import ComposeModel
import Foundation

enum ComposeImportPolicy {
    static let filenames = ["compose.yaml", "compose.yml", "docker-compose.yml", "docker-compose.yaml"]

    static func resolve(_ selection: URL, fileManager: FileManager = .default) throws -> URL {
        var directory: ObjCBool = false
        guard fileManager.fileExists(atPath: selection.path, isDirectory: &directory) else {
            throw ImportError.notFound(selection.path)
        }
        guard directory.boolValue else { return selection }
        for name in filenames {
            let candidate = selection.appendingPathComponent(name)
            var isDirectory: ObjCBool = false
            if fileManager.fileExists(atPath: candidate.path, isDirectory: &isDirectory), !isDirectory.boolValue {
                return candidate
            }
        }
        throw ImportError.noComposeFile(selection.path)
    }

    enum ImportError: LocalizedError {
        case notFound(String), noComposeFile(String)
        var errorDescription: String? {
            switch self {
            case .notFound(let path): return "Could not find \(path)."
            case .noComposeFile(let path): return "No Compose file found in \(path). Looked for compose.yaml, compose.yml, docker-compose.yml and docker-compose.yaml."
            }
        }
    }

    static func suggestion(for key: String) -> String? {
        switch key {
        case "restart": return "Apple container has no restart policy. Restart the service from ContainerDesk or a launchd job."
        case "healthcheck", "depends_on.condition": return "Dependencies start first but are not waited on. Add a retry or wait in the dependent service's start command."
        case "user": return "Set the user in the image (USER in the Dockerfile)."
        case "tmpfs": return "Mount a tmpfs from the container settings after creation, or use a volume."
        case "extra_hosts": return "Use a DNS domain in Settings and refer to services as <project>-<service>.<domain>."
        case "network_mode", "networks": return "Put the services on one shared network."
        case "secrets", "configs": return "Mount the file with a read-only bind mount."
        case "entrypoint": return "Set the entrypoint in the image, or put it in command."
        case "profiles", "include": return "Split into separate Compose files and import each."
        default: return nil
        }
    }
}

extension Finding {
    var supportLabel: String {
        switch support {
        case .unsupported: return "Not possible"
        case .deferred: return severity == .cosmetic ? "Ignored (cosmetic)" : "Not yet"
        default: return severity == .cosmetic ? "Ignored (cosmetic)" : "Not yet"
        }
    }
}

import Foundation

enum EnvironmentValuePolicy {
    static func isSecret(_ key: String) -> Bool {
        let normalized = key.uppercased()
        return ["PASSWORD", "SECRET", "TOKEN", "KEY"].contains { normalized.contains($0) }
    }

    static func parse(_ entry: String) -> (key: String, value: String)? {
        guard let separator = entry.firstIndex(of: "="), separator != entry.startIndex else { return nil }
        return (String(entry[..<separator]), String(entry[entry.index(after: separator)...]))
    }

    static func displayValue(key: String, value: String, revealed: Bool) -> String {
        isSecret(key) && !revealed ? "••••••••" : value
    }
}

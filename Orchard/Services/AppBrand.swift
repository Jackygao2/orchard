import Foundation

/// Product identity. Sandbox interoperability labels remain defined in Sandbox.swift.
enum AppBrand {
    static let name = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "ContainerDesk"
    static let bundleIdentifier = Bundle.main.bundleIdentifier ?? "local.containerdesk"
    static let urlScheme = Bundle.main.object(forInfoDictionaryKey: "ContainerDeskURLScheme") as? String ?? "containerdesk"
    static let keychainService = bundleIdentifier + ".model-api-keys"

    static func applicationSupportDirectory(fileManager: FileManager = .default) -> URL {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        return base.appendingPathComponent(name, isDirectory: true)
    }
}

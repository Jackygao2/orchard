import Foundation
import Testing
@testable import Orchard

@Test("Log export writes displayed text without terminal escape sequences")
func logExportContent() throws {
    let lines = ["\u{001B}[31mred\u{001B}[0m", "second line", ""]
    let text = LogExport.text(lines)
    #expect(text == "red\nsecond line\n")
    let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("log")
    defer { try? FileManager.default.removeItem(at: file) }
    try LogExport.write(text, to: file)
    #expect(try String(contentsOf: file, encoding: .utf8) == text)
}

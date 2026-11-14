import Foundation
import Testing
@testable import Orchard

@Test("TerminalLauncher: automation refusal points at System Settings")
func terminalLauncherNotAuthorizedMessage() {
    let error: NSDictionary = [
        NSAppleScript.errorNumber: -1743,
        NSAppleScript.errorAppName: "Terminal",
        NSAppleScript.errorBriefMessage: "Not authorized to send Apple events to Terminal.",
    ]
    let message = TerminalLauncher.userMessage(for: error)
    #expect(message.contains("Terminal"))
    #expect(message.contains("Privacy & Security"))
    #expect(message.contains("Automation"))
}

@Test("TerminalLauncher: privilege error is treated as an automation refusal")
func terminalLauncherPrivilegeErrorMessage() {
    let error: NSDictionary = [
        NSAppleScript.errorNumber: -10004,
        NSAppleScript.errorAppName: "iTerm2",
    ]
    let message = TerminalLauncher.userMessage(for: error)
    #expect(message.contains("iTerm2"))
    #expect(message.contains("Automation"))
}

@Test("TerminalLauncher: app-not-running errors suggest opening the app", arguments: [-600, -609])
func terminalLauncherAppNotRunningMessage(code: Int) {
    let error: NSDictionary = [
        NSAppleScript.errorNumber: code,
        NSAppleScript.errorAppName: "iTerm2",
    ]
    let message = TerminalLauncher.userMessage(for: error)
    #expect(message.contains("iTerm2"))
    #expect(message.contains("isn't running"))
}

@Test("TerminalLauncher: unknown errors fall back to the brief message")
func terminalLauncherUnknownErrorMessage() {
    let error: NSDictionary = [
        NSAppleScript.errorNumber: -2700,
        NSAppleScript.errorBriefMessage: "Some other failure.",
    ]
    let message = TerminalLauncher.userMessage(for: error)
    #expect(message.contains("Failed to open terminal"))
    #expect(message.contains("Some other failure."))
}

@Test("TerminalLauncher: missing error fields still produce a usable message, not the raw dictionary")
func terminalLauncherMissingFieldsMessage() {
    let error: NSDictionary = [NSAppleScript.errorNumber: -2700, "SomeInternalKey": "noise"]
    let message = TerminalLauncher.userMessage(for: error)
    #expect(message.contains("Failed to open terminal"))
    #expect(message.contains("-2700"))
    #expect(!message.contains("SomeInternalKey"))
}

@Test("Terminal arguments preserve literal shell metacharacters and quoted words")
func terminalLiteralArguments() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let executable = root.appendingPathComponent("fake container's binary")
    try "#!/bin/sh\nprintf '%s\\n' \"$@\"\n".write(to: executable, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)
    let marker = root.appendingPathComponent("injected")
    let shell = "bash -l ';touch \(marker.path)' \"a b\""
    let command = try #require(TerminalLauncher.containerCommand(binary: executable.path, containerID: "name' ; touch \(marker.path)", shell: shell))
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/sh")
    process.arguments = ["-c", command]
    let output = Pipe()
    process.standardOutput = output
    try process.run()
    process.waitUntilExit()
    let text = String(decoding: output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
    #expect(process.terminationStatus == 0)
    #expect(text.split(separator: "\n").map(String.init) == ["exec", "-it", "name' ; touch \(marker.path)", "bash", "-l", ";touch \(marker.path)", "a b"])
    #expect(!FileManager.default.fileExists(atPath: marker.path))
    #expect(TerminalLauncher.shellArguments("bash 'unfinished") == nil)
    #expect(TerminalLauncher.shellArguments("bash \"\"") == ["bash", ""])
}

@Test("AppleScript literal encodes line breaks outside string literals")
func terminalAppleScriptLineBreaks() {
    let literal = TerminalLauncher.appleScriptLiteral("one\ntwo\rthree")
    #expect(literal == "\"one\" & character id 10 & \"two\" & character id 13 & \"three\"")
    #expect(!SystemCommandRunner.adminScript(program: "/bin/echo", arguments: ["a\nb"]).contains("\n"))
}

@MainActor
@Test("First terminal use explains automation and offers a safe copy path")
func terminalAutomationExplanation() {
    let defaults = ephemeralDefaults()
    let settings = SettingsStore(alertCenter: AlertCenter(), defaults: defaults, secrets: InMemorySecretsStore())
    var prompts = 0
    var copied = ""
    var launched = 0
    let launcher = TerminalLauncher(settings: settings, alertCenter: AlertCenter(), defaults: defaults,
        confirmationOverride: { _ in prompts += 1; return prompts == 1 ? .alertSecondButtonReturn : .alertFirstButtonReturn },
        copyOverride: { copied = $0 }, launchCommandOverride: { _ in launched += 1 })
    launcher.openTerminal(for: "name;touch /tmp/nope")
    #expect(prompts == 1 && launched == 0)
    #expect(copied.contains("'name;touch /tmp/nope'"))
    launcher.openTerminal(for: "web")
    launcher.openTerminal(for: "web")
    #expect(prompts == 2 && launched == 2)
}

import Foundation
import Testing
@testable import Orchard

@Test("Published TCP ports build safe browser URLs")
func publishedPortBrowserURLs() {
    func port(_ host: String?, _ number: Int = 8080, _ proto: String = "tcp") -> PublishedPort {
        PublishedPort(hostPort: number, containerPort: 80, transportProtocol: proto, hostAddress: host)
    }
    #expect(port(nil).browserURL?.absoluteString == "http://localhost:8080")
    #expect(port("0.0.0.0").browserURL?.absoluteString == "http://localhost:8080")
    #expect(port("::").browserURL?.absoluteString == "http://localhost:8080")
    #expect(port("127.0.0.1").browserURL?.absoluteString == "http://127.0.0.1:8080")
    #expect(port("::1").browserURL?.absoluteString == "http://[::1]:8080")
    #expect(port("example.local").browserURL?.absoluteString == "http://example.local:8080")
    #expect(port("host@evil.example").browserURL == nil)
    #expect(port("bad/path").browserURL == nil)
    #expect(port("999.999.999.999").browserURL == nil)
    #expect(port(nil, 0).browserURL == nil)
    #expect(port(nil, 65536).browserURL == nil)
    #expect(port(nil, 8080, "udp").browserURL == nil)
}

@Test("Stopped containers do not offer browser actions for previously published ports")
func stoppedPortsAreNotOpenable() throws {
    let ports = #"[{"hostPort":8080,"containerPort":80,"proto":"tcp","hostAddress":"127.0.0.1"}]"#
    let running = try makeContainer(id: "web", status: "running", publishedPortsJSON: ports)
    let stopped = try makeContainer(id: "web", status: "stopped", publishedPortsJSON: ports)
    #expect(running.openablePorts.count == 1)
    #expect(stopped.openablePorts.isEmpty)
}

@Test("Uptime uses the Runtime start date only for running containers")
func containerUptime() throws {
    var container = try makeContainer(id: "web", status: "running")
    let now = Date(timeIntervalSince1970: 10_000)
    #expect(container.uptime(at: now) == nil)
    container.startedDate = now.addingTimeInterval(-120)
    #expect(container.uptime(at: now) == 120)
    container.startedDate = now.addingTimeInterval(60)
    #expect(container.uptime(at: now) == nil)
    var stopped = try makeContainer(id: "db", status: "stopped")
    stopped.startedDate = now.addingTimeInterval(-120)
    #expect(stopped.uptime(at: now) == nil)
    var other = try makeContainer(id: "other", status: "running")
    other.startedDate = now.addingTimeInterval(-60)
    container.startedDate = now.addingTimeInterval(-120)
    #expect(Container.uptimePrecedes(other, container, at: now, ascending: true))
    #expect(Container.uptimePrecedes(container, other, at: now, ascending: false))
    #expect(Container.uptimePrecedes(container, stopped, at: now, ascending: true))
    #expect(Container.uptimePrecedes(container, stopped, at: now, ascending: false))
}

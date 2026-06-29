import Foundation

/// In-memory mock store so the control UI is fully usable offline: actions flip
/// container state and append to the audit log, just like the real plane.
public actor MockControlStore {
	public static let shared = MockControlStore()

	private var containers: [DockerContainer]
	private var auditLog: [AuditEntry] = []

	init() { containers = MockControlStore.seed() }

	static func seed() -> [DockerContainer] {
		func c(_ name: String, _ image: String, running: Bool = true, controllable: Bool = true) -> DockerContainer {
			DockerContainer(id: String(name.prefix(12)), name: name, image: image,
			                state: running ? "running" : "exited",
			                status: running ? "Up 3 hours" : "Exited (0) 5 minutes ago",
			                controllable: controllable)
		}
		return [
			c("jellyfin", "linuxserver/jellyfin"),
			c("qbittorrent", "linuxserver/qbittorrent"),
			c("sonarr", "linuxserver/sonarr"),
			c("radarr", "linuxserver/radarr"),
			c("prowlarr", "linuxserver/prowlarr"),
			c("pihole", "pihole/pihole"),
			c("mosquitto", "eclipse-mosquitto"),
			c("zigbee2mqtt", "koenkk/zigbee2mqtt", running: false),
			c("dockerproxy", "tecnativa/docker-socket-proxy", controllable: false),
			c("caddy", "caddy", controllable: false),
		]
	}

	func list() -> [DockerContainer] { containers }

	func auditList() -> [AuditEntry] { auditLog }

	func perform(_ action: ContainerAction, on name: String) -> AuditEntry {
		if let idx = containers.firstIndex(where: { $0.name == name }) {
			switch action {
			case .start, .restart:
				containers[idx].state = "running"
				containers[idx].status = "Up 1 second"
			case .stop:
				containers[idx].state = "exited"
				containers[idx].status = "Exited (0) just now"
			}
		}
		let entry = AuditEntry(ts: Int(Date().timeIntervalSince1970), action: action.rawValue,
		                       container: name, result: "ok", actor: "mock")
		auditLog.insert(entry, at: 0)
		return entry
	}
}

public struct MockDockerControlClient: DockerControlProviding {
	public init() {}

	public func containers() async throws -> [DockerContainer] {
		await MockControlStore.shared.list()
	}

	public func logs(container: String, tail: Int) async throws -> String {
		"""
		[mock logs — \(container)]
		\(container) | Starting service…
		\(container) | Listening on :8080
		\(container) | Ready.
		"""
	}

	public func perform(_ action: ContainerAction, on container: String) async throws -> AuditEntry {
		await MockControlStore.shared.perform(action, on: container)
	}

	public func audit() async throws -> [AuditEntry] {
		await MockControlStore.shared.auditList()
	}
}

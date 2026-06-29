import Foundation

/// A controllable container as reported by `GET /api/docker/containers`.
public struct DockerContainer: Codable, Sendable, Equatable, Identifiable {
	public var id: String
	public var name: String
	public var image: String?
	public var state: String?        // running, exited, paused, …
	public var status: String?       // "Up 3 hours"
	public var controllable: Bool

	public init(id: String, name: String, image: String? = nil, state: String? = nil,
	            status: String? = nil, controllable: Bool = false) {
		self.id = id
		self.name = name
		self.image = image
		self.state = state
		self.status = status
		self.controllable = controllable
	}

	public var isRunning: Bool { state == "running" }
}

/// A lifecycle action the app can request.
public enum ContainerAction: String, Sendable, CaseIterable {
	case start, stop, restart

	public var label: String { rawValue.capitalized }
	public var systemImage: String {
		switch self {
		case .start: return "play.fill"
		case .stop: return "stop.fill"
		case .restart: return "arrow.clockwise"
		}
	}
}

/// An audit record returned by writes / `GET /api/docker/audit`.
public struct AuditEntry: Codable, Sendable, Equatable, Identifiable {
	public var ts: Int
	public var action: String
	public var container: String
	public var result: String
	public var actor: String

	public var id: String { "\(ts)-\(container)-\(action)" }
	public var date: Date { Date(timeIntervalSince1970: TimeInterval(ts)) }
	public var succeeded: Bool { result == "ok" }
}

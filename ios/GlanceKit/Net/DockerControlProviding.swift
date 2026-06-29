import Foundation

/// The Docker control plane, abstracted for live vs mock.
public protocol DockerControlProviding: Sendable {
	func containers() async throws -> [DockerContainer]
	func logs(container: String, tail: Int) async throws -> String
	func perform(_ action: ContainerAction, on container: String) async throws -> AuditEntry
	func audit() async throws -> [AuditEntry]
}

public enum ControlError: LocalizedError, Equatable {
	case notConfigured
	case forbidden(String)
	case http(Int, String)
	case transport(String)

	public var errorDescription: String? {
		switch self {
		case .notConfigured: return "Control plane not configured. Add a CONTROL_TOKEN in Settings."
		case .forbidden(let m): return m
		case .http(let code, let m): return m.isEmpty ? "HTTP \(code)" : m
		case .transport(let m): return m
		}
	}
}

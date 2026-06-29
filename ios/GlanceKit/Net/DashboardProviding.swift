import Foundation

/// Abstracts the source of dashboard snapshots so the UI can run against either
/// the live aggregator or bundled mock data without changing.
public protocol DashboardProviding: Sendable {
	/// Fetch the current dashboard snapshot.
	func fetch() async throws -> Dashboard
	/// Lightweight connectivity check (`GET /healthz`). Returns true when reachable.
	func testConnection() async -> Bool
}

/// Errors surfaced by the live client.
public enum DashboardError: LocalizedError, Equatable {
	case notConfigured
	case badURL
	case unauthorized
	case http(Int)
	case transport(String)

	public var errorDescription: String? {
		switch self {
		case .notConfigured: return "No server configured. Add a base URL and token in Settings."
		case .badURL: return "The configured base URL is invalid."
		case .unauthorized: return "Unauthorized — check your token."
		case .http(let code): return "Server returned HTTP \(code)."
		case .transport(let msg): return msg
		}
	}
}

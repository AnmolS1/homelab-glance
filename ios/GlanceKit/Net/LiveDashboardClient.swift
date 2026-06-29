import Foundation

/// Talks to the real aggregator over HTTP(S): `GET /api/dashboard` with a
/// Bearer token, and `GET /healthz` for connectivity checks.
public struct LiveDashboardClient: DashboardProviding {
	public let baseURL: URL
	public let token: String
	private let session: URLSession

	/// - Parameters:
	///   - baseURLString: aggregator root, e.g. `http://server.tailnet.ts.net:8765`.
	///     Tolerant of common variations: a missing scheme (defaults to `http://`),
	///     a trailing slash, or a pasted full endpoint URL ending in `/api/dashboard`
	///     or `/healthz` (as the existing web widgets use) — all normalize to the root.
	///   - token: WIDGET_TOKEN sent as `Authorization: Bearer …`.
	public init?(baseURLString: String, token: String, session: URLSession = .shared) {
		guard let url = URL(string: Self.normalizedBase(baseURLString)) else { return nil }
		self.baseURL = url
		self.token = token
		self.session = session
	}

	/// Reduce user input to the aggregator root URL string. Returns "" for empty input.
	static func normalizedBase(_ raw: String) -> String {
		var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !s.isEmpty else { return "" }
		if !s.contains("://") { s = "http://" + s }
		func trimTrailingSlashes() { while s.hasSuffix("/") { s.removeLast() } }
		trimTrailingSlashes()
		for suffix in ["/api/dashboard", "/healthz"] where s.hasSuffix(suffix) {
			s.removeLast(suffix.count)
		}
		trimTrailingSlashes()
		return s
	}

	private func endpoint(_ path: String) -> URL {
		baseURL.appendingPathComponent(path)
	}

	public func fetch() async throws -> Dashboard {
		var req = URLRequest(url: endpoint("api/dashboard"))
		if !token.isEmpty {
			req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
		}
		req.timeoutInterval = 8

		let data: Data
		let response: URLResponse
		do {
			(data, response) = try await session.data(for: req)
		} catch {
			throw DashboardError.transport(error.localizedDescription)
		}

		if let http = response as? HTTPURLResponse {
			switch http.statusCode {
			case 200: break
			case 401: throw DashboardError.unauthorized
			default: throw DashboardError.http(http.statusCode)
			}
		}

		do {
			return try JSONDecoder.glance.decode(Dashboard.self, from: data)
		} catch {
			throw DashboardError.transport("Could not decode dashboard: \(error.localizedDescription)")
		}
	}

	public func testConnection() async -> Bool {
		var req = URLRequest(url: endpoint("healthz"))
		req.timeoutInterval = 6
		guard let (_, response) = try? await session.data(for: req),
		      let http = response as? HTTPURLResponse else {
			return false
		}
		return http.statusCode == 200
	}
}

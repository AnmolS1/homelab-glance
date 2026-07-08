import Foundation

/// Live Docker control client. Reads use the Bearer WIDGET_TOKEN; writes add the
/// `X-Control-Token` header. Shares URL normalization with `LiveDashboardClient`.
public struct LiveDockerControlClient: DockerControlProviding {
	public let baseURL: URL
	public let token: String
	public let controlToken: String
	private let session: URLSession

	public init?(baseURLString: String, token: String, controlToken: String, session: URLSession = .shared) {
		guard let url = URL(string: LiveDashboardClient.normalizedBase(baseURLString)) else { return nil }
		self.baseURL = url
		self.token = token
		self.controlToken = controlToken
		self.session = session
	}

	private struct ContainersResponse: Decodable { let containers: [DockerContainer] }
	private struct LogsResponse: Decodable { let logs: String }
	private struct ActionResponse: Decodable { let audit: AuditEntry }
	private struct AuditResponse: Decodable { let entries: [AuditEntry] }
	private struct ErrorBody: Decodable { let detail: String? }

	private func request(_ path: String, method: String = "GET", control: Bool = false) -> URLRequest {
		var req = URLRequest(url: baseURL.appendingPathComponent(path))
		req.httpMethod = method
		req.timeoutInterval = 15
		if !token.isEmpty { req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
		if control, !controlToken.isEmpty { req.setValue(controlToken, forHTTPHeaderField: "X-Control-Token") }
		return req
	}

	private func send<T: Decodable>(_ req: URLRequest, as type: T.Type) async throws -> T {
		let data: Data, response: URLResponse
		do {
			(data, response) = try await session.data(for: req)
		} catch {
			throw ControlError.transport(error.localizedDescription)
		}
		if let http = response as? HTTPURLResponse, http.statusCode != 200 {
			let detail = (try? JSONDecoder().decode(ErrorBody.self, from: data))?.detail ?? ""
			switch http.statusCode {
			case 503: throw ControlError.notConfigured
			case 401, 403: throw ControlError.forbidden(detail.isEmpty ? "Not authorized" : detail)
			default: throw ControlError.http(http.statusCode, detail)
			}
		}
		do {
			return try JSONDecoder.glance.decode(T.self, from: data)
		} catch {
			throw ControlError.transport("Decode failed: \(error.localizedDescription)")
		}
	}

	public func containers() async throws -> [DockerContainer] {
		try await send(request("api/docker/containers"), as: ContainersResponse.self).containers
	}

	public func logs(container: String, tail: Int) async throws -> String {
		var req = request("api/docker/\(container)/logs")
		req.url = req.url?.appending(queryItems: [URLQueryItem(name: "tail", value: String(tail))])
		return try await send(req, as: LogsResponse.self).logs
	}

	public func stats(container: String) async throws -> ContainerStats {
		try await send(request("api/docker/\(container)/stats"), as: ContainerStats.self)
	}

	public func perform(_ action: ContainerAction, on container: String) async throws -> AuditEntry {
		let req = request("api/docker/\(container)/\(action.rawValue)", method: "POST", control: true)
		return try await send(req, as: ActionResponse.self).audit
	}

	public func audit() async throws -> [AuditEntry] {
		try await send(request("api/docker/audit"), as: AuditResponse.self).entries
	}
}

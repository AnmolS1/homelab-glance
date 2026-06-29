import Foundation

/// Last-known dashboard shared between the app and the widgets via the App Group
/// container. The app writes on each successful fetch so widgets render instantly
/// from cache, then refresh with their own live fetch on the next timeline reload.
///
/// Uses plain (camelCase) JSON — independent of the server's snake_case payload,
/// which `JSONDecoder.glance` handles. No-ops gracefully when the App Group
/// container is unavailable (e.g. unsigned local builds).
public struct DashboardCache: Sendable {
	public static let shared = DashboardCache()

	private let filename = "dashboard.json"

	private var fileURL: URL? {
		FileManager.default
			.containerURL(forSecurityApplicationGroupIdentifier: AppSettings.appGroup)?
			.appendingPathComponent(filename)
	}

	public init() {}

	public func write(_ dashboard: Dashboard) {
		guard let url = fileURL, let data = try? JSONEncoder().encode(dashboard) else { return }
		try? data.write(to: url, options: .atomic)
	}

	public func read() -> Dashboard? {
		guard let url = fileURL, let data = try? Data(contentsOf: url) else { return nil }
		return try? JSONDecoder().decode(Dashboard.self, from: data)
	}
}

import Foundation

/// Anchor class used to resolve the GlanceKit framework bundle at runtime.
final class GlanceKitBundleToken {}

/// Access to the bundled sample dashboard used by mock mode, previews, and tests.
public enum MockData {
	/// The GlanceKit resource bundle.
	public static var bundle: Bundle { Bundle(for: GlanceKitBundleToken.self) }

	/// Raw bytes of the bundled `sample-dashboard.json`.
	public static func sampleJSONData() throws -> Data {
		guard let url = bundle.url(forResource: "sample-dashboard", withExtension: "json") else {
			throw DashboardError.transport("sample-dashboard.json not found in GlanceKit bundle")
		}
		return try Data(contentsOf: url)
	}

	/// The decoded sample dashboard.
	public static func sampleDashboard() throws -> Dashboard {
		try JSONDecoder.glance.decode(Dashboard.self, from: sampleJSONData())
	}
}

/// A `DashboardProviding` that returns the bundled sample. Optionally simulates
/// latency so loading states are exercisable in mock mode.
public struct MockDashboardClient: DashboardProviding {
	public var latency: Duration

	public init(latency: Duration = .zero) {
		self.latency = latency
	}

	public func fetch() async throws -> Dashboard {
		if latency != .zero { try? await Task.sleep(for: latency) }
		return try MockData.sampleDashboard()
	}

	public func testConnection() async -> Bool { true }
}

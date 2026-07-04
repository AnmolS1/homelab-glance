import AppIntents
import GlanceKit

/// App Intent that restarts a container via the control plane — runs without
/// opening the app (from a Control Center / Lock Screen control).
///
/// Lives in SharedIntents (compiled into BOTH the app and the widget
/// extension): macOS resolves interactive-widget intents against the APP
/// bundle's AppIntents metadata, while iOS resolves them in the extension.
struct RestartServiceIntent: AppIntent {
	static let title: LocalizedStringResource = "Restart Service"
	static let description = IntentDescription("Restart a homelab container.")

	@Parameter(title: "Container", default: "sonarr")
	var container: String

	init() {}
	init(container: String) { self.container = container }

	func perform() async throws -> some IntentResult {
		let connection = StoredConnection.load()
		_ = try? await connection.makeControlProvider().perform(.restart, on: container)
		return .result()
	}
}

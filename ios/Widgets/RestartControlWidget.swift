#if os(iOS)
import AppIntents
import GlanceKit

/// App Intent that restarts a container via the control plane — runs without
/// opening the app (from a Control Center / Lock Screen control).
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

import WidgetKit
import SwiftUI

/// iOS 18 Control Center / Lock Screen control to restart a chosen service.
@available(iOS 18.0, *)
struct RestartControlWidget: ControlWidget {
	var body: some ControlWidgetConfiguration {
		StaticControlConfiguration(kind: "dev.ponderance.homelabglance.restart") {
			ControlWidgetButton(action: RestartServiceIntent(container: "sonarr")) {
				Label("Restart sonarr", systemImage: "arrow.clockwise")
			}
		}
		.displayName("Restart Service")
		.description("Restart a homelab container without opening the app.")
	}
}
#endif

#if os(iOS)
// RestartServiceIntent lives in SharedIntents/ContainerIntents.swift (compiled
// into both the app and this extension); only the control itself lives here.
import AppIntents
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

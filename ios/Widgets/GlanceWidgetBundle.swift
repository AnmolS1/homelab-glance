import WidgetKit
import SwiftUI

/// Widget bundle entry point. SCAFFOLD ONLY for sub-project 1 — real widget
/// content (Home Screen / Lock Screen / macOS) arrives in sub-project 2. This
/// placeholder exists so the extension target, App Group, and embedding are
/// wired and building from day one.
@main
struct GlanceWidgetBundle: WidgetBundle {
	var body: some Widget {
		GlanceWidget()
		#if os(iOS)
		DownloadLiveActivity()
		if #available(iOS 18.0, *) {
			RestartControlWidget()
		}
		#endif
	}
}

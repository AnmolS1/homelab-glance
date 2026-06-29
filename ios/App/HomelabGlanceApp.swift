import SwiftUI
import GlanceKit

@main
struct HomelabGlanceApp: App {
	@State private var settings = AppSettings.shared

	init() {
		BlueprintFonts.registerAll()
	}

	var body: some Scene {
		WindowGroup {
			DashboardView(settings: settings)
				.preferredColorScheme(.dark)
		}
		#if os(macOS)
		.defaultSize(width: 760, height: 900)
		#endif

		#if os(macOS)
		// Always-available Übersicht replacement: the full dashboard in a
		// menu-bar dropdown panel.
		MenuBarExtra {
			DashboardView(settings: settings)
				.frame(width: 440, height: 660)
				.preferredColorScheme(.dark)
		} label: {
			LogoMark(size: 18)
		}
		.menuBarExtraStyle(.window)
		#endif
	}
}

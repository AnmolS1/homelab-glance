import SwiftUI
import GlanceKit
#if os(macOS)
import AppKit
#endif

@main
struct HomelabGlanceApp: App {
	@State private var settings = AppSettings.shared
	@State private var router = DeepLinkRouter()
	@State private var showOnboarding = false

	init() {
		BlueprintFonts.registerAll()
	}

	var body: some Scene {
		WindowGroup {
			DashboardView(settings: settings, router: router)
				.onAppear { showOnboarding = !settings.hasCompletedOnboarding }
				.sheet(isPresented: $showOnboarding) {
					OnboardingSheet(settings: settings)
				}
				// Widget cards deep-link here: homelabglance://logs/<container>.
				.onOpenURL { url in
					if let link = DeepLink(url: url) { router.pending = link }
				}
				#if os(macOS)
				.task { applyDockPolicy() }
				.onChange(of: settings.hideDockIcon) { _, _ in applyDockPolicy() }
				#endif
		}
		#if os(macOS)
		.defaultSize(width: 760, height: 900)
		#endif

		#if os(macOS)
		// Always-available Übersicht replacement: the full dashboard in a menu-bar
		// dropdown. Template image so the system sizes/tints it for the bar.
		MenuBarExtra("Homelab Glance", image: "MenuBarMark") {
			DashboardView(settings: settings, inPanel: true)
				.frame(width: 480, height: 720)
		}
		.menuBarExtraStyle(.window)
		#endif
	}

	#if os(macOS)
	/// Show or hide the Dock icon. `.accessory` runs the app menu-bar-only; the
	/// MenuBarExtra keeps it reachable once the Dock icon is gone.
	private func applyDockPolicy() {
		NSApplication.shared.setActivationPolicy(settings.hideDockIcon ? .accessory : .regular)
	}
	#endif
}

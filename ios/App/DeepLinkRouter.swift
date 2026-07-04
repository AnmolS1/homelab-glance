import SwiftUI
import GlanceKit

/// Pushable destinations for the main dashboard's `NavigationStack`. Value-based so
/// both the toolbar buttons and incoming deep links drive the same stack.
enum DashRoute: Hashable {
	case containers
	case logs(container: String)
}

/// Carries an incoming `DeepLink` (from `onOpenURL`) to the main-window
/// `DashboardView`, which translates it into `NavigationStack` pushes and then
/// clears it. The menu-bar panel copy of `DashboardView` gets no router, so it
/// keeps its own independent navigation.
@MainActor
@Observable
final class DeepLinkRouter {
	var pending: DeepLink?
}

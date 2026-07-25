import SwiftUI
import GlanceKit
#if canImport(UIKit)
import UIKit
#endif

/// The live dashboard: host header, service groups (Media, Acquisition,
/// Infrastructure, Home), the sensors section, and an "updated HH:MM:SS" footer.
struct DashboardView: View {
	@Environment(\.colorScheme) private var scheme
	@Environment(\.scenePhase) private var scenePhase
	@Environment(\.dynamicTypeSize) private var dynamicTypeSize

	private let settings: AppSettings
	/// When hosted in the MenuBarExtra popover there's no title bar, so `.toolbar`
	/// items don't render — show the nav buttons in-content instead.
	private let inPanel: Bool
	/// Non-nil only for the main window: routes incoming deep links into `path`.
	private let router: DeepLinkRouter?
	/// Non-nil only when launched by the screenshot harness: deep-jumps the stack
	/// to a named screen ("containers" / "cards" / "logs") on first appear.
	private let screenshotScreen: String?
	@State private var model: DashboardViewModel
	@State private var path = NavigationPath()

	private static let groupOrder = ["Media", "Acquisition", "Infrastructure", "Home"]
	// Wider minimum at accessibility text sizes → fewer columns (single on phones)
	// so grown cards reflow instead of clipping.
	private var columns: [GridItem] {
		[GridItem(.adaptive(minimum: dynamicTypeSize.isAccessibilitySize ? 300 : 150), spacing: 8)]
	}

	init(settings: AppSettings, inPanel: Bool = false, router: DeepLinkRouter? = nil,
	     screenshotScreen: String? = nil) {
		self.settings = settings
		self.inPanel = inPanel
		self.router = router
		self.screenshotScreen = screenshotScreen
		_model = State(initialValue: DashboardViewModel(settings: settings))
	}

	private var controlLink: some View {
		NavigationLink(value: DashRoute.containers) { Image(systemName: "server.rack") }
			.accessibilityLabel("Containers")
			.help("Containers")
	}
	private var settingsLink: some View {
		NavigationLink { SettingsView(settings: settings) } label: { Image(systemName: "gearshape") }
			.accessibilityLabel("Settings")
			.help("Settings")
	}

	/// True while the view model has no data to show (used to gate the failure
	/// announcement so it fires once on entering the error state).
	private var failureMessage: String? {
		if case .failed(let message) = model.state { return message } else { return nil }
	}

	/// Translate a deep link into stack pushes. `.logs` lands on the container list
	/// with the logs on top, so Back returns to the list.
	private func handle(_ link: DeepLink) {
		switch link {
		case .containers:
			path = NavigationPath([DashRoute.containers])
		case .logs(let container):
			path = NavigationPath([DashRoute.containers, DashRoute.logs(container: container)])
		}
		router?.pending = nil
	}

	/// Resolved palette for the current colour scheme. A computed property (not a
	/// `let` inside `body`) so the type-checker doesn't re-infer it across the
	/// whole body expression — that pushed `body` past the solver's budget on
	/// CI's slower machine and failed the Release archive. See `navigation`,
	/// `rootContent`, and `navToolbar`, which wall off sub-expressions behind
	/// opaque return types for the same reason.
	private var bp: BlueprintColors { BlueprintColors.resolve(scheme) }

	var body: some View {
		navigation
		.environment(\.blueprint, bp)
		.tint(bp.crease)
		.task { model.start() }
		.onChange(of: scenePhase) { _, phase in
			if phase == .active { model.start() } else { model.stop() }
		}
		// Re-read the provider when connection settings change (push nav has no
		// sheet-dismiss hook).
		.onChange(of: settings.useMockData) { _, _ in model.applySettings() }
		.onChange(of: settings.baseURLString) { _, _ in model.applySettings() }
		.onChange(of: settings.token) { _, _ in model.applySettings() }
		// Deep links (main window only): translate an incoming DeepLink into nav
		// pushes. `.task` catches a link that arrived during cold launch.
		.onChange(of: router?.pending) { _, link in
			if let link { handle(link) }
		}
		// Announce an unreachable/error state once, politely (fires on entering
		// .failed; only re-fires if the message text itself changes).
		.onChange(of: failureMessage) { _, message in
			if let message { AccessibilityNotification.Announcement(message).post() }
		}
		.task { if let link = router?.pending { handle(link) } }
		// Screenshot harness: deep-jump to the requested screen on first appear.
		.task {
			switch screenshotScreen {
			case "containers": path = NavigationPath([DashRoute.containers])
			case "cards":      path = NavigationPath([DashRoute.cards])
			case "logs":       path = NavigationPath([DashRoute.containers, DashRoute.logs(container: "jellyfin")])
			default: break
			}
		}
	}

	/// The navigation container. Extracted from `body` so its whole chain
	/// (destinations, toolbars) type-checks as an isolated `some View`.
	private var navigation: some View {
		NavigationStack(path: $path) {
			ZStack {
				GraphPaperBackground()
				rootContent
			}
			.navigationTitle("")
			.navigationDestination(for: DashRoute.self) { destination($0) }
			.toolbar { navToolbar }
			// In the menu-bar popover there's no title bar — hide the empty
			// nav-bar area so the in-content buttons sit at the very top.
			#if os(macOS)
			.toolbar(inPanel ? .hidden : .automatic, for: .windowToolbar)
			#endif
		}
	}

	/// The ZStack's foreground: the in-panel nav row (menu-bar popover only)
	/// stacked over the dashboard content, or just the content in the window.
	@ViewBuilder
	private var rootContent: some View {
		if inPanel {
			VStack(spacing: 0) {
				HStack(spacing: 14) {
					Spacer()
					controlLink
					settingsLink
				}
				.font(.title3)
				.tint(bp.crease)
				.padding(.horizontal, 14)
				.padding(.top, 10)
				content(bp)
			}
		} else {
			content(bp)
		}
	}

	@ViewBuilder
	private func destination(_ route: DashRoute) -> some View {
		switch route {
		case .containers:
			ControlView(settings: settings)
		case .logs(let container):
			LogsView(settings: settings, container: container)
				.environment(\.blueprint, bp)
		case .cards:
			CardManagerView(settings: settings)
				.environment(\.blueprint, bp)
		}
	}

	@ToolbarContentBuilder
	private var navToolbar: some ToolbarContent {
		if !inPanel {
			ToolbarItem(placement: .primaryAction) { controlLink.tint(bp.crease) }
			ToolbarItem(placement: .primaryAction) { settingsLink.tint(bp.crease) }
		}
	}

	@ViewBuilder
	private func content(_ bp: BlueprintColors) -> some View {
		switch model.state {
		case .loading:
			ProgressView().tint(bp.crease)
		case .failed(let message):
			VStack(spacing: 12) {
				Image(systemName: "exclamationmark.triangle")
					.font(.title)
					.foregroundStyle(bp.crane)
					.accessibilityHidden(true)
				Text(message)
					.font(Typography.text(13))
					.foregroundStyle(bp.ink60)
					.multilineTextAlignment(.center)
				NavigationLink("Open Settings") { SettingsView(settings: settings) }
					.buttonStyle(.bordered)
					.tint(bp.crease)
			}
			.padding(32)
		case .loaded(let dash):
			// On the tall 13" iPad the dashboard doesn't fill the viewport, so center
			// it vertically — balanced margins read as intentional rather than a big
			// gap at the bottom. Content taller than the viewport still scrolls.
			GeometryReader { proxy in
				ScrollView {
					loaded(dash, bp)
						.padding(16)
						.frame(maxWidth: .infinity,
						       minHeight: centersContentVertically ? proxy.size.height : nil,
						       alignment: .center)
				}
				// Manual refresh with spoken announcements (background polls stay silent).
				.refreshable {
					AccessibilityNotification.Announcement("Refreshing").post()
					await model.refresh()
					AccessibilityNotification.Announcement("Dashboard updated").post()
				}
			}
		}
	}

	/// True on iPad, where the dashboard is shorter than the tall portrait viewport.
	private var centersContentVertically: Bool {
		#if os(iOS)
		UIDevice.current.userInterfaceIdiom == .pad
		#else
		false
		#endif
	}

	private func loaded(_ dash: Dashboard, _ bp: BlueprintColors) -> some View {
		// Rich-when-detected, else generic: containers whose service already has
		// a rich card are skipped; the rest render as generic container tiles.
		// The user's CardConfig applies visibility, order, groups, and renames.
		let config = CardConfigStore.shared.load()
		let tiles = mergeTiles(cards: dash.cards, containers: dash.containers ?? [], config: config)
		let richCards = tiles.compactMap { if case .rich(let card) = $0 { card } else { nil } }
		let grouped = Dictionary(grouping: richCards, by: { $0.group ?? "Other" })
		let genericTiles: [(DockerContainer, ServiceType?)] = tiles.compactMap {
			if case .generic(let container, let type) = $0 { (container, type) } else { nil }
		}
		let genericGrouped = Dictionary(grouping: genericTiles) { config.groups[$0.0.name] ?? "Containers" }
		// Alert counts from the MERGED tiles, so a down container (no rich card)
		// counts too — dash.downCount alone sees only cards.
		let downTiles = richCards.filter { $0.status == .down }.count
			+ genericTiles.filter { !$0.0.isRunning }.count
		let staleTiles = richCards.filter { $0.status != .down && $0.stale == true }.count
		return VStack(alignment: .leading, spacing: 18) {
			HostHeaderView(host: dash.host, downCount: downTiles, staleCount: staleTiles)

			Rectangle()
				.fill(bp.creaseLine)
				.frame(height: 1)

			ForEach(Self.groupOrder.filter { grouped[$0] != nil || genericGrouped[$0] != nil }, id: \.self) { group in
				section(group, rich: grouped[group] ?? [], generic: genericGrouped[group] ?? [], config: config)
			}

			if let ungrouped = genericGrouped["Containers"], !ungrouped.isEmpty {
				section("Containers", rich: [], generic: ungrouped, config: config)
			}

			if let sensors = dash.host.sensors {
				SensorsView(sensors: sensors)
			}

			HStack {
				Spacer()
				Text("updated \(Format.clock(model.lastUpdated))")
					.font(Typography.mono(10, weight: .regular))
					.foregroundStyle(bp.ink60.opacity(0.7))
					// Speak a relative time ("updated 2 minutes ago") rather than the clock.
					.accessibilityLabel(Format.spokenRelative(model.lastUpdated))
			}
		}
	}

	/// One dashboard section (v1.2 status-weighted): down items render full-width
	/// above the grid so they stay dominant in a narrow grid; the rest fill the
	/// adaptive grid sorted stale-before-up, so trouble floats to the top.
	@ViewBuilder
	private func section(_ group: String, rich: [Card],
	                     generic: [(DockerContainer, ServiceType?)], config: CardConfig) -> some View {
		let downRich = rich.filter { $0.status == .down }.sorted { $0.title < $1.title }
		let downGeneric = generic.filter { !$0.0.isRunning }
		let gridRich = rich.filter { $0.status != .down }.sorted { a, b in
			let ra = a.stale == true ? 0 : 1, rb = b.stale == true ? 0 : 1
			return ra != rb ? ra < rb : a.title < b.title
		}
		let gridGeneric = generic.filter { $0.0.isRunning }
		VStack(alignment: .leading, spacing: 8) {
			SectionLabel(group)
			ForEach(downRich) { ServiceCardView(card: $0) }
			ForEach(downGeneric, id: \.0.name) { container, type in
				GenericContainerTile(container: container, serviceType: type, config: config, settings: settings)
			}
			if !gridRich.isEmpty || !gridGeneric.isEmpty {
				LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
					ForEach(gridRich) { ServiceCardView(card: $0) }
					ForEach(gridGeneric, id: \.0.name) { container, type in
						GenericContainerTile(container: container, serviceType: type, config: config, settings: settings)
					}
				}
			}
		}
	}
}

/// A generic container card wired for the app: tap opens its logs, a context
/// menu offers start/stop/restart when the container is controllable, and one
/// CPU/mem sample loads lazily after the card appears (the ~1s two-sample
/// fetch never blocks rendering, and the widget never does this at all).
private struct GenericContainerTile: View {
	let container: DockerContainer
	let serviceType: ServiceType?
	var config = CardConfig()
	let settings: AppSettings

	@State private var stats: ContainerStats?

	/// The container with the user's display-name override applied.
	private var displayContainer: DockerContainer {
		var c = container
		c.name = config.displayName(for: container.name)
		return c
	}

	var body: some View {
		NavigationLink(value: DashRoute.logs(container: container.name)) {
			GenericContainerCardView(container: displayContainer, serviceType: serviceType, stats: stats)
		}
		.buttonStyle(.plain)
		.accessibilityHint("Opens logs")
		.contextMenu {
			if container.controllable {
				ForEach(ContainerAction.allCases, id: \.self) { action in
					Button {
						let provider = settings.makeControlProvider()
						Task { _ = try? await provider.perform(action, on: container.name) }
					} label: {
						Label(action.label, systemImage: action.systemImage)
					}
				}
			}
		}
		.task(id: container.name) {
			guard container.isRunning, stats == nil else { return }
			let provider = settings.makeControlProvider()
			stats = try? await provider.stats(container: container.name)
		}
	}
}

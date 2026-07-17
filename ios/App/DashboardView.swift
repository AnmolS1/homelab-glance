import SwiftUI
import GlanceKit

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
	@State private var model: DashboardViewModel
	@State private var path = NavigationPath()

	private static let groupOrder = ["Media", "Acquisition", "Infrastructure", "Home"]
	// Wider minimum at accessibility text sizes → fewer columns (single on phones)
	// so grown cards reflow instead of clipping.
	private var columns: [GridItem] {
		[GridItem(.adaptive(minimum: dynamicTypeSize.isAccessibilitySize ? 300 : 165), spacing: 10)]
	}

	init(settings: AppSettings, inPanel: Bool = false, router: DeepLinkRouter? = nil) {
		self.settings = settings
		self.inPanel = inPanel
		self.router = router
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

	/// The current error message when the dashboard has no data, else nil — gates
	/// the failure announcement so it fires once on entering the error state.
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

	var body: some View {
		let bp = BlueprintColors.resolve(scheme)
		NavigationStack(path: $path) {
			ZStack {
				GraphPaperBackground()
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
			.navigationTitle("")
			.navigationDestination(for: DashRoute.self) { route in
				switch route {
				case .containers:
					ControlView(settings: settings)
				case .logs(let container):
					LogsView(settings: settings, container: container)
						.environment(\.blueprint, bp)
				}
			}
			.toolbar {
				if !inPanel {
					ToolbarItem(placement: .primaryAction) { controlLink.tint(bp.crease) }
					ToolbarItem(placement: .primaryAction) { settingsLink.tint(bp.crease) }
				}
			}
			// In the menu-bar popover there's no title bar — hide the empty
			// nav-bar area so the in-content buttons sit at the very top.
			#if os(macOS)
			.toolbar(inPanel ? .hidden : .automatic, for: .windowToolbar)
			#endif
		}
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
			ScrollView {
				loaded(dash, bp)
					.padding(16)
			}
			// Manual refresh with spoken announcements (background polls stay silent).
			.refreshable {
				AccessibilityNotification.Announcement("Refreshing").post()
				await model.refresh()
				AccessibilityNotification.Announcement("Dashboard updated").post()
			}
		}
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
		return VStack(alignment: .leading, spacing: 18) {
			HostHeaderView(host: dash.host)

			Rectangle()
				.fill(bp.creaseLine)
				.frame(height: 1)

			ForEach(Self.groupOrder.filter { grouped[$0] != nil || genericGrouped[$0] != nil }, id: \.self) { group in
				VStack(alignment: .leading, spacing: 8) {
					SectionLabel(group)
					LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
						ForEach(grouped[group] ?? []) { card in
							ServiceCardView(card: card)
						}
						ForEach(genericGrouped[group] ?? [], id: \.0.name) { container, type in
							GenericContainerTile(container: container, serviceType: type, config: config, settings: settings)
						}
					}
				}
			}

			if let ungrouped = genericGrouped["Containers"], !ungrouped.isEmpty {
				VStack(alignment: .leading, spacing: 8) {
					SectionLabel("Containers")
					LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
						ForEach(ungrouped, id: \.0.name) { container, type in
							GenericContainerTile(container: container, serviceType: type, config: config, settings: settings)
						}
					}
				}
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

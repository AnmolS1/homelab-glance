import SwiftUI
import GlanceKit

/// The live dashboard: host header, service groups (Media, Acquisition,
/// Infrastructure, Home), the sensors section, and an "updated HH:MM:SS" footer.
struct DashboardView: View {
	@Environment(\.colorScheme) private var scheme
	@Environment(\.scenePhase) private var scenePhase

	private let settings: AppSettings
	/// When hosted in the MenuBarExtra popover there's no title bar, so `.toolbar`
	/// items don't render — show the nav buttons in-content instead.
	private let inPanel: Bool
	/// Non-nil only for the main window: routes incoming deep links into `path`.
	private let router: DeepLinkRouter?
	@State private var model: DashboardViewModel
	@State private var path = NavigationPath()

	private static let groupOrder = ["Media", "Acquisition", "Infrastructure", "Home"]
	private let columns = [GridItem(.adaptive(minimum: 165), spacing: 10)]

	init(settings: AppSettings, inPanel: Bool = false, router: DeepLinkRouter? = nil) {
		self.settings = settings
		self.inPanel = inPanel
		self.router = router
		_model = State(initialValue: DashboardViewModel(settings: settings))
	}

	private var controlLink: some View {
		NavigationLink(value: DashRoute.containers) { Image(systemName: "server.rack") }
	}
	private var settingsLink: some View {
		NavigationLink { SettingsView(settings: settings) } label: { Image(systemName: "gearshape") }
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
		}
	}

	private func loaded(_ dash: Dashboard, _ bp: BlueprintColors) -> some View {
		let grouped = Dictionary(grouping: dash.cards, by: { $0.group ?? "Other" })
		// Rich-when-detected, else generic: containers whose service already has
		// a rich card are skipped; the rest render as generic container tiles.
		let genericTiles: [(DockerContainer, ServiceType?)] = mergeTiles(
			cards: dash.cards, containers: dash.containers ?? []
		).compactMap {
			if case .generic(let container, let type) = $0 { (container, type) } else { nil }
		}
		return VStack(alignment: .leading, spacing: 18) {
			HostHeaderView(host: dash.host)

			Rectangle()
				.fill(bp.creaseLine)
				.frame(height: 1)

			ForEach(Self.groupOrder.filter { grouped[$0] != nil }, id: \.self) { group in
				VStack(alignment: .leading, spacing: 8) {
					SectionLabel(group)
					LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
						ForEach(grouped[group] ?? []) { card in
							ServiceCardView(card: card)
						}
					}
				}
			}

			if !genericTiles.isEmpty {
				VStack(alignment: .leading, spacing: 8) {
					SectionLabel("Containers")
					LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
						ForEach(genericTiles, id: \.0.name) { container, type in
							GenericContainerTile(container: container, serviceType: type, settings: settings)
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
	let settings: AppSettings

	@State private var stats: ContainerStats?

	var body: some View {
		NavigationLink(value: DashRoute.logs(container: container.name)) {
			GenericContainerCardView(container: container, serviceType: serviceType, stats: stats)
		}
		.buttonStyle(.plain)
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

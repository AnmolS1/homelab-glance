import SwiftUI
import GlanceKit

/// The live dashboard: host header, service groups (Media, Acquisition,
/// Infrastructure, Home), the sensors section, and an "updated HH:MM:SS" footer.
struct DashboardView: View {
	@Environment(\.colorScheme) private var scheme
	@Environment(\.scenePhase) private var scenePhase

	private let settings: AppSettings
	@State private var model: DashboardViewModel
	@State private var showingSettings = false
	@State private var showingControl = false

	private static let groupOrder = ["Media", "Acquisition", "Infrastructure", "Home"]
	private let columns = [GridItem(.adaptive(minimum: 165), spacing: 10)]

	init(settings: AppSettings) {
		self.settings = settings
		_model = State(initialValue: DashboardViewModel(settings: settings))
	}

	var body: some View {
		let bp = BlueprintColors.resolve(scheme)
		NavigationStack {
			ZStack {
				GraphPaperBackground()
				content(bp)
			}
			.navigationTitle("")
			.toolbar {
				ToolbarItem(placement: .primaryAction) {
					Button {
						showingControl = true
					} label: {
						Image(systemName: "server.rack")
					}
					.tint(bp.crease)
				}
				ToolbarItem(placement: .primaryAction) {
					Button {
						showingSettings = true
					} label: {
						Image(systemName: "gearshape")
					}
					.tint(bp.crease)
				}
			}
		}
		.environment(\.blueprint, bp)
		.tint(bp.crease)
		.sheet(isPresented: $showingControl) {
			NavigationStack { ControlView(settings: settings) }
				.environment(\.blueprint, bp)
				.tint(bp.crease)
		}
		.sheet(isPresented: $showingSettings, onDismiss: { model.applySettings() }) {
			SettingsView(settings: settings)
				.environment(\.blueprint, bp)
		}
		.task { model.start() }
		.onChange(of: scenePhase) { _, phase in
			if phase == .active { model.start() } else { model.stop() }
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
				Text(message)
					.font(Typography.text(13))
					.foregroundStyle(bp.ink60)
					.multilineTextAlignment(.center)
				Button("Open Settings") { showingSettings = true }
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

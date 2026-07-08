import WidgetKit
import SwiftUI
import GlanceKit

struct DashboardEntry: TimelineEntry {
	let date: Date
	let dashboard: Dashboard?
	let unreachable: Bool
	/// Selected + merged tiles rendered as `Card`s (rich cards pass through;
	/// generic containers synthesize a card). Ordered per CardConfig.
	let cards: [Card]
	let layout: WidgetLayoutOption
	let density: WidgetDensity
}

/// Timeline provider: renders the App-Group cache instantly, then refreshes
/// with its own live fetch (mock when unconfigured). Honors the per-instance
/// intent: chosen containers (else the in-app widget defaults, else all
/// visible), layout, and density. Reloads ~every 20 min — ambient; the in-app
/// view is the live one.
struct DashboardTimelineProvider: AppIntentTimelineProvider {
	typealias Entry = DashboardEntry
	typealias Intent = GlanceConfigurationIntent

	/// intent selection → CardConfig.widgetDefaults → all visible (nil).
	private func effectiveSelection(for intent: GlanceConfigurationIntent, config: CardConfig) -> Set<String>? {
		if let chosen = intent.containers, !chosen.isEmpty {
			return Set(chosen.map(\.id))
		}
		if !config.widgetDefaults.isEmpty {
			return Set(config.widgetDefaults)
		}
		return nil
	}

	private func entry(for intent: GlanceConfigurationIntent, dashboard: Dashboard?, unreachable: Bool) -> DashboardEntry {
		let config = CardConfigStore.shared.load()
		let cards: [Card]
		if let dashboard {
			cards = mergeTiles(
				cards: dashboard.cards,
				containers: dashboard.containers ?? [],
				config: config,
				selection: effectiveSelection(for: intent, config: config)
			).map { $0.asWidgetCard(config: config) }
		} else {
			cards = []
		}
		return DashboardEntry(
			date: Date(),
			dashboard: dashboard,
			unreachable: unreachable,
			cards: cards,
			layout: intent.layout,
			density: intent.density
		)
	}

	func placeholder(in context: Context) -> DashboardEntry {
		entry(for: GlanceConfigurationIntent(), dashboard: try? MockData.sampleDashboard(), unreachable: false)
	}

	func snapshot(for configuration: GlanceConfigurationIntent, in context: Context) async -> DashboardEntry {
		let dash = DashboardCache.shared.read() ?? (try? MockData.sampleDashboard())
		return entry(for: configuration, dashboard: dash, unreachable: false)
	}

	func timeline(for configuration: GlanceConfigurationIntent, in context: Context) async -> Timeline<DashboardEntry> {
		let connection = StoredConnection.load()
		var dashboard = DashboardCache.shared.read()
		var unreachable = false
		do {
			let fetched = try await connection.makeProvider().fetch()
			dashboard = fetched
			DashboardCache.shared.write(fetched)
		} catch {
			if dashboard == nil { unreachable = true }
		}
		let next = Date().addingTimeInterval(20 * 60)
		return Timeline(
			entries: [entry(for: configuration, dashboard: dashboard, unreachable: unreachable)],
			policy: .after(next)
		)
	}
}

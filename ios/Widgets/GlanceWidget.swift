import WidgetKit
import SwiftUI
import GlanceKit

struct GlanceWidget: Widget {
	var body: some WidgetConfiguration {
		// Same kind string as the previous StaticConfiguration — WidgetKit
		// migrates already-placed widgets in place, initializing the intent
		// with its defaults (all-visible containers, grid, regular), which
		// reproduces the pre-migration behavior exactly.
		AppIntentConfiguration(
			kind: "HomelabGlanceDashboard",
			intent: GlanceConfigurationIntent.self,
			provider: DashboardTimelineProvider()
		) { entry in
			DashboardWidgetEntryView(entry: entry)
		}
		.configurationDisplayName("Homelab Glance")
		.description("Your homelab status at a glance.")
		.supportedFamilies(Self.families)
	}

	static var families: [WidgetFamily] {
		#if os(iOS)
		// .systemExtraLarge is offered on iPad; iPhone simply ignores it.
		[.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge,
		 .accessoryInline, .accessoryCircular, .accessoryRectangular]
		#else
		// macOS supports the wide .systemExtraLarge tile too (renders ExtraLargeView).
		[.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge]
		#endif
	}
}

#if DEBUG
/// Bundled-mock entry for canvas previews — mirrors how the timeline provider
/// builds its cards (mergeTiles → asWidgetCard), so the preview exercises the real
/// fit-to-tile layout. Flip the device's text size in the canvas to watch the large
/// tiles degrade (full → temps-only → no-sensors → fewer cards) instead of clipping.
private func previewEntry(layout: WidgetLayoutOption = .grid,
                          density: WidgetDensity = .regular) -> DashboardEntry {
	let dash = try? MockData.sampleDashboard()
	let config = CardConfigStore.shared.load()
	let cards = dash.map {
		mergeTiles(cards: $0.cards, containers: $0.containers ?? [], config: config, selection: nil)
			.map { $0.asWidgetCard(config: config) }
	} ?? []
	return DashboardEntry(date: .now, dashboard: dash, unreachable: false,
	                      cards: cards, layout: layout, density: density)
}

#Preview("Large", as: .systemLarge) { GlanceWidget() } timeline: { previewEntry() }
#Preview("Extra Large", as: .systemExtraLarge) { GlanceWidget() } timeline: { previewEntry() }
#endif

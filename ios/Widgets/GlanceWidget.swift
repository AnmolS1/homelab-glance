import WidgetKit
import SwiftUI
import GlanceKit

struct GlanceWidget: Widget {
	var body: some WidgetConfiguration {
		StaticConfiguration(kind: "HomelabGlanceDashboard", provider: DashboardTimelineProvider()) { entry in
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

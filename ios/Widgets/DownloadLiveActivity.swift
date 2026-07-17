#if os(iOS)
import ActivityKit
import WidgetKit
import SwiftUI
import GlanceKit

/// qBittorrent download Live Activity — Lock Screen banner + Dynamic Island.
struct DownloadLiveActivity: Widget {
	var body: some WidgetConfiguration {
		ActivityConfiguration(for: DownloadActivityAttributes.self) { context in
			lockScreen(context)
				.padding(14)
				.activityBackgroundTint(BlueprintColors.dark.graph)
				.activitySystemActionForegroundColor(BlueprintColors.dark.crease)
		} dynamicIsland: { context in
			DynamicIsland {
				DynamicIslandExpandedRegion(.leading) {
					Label("\(Format.num(context.state.downloadMibps)) MiB/s", systemImage: "arrow.down")
						.accessibilityLabel("downloading \(Format.num(context.state.downloadMibps)) megabytes per second")
						.font(.caption).foregroundStyle(BlueprintColors.dark.crease)
				}
				DynamicIslandExpandedRegion(.trailing) {
					Label("\(context.state.activeCount)", systemImage: "arrow.down.circle")
						.accessibilityLabel("\(context.state.activeCount) active")
						.font(.caption)
				}
				DynamicIslandExpandedRegion(.center) {
					Text(context.attributes.host).font(.caption2).foregroundStyle(.secondary)
				}
				DynamicIslandExpandedRegion(.bottom) {
					Text("↑ \(Format.num(context.state.uploadMibps)) MiB/s · seeding \(context.state.seedingCount)")
						.font(.caption2).foregroundStyle(.secondary)
				}
			} compactLeading: {
				Image(systemName: "arrow.down").accessibilityLabel("Downloading")
			} compactTrailing: {
				Text("\(Format.num(context.state.downloadMibps, decimals: 0))").accessibilityLabel("\(Format.num(context.state.downloadMibps, decimals: 0)) megabytes per second down")
			} minimal: {
				Image(systemName: "arrow.down.circle").accessibilityLabel("Download activity")
			}
			.keylineTint(BlueprintColors.dark.crane)
		}
	}

	private func lockScreen(_ context: ActivityViewContext<DownloadActivityAttributes>) -> some View {
		HStack {
			VStack(alignment: .leading, spacing: 2) {
				Text(context.attributes.host)
					.font(.headline).foregroundStyle(BlueprintColors.dark.ink)
				Text("\(context.state.activeCount) active · seeding \(context.state.seedingCount)")
					.font(.caption).foregroundStyle(BlueprintColors.dark.ink60)
			}
			Spacer()
			VStack(alignment: .trailing, spacing: 2) {
				Text("↓ \(Format.num(context.state.downloadMibps)) MiB/s")
					.font(.callout.bold()).foregroundStyle(BlueprintColors.dark.crease)
				Text("↑ \(Format.num(context.state.uploadMibps)) MiB/s")
					.font(.caption).foregroundStyle(BlueprintColors.dark.ink60)
			}
		}
		.accessibilityElement(children: .ignore)
		.accessibilityLabel("\(context.attributes.host). downloading \(Format.num(context.state.downloadMibps)) megabytes per second, uploading \(Format.num(context.state.uploadMibps)). \(context.state.activeCount) active, seeding \(context.state.seedingCount)")
	}
}
#endif

#if os(iOS)
import ActivityKit
import GlanceKit

/// Starts / updates / ends the qBittorrent download Live Activity from the
/// foreground app. Uses `Activity.activities` rather than a stored handle so no
/// non-Sendable state crosses isolation. (Push updates from the aggregator are a
/// documented stretch goal.)
enum LiveActivityController {
	/// Reconcile the activity with the latest qBittorrent card: start when there
	/// are active downloads, update while they continue, end when they finish.
	static func sync(host: String, dlMibps: Double, ulMibps: Double, active: Int, seeding: Int) async {
		guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

		let state = DownloadActivityAttributes.ContentState(
			downloadMibps: dlMibps, uploadMibps: ulMibps, activeCount: active, seedingCount: seeding)
		let content = ActivityContent(state: state, staleDate: nil)
		let activities = Activity<DownloadActivityAttributes>.activities

		if active > 0 {
			if let activity = activities.first {
				await activity.update(content)
			} else {
				_ = try? Activity.request(
					attributes: DownloadActivityAttributes(host: host),
					content: content, pushType: nil)
			}
		} else {
			for activity in activities {
				await activity.end(content, dismissalPolicy: .immediate)
			}
		}
	}
}
#endif

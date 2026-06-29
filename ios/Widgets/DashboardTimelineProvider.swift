import WidgetKit
import SwiftUI
import GlanceKit

struct DashboardEntry: TimelineEntry {
	let date: Date
	let dashboard: Dashboard?
	let unreachable: Bool
}

/// Carries WidgetKit's non-Sendable completion closure across the `Task`
/// boundary. Safe because the completion is invoked exactly once.
private struct SendableBox<T>: @unchecked Sendable {
	let value: T
}

/// Timeline provider: renders the App-Group cache instantly, then refreshes with
/// its own live fetch (mock when unconfigured). Reloads ~every 20 min — ambient;
/// the in-app view is the live one.
struct DashboardTimelineProvider: TimelineProvider {
	func placeholder(in context: Context) -> DashboardEntry {
		DashboardEntry(date: Date(), dashboard: try? MockData.sampleDashboard(), unreachable: false)
	}

	func getSnapshot(in context: Context, completion: @escaping (DashboardEntry) -> Void) {
		let dash = DashboardCache.shared.read() ?? (try? MockData.sampleDashboard())
		completion(DashboardEntry(date: Date(), dashboard: dash, unreachable: false))
	}

	func getTimeline(in context: Context, completion: @escaping (Timeline<DashboardEntry>) -> Void) {
		let box = SendableBox(value: completion)
		Task {
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
			let entry = DashboardEntry(date: Date(), dashboard: dashboard, unreachable: unreachable)
			let next = Date().addingTimeInterval(20 * 60)
			box.value(Timeline(entries: [entry], policy: .after(next)))
		}
	}
}

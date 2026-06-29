import SwiftUI
import Observation
import GlanceKit

/// Drives the dashboard: fetches via the settings-selected provider, polls while
/// foregrounded at the snapshot's `poll_seconds`, and exposes loading/loaded/error.
@MainActor
@Observable
final class DashboardViewModel {
	enum LoadState {
		case loading
		case loaded(Dashboard)
		case failed(String)
	}

	private(set) var state: LoadState = .loading
	private(set) var lastUpdated: Date?

	private let settings: AppSettings
	private var provider: any DashboardProviding
	private var pollTask: Task<Void, Never>?

	init(settings: AppSettings) {
		self.settings = settings
		self.provider = settings.makeProvider()
	}

	private var pollSeconds: Int {
		if case .loaded(let d) = state { return max(5, d.pollSeconds ?? 15) }
		return 15
	}

	/// Re-read the provider from settings (after the Settings sheet changes) and refresh.
	func applySettings() {
		provider = settings.makeProvider()
		state = .loading
		Task { await refresh() }
	}

	func start() {
		guard pollTask == nil else { return }
		pollTask = Task { [weak self] in
			while let self, !Task.isCancelled {
				await self.refresh()
				try? await Task.sleep(for: .seconds(self.pollSeconds))
			}
		}
	}

	func stop() {
		pollTask?.cancel()
		pollTask = nil
	}

	func refresh() async {
		do {
			let dash = try await provider.fetch()
			state = .loaded(dash)
			lastUpdated = dash.generatedAtDate ?? Date()
			// Share with the widgets so they render instantly from cache.
			DashboardCache.shared.write(dash)
			WidgetReload.requestAll()
			#if os(iOS)
			if let qb = dash.cards.first(where: { $0.id == "qbittorrent" }), let d = qb.data {
				await LiveActivityController.sync(
					host: dash.host.name ?? "homelab",
					dlMibps: d.dlMibps ?? 0, ulMibps: d.ulMibps ?? 0,
					active: d.active ?? 0, seeding: d.seeding ?? 0)
			}
			#endif
		} catch {
			// Keep showing last-good data if we have it; only surface a hard error
			// when we never loaded anything.
			if case .loaded = state { return }
			let message = (error as? DashboardError)?.errorDescription ?? error.localizedDescription
			state = .failed(message)
		}
	}
}

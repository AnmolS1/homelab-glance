import Foundation

/// User configuration for the dashboard tiles, keyed by **container name**
/// (rich service cards resolve to their backing container's name; the fixed
/// Home cards use the container name as the card id already).
public struct CardConfig: Codable, Sendable, Equatable {
	/// Display order for the generic "Containers" section and the widget.
	/// Names not listed sort after the listed ones, alphabetically.
	public var order: [String]
	/// Tiles the user hid — excluded from dashboard and widgets.
	public var hidden: Set<String>
	/// Group override per container (generic tiles only; rich cards keep the
	/// server-assigned group).
	public var groups: [String: String]
	/// Display-name override per container.
	public var renames: [String: String]
	/// Default widget selection when a placed widget has no per-instance
	/// choice. Empty ⇒ all visible tiles.
	public var widgetDefaults: [String]

	public init(
		order: [String] = [],
		hidden: Set<String> = [],
		groups: [String: String] = [:],
		renames: [String: String] = [:],
		widgetDefaults: [String] = []
	) {
		self.order = order
		self.hidden = hidden
		self.groups = groups
		self.renames = renames
		self.widgetDefaults = widgetDefaults
	}

	public func displayName(for containerName: String) -> String {
		renames[containerName] ?? containerName
	}
}

/// App-Group JSON persistence for `CardConfig` (same pattern as
/// `DashboardCache`) so the app, widgets, and intents read one config.
public struct CardConfigStore: Sendable {
	public static let shared = CardConfigStore()

	private let filename = "card-config.json"

	private var fileURL: URL? {
		FileManager.default
			.containerURL(forSecurityApplicationGroupIdentifier: AppSettings.appGroup)?
			.appendingPathComponent(filename)
	}

	public init() {}

	public func load() -> CardConfig {
		guard let url = fileURL, let data = try? Data(contentsOf: url),
		      let config = try? JSONDecoder().decode(CardConfig.self, from: data) else {
			return CardConfig()
		}
		return config
	}

	public func save(_ config: CardConfig) {
		guard let url = fileURL, let data = try? JSONEncoder().encode(config) else { return }
		try? data.write(to: url, options: .atomic)
	}
}

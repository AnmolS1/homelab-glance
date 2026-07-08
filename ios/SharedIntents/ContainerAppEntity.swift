import AppIntents
import GlanceKit

/// A homelab container as an App Intents entity, so the widget's Edit screen
/// can offer the auto-detected inventory. `id` is the container **name** —
/// stable across container recreation, and the key `CardConfig` uses.
struct ContainerAppEntity: AppEntity {
	static let typeDisplayRepresentation: TypeDisplayRepresentation = "Container"
	static let defaultQuery = ContainerEntityQuery()

	let id: String
	var name: String
	var image: String?

	var displayRepresentation: DisplayRepresentation {
		DisplayRepresentation(
			title: "\(name)",
			subtitle: image.map { "\($0)" }
		)
	}

	init(container: DockerContainer, config: CardConfig) {
		self.id = container.name
		self.name = config.displayName(for: container.name)
		self.image = container.image
	}

	init(id: String) {
		self.id = id
		self.name = id
		self.image = nil
	}
}

/// Sources the entity list from the App-Group dashboard cache (written on
/// every successful fetch), falling back to a live/mock fetch on a cold cache.
struct ContainerEntityQuery: EntityQuery {
	private func allContainers() async -> [DockerContainer] {
		if let cached = DashboardCache.shared.read()?.containers, !cached.isEmpty {
			return cached
		}
		let connection = StoredConnection.load()
		if let live = try? await connection.makeControlProvider().containers() {
			return live
		}
		return []
	}

	func entities(for identifiers: [String]) async throws -> [ContainerAppEntity] {
		let config = CardConfigStore.shared.load()
		let byName = Dictionary(uniqueKeysWithValues: (await allContainers()).map { ($0.name, $0) })
		return identifiers.map { id in
			if let container = byName[id] {
				ContainerAppEntity(container: container, config: config)
			} else {
				// Keep a stale selection resolvable so a placed widget doesn't
				// lose its configuration when a container is recreated/renamed.
				ContainerAppEntity(id: id)
			}
		}
	}

	func suggestedEntities() async throws -> [ContainerAppEntity] {
		let config = CardConfigStore.shared.load()
		return (await allContainers())
			.filter { !config.hidden.contains($0.name) }
			.sorted { a, b in
				let rank = Dictionary(uniqueKeysWithValues: config.order.enumerated().map { ($1, $0) })
				let ra = rank[a.name] ?? Int.max
				let rb = rank[b.name] ?? Int.max
				return ra == rb ? a.name < b.name : ra < rb
			}
			.map { ContainerAppEntity(container: $0, config: config) }
	}
}

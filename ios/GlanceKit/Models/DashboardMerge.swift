import Foundation

/// One dashboard tile: a rich service card (the aggregator has a poller and
/// returned data for it) or a generic container card (auto-detected only).
public enum DashboardTile: Identifiable, Sendable {
	case rich(Card)
	case generic(DockerContainer, ServiceType?)

	public var id: String {
		switch self {
		case .rich(let card): "card-\(card.id)"
		case .generic(let container, _): "container-\(container.name)"
		}
	}

	/// The group a tile renders under (rich cards keep their server-assigned
	/// group; generic containers gather under "Containers" unless overridden).
	public var group: String {
		switch self {
		case .rich(let card): card.group ?? "Other"
		case .generic: "Containers"
		}
	}

	/// Render a tile as a `Card` for the widget families, which are built
	/// around `Card` (chips/mini-cards deep-link to logs via `card.id`, which
	/// for a synthesized card is the container name — exactly what LogsView
	/// expects).
	public func asWidgetCard(config: CardConfig = CardConfig()) -> Card {
		switch self {
		case .rich(let card):
			return card
		case .generic(let container, _):
			return Card(
				id: container.name,
				title: config.displayName(for: container.name),
				group: config.groups[container.name] ?? "Containers",
				status: container.isRunning ? .up : .down,
				stale: false,
				containerRunning: container.isRunning
			)
		}
	}
}

/// The container name a tile is keyed by for config (hidden/order/selection).
/// A rich card resolves to the container that detects to it (or its own id —
/// service card ids equal the conventional container name, and the fixed Home
/// cards use the container name as the card id already).
func tileKey(for tile: DashboardTile, nameByCardID: [String: String]) -> String {
	switch tile {
	case .rich(let card): nameByCardID[card.id] ?? card.id
	case .generic(let container, _): container.name
	}
}

/// Merge the rich cards with the auto-detected container inventory:
/// rich-when-detected, else generic. A container maps to its rich card when
/// `ServiceType.detect` finds a known type AND the dashboard carries a card
/// with that id — otherwise it falls back to a generic tile. Containers the
/// rich cards already cover are not duplicated.
///
/// `config` hides tiles and orders the result; `selection` (per-widget) keeps
/// only the named containers (nil ⇒ no filter). Lives in GlanceKit so the app
/// and the widget (working off the cached snapshot) share one implementation.
public func mergeTiles(
	cards: [Card],
	containers: [DockerContainer],
	config: CardConfig = CardConfig(),
	selection: Set<String>? = nil
) -> [DashboardTile] {
	let cardIDs = Set(cards.map(\.id))

	// container name → rich card id it backs (detection, else its own name).
	var nameByCardID: [String: String] = [:]
	for container in containers {
		let type = ServiceType.detect(image: container.image, name: container.name)
		let cardID = type?.cardID ?? container.name
		if cardIDs.contains(cardID) && nameByCardID[cardID] == nil {
			nameByCardID[cardID] = container.name
		}
	}

	var tiles: [DashboardTile] = cards.map { .rich($0) }
	for container in containers {
		let type = ServiceType.detect(image: container.image, name: container.name)
		if let type, cardIDs.contains(type.cardID) { continue }
		if cardIDs.contains(container.name) { continue }
		tiles.append(.generic(container, type))
	}

	tiles = tiles.filter { tile in
		let key = tileKey(for: tile, nameByCardID: nameByCardID)
		if config.hidden.contains(key) { return false }
		if let selection { return selection.contains(key) }
		return true
	}

	// Stable order: names listed in config.order first (in that order), the
	// rest keep their merge order after them.
	if !config.order.isEmpty {
		let rank = Dictionary(uniqueKeysWithValues: config.order.enumerated().map { ($1, $0) })
		tiles = tiles.enumerated().sorted { a, b in
			let ka = rank[tileKey(for: a.element, nameByCardID: nameByCardID)] ?? Int.max
			let kb = rank[tileKey(for: b.element, nameByCardID: nameByCardID)] ?? Int.max
			return ka == kb ? a.offset < b.offset : ka < kb
		}.map(\.element)
	}
	return tiles
}

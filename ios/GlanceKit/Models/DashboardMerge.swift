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
	/// group; generic containers gather under "Containers").
	public var group: String {
		switch self {
		case .rich(let card): card.group ?? "Other"
		case .generic: "Containers"
		}
	}
}

/// Merge the rich cards with the auto-detected container inventory:
/// rich-when-detected, else generic. A container maps to its rich card when
/// `ServiceType.detect` finds a known type AND the dashboard carries a card
/// with that id — otherwise it falls back to a generic tile. Containers the
/// rich cards already cover are not duplicated. Lives in GlanceKit so the app
/// and the widget (working off the cached snapshot) share one implementation.
public func mergeTiles(cards: [Card], containers: [DockerContainer]) -> [DashboardTile] {
	let cardIDs = Set(cards.map(\.id))
	var tiles: [DashboardTile] = cards.map { .rich($0) }

	for container in containers {
		let type = ServiceType.detect(image: container.image, name: container.name)
		if let type, cardIDs.contains(type.cardID) {
			continue  // already rendered as its rich card
		}
		// The aggregator's fixed "Home" cards (no dedicated poller) also arrive
		// as rich cards keyed by container name — don't duplicate those either.
		if cardIDs.contains(container.name) {
			continue
		}
		tiles.append(.generic(container, type))
	}
	return tiles
}

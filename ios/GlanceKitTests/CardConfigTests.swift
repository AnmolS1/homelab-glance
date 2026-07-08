import XCTest
@testable import GlanceKit

final class CardConfigTests: XCTestCase {
	private func container(_ name: String, image: String? = nil) -> DockerContainer {
		DockerContainer(id: String(name.prefix(12)), name: name, image: image,
		                state: "running", status: "Up 1 hour", controllable: true)
	}

	func testConfigRoundTrip() throws {
		let config = CardConfig(
			order: ["b", "a"],
			hidden: ["c"],
			groups: ["a": "Media"],
			renames: ["b": "Bee"],
			widgetDefaults: ["a", "b"]
		)
		let data = try JSONEncoder().encode(config)
		let decoded = try JSONDecoder().decode(CardConfig.self, from: data)
		XCTAssertEqual(decoded, config)
	}

	func testDisplayNameFallsBackToContainerName() {
		let config = CardConfig(renames: ["a": "Alpha"])
		XCTAssertEqual(config.displayName(for: "a"), "Alpha")
		XCTAssertEqual(config.displayName(for: "b"), "b")
	}

	func testHiddenExcludesGenericAndRichTiles() {
		let cards = [Card(id: "jellyfin", title: "Jellyfin", group: "Media")]
		let containers = [
			container("jellyfin", image: "jellyfin/jellyfin"),
			container("acme-app", image: "ghcr.io/acme/acme-app"),
		]
		// Hiding by container name hides the rich card it backs, and hiding a
		// generic container hides its tile.
		let config = CardConfig(hidden: ["jellyfin", "acme-app"])
		let tiles = mergeTiles(cards: cards, containers: containers, config: config)
		XCTAssertTrue(tiles.isEmpty)
	}

	func testSelectionFiltersTiles() {
		let cards = [Card(id: "jellyfin", title: "Jellyfin", group: "Media")]
		let containers = [
			container("jellyfin", image: "jellyfin/jellyfin"),
			container("acme-app", image: "ghcr.io/acme/acme-app"),
			container("other", image: "other/other"),
		]
		let tiles = mergeTiles(cards: cards, containers: containers,
		                       selection: ["jellyfin", "acme-app"])
		XCTAssertEqual(tiles.count, 2)
		guard case .rich = tiles[0], case .generic(let c, _) = tiles[1] else {
			return XCTFail("expected rich + generic")
		}
		XCTAssertEqual(c.name, "acme-app")
	}

	func testSelectionMatchesRichCardByBackingContainerName() {
		// Container named "tv" runs the sonarr image → backs the "sonarr" card.
		let cards = [Card(id: "sonarr", title: "Sonarr", group: "Acquisition")]
		let containers = [container("tv", image: "lscr.io/linuxserver/sonarr")]
		let selected = mergeTiles(cards: cards, containers: containers, selection: ["tv"])
		XCTAssertEqual(selected.count, 1)
		guard case .rich(let card) = selected[0] else { return XCTFail("expected rich") }
		XCTAssertEqual(card.id, "sonarr")
		// And deselecting it removes the rich card.
		XCTAssertTrue(mergeTiles(cards: cards, containers: containers, selection: ["x"]).isEmpty)
	}

	func testOrderAppliesToTiles() {
		let containers = [container("a"), container("b"), container("c")]
		let config = CardConfig(order: ["c", "a"])
		let tiles = mergeTiles(cards: [], containers: containers, config: config)
		let names = tiles.compactMap { if case .generic(let c, _) = $0 { c.name } else { nil } }
		XCTAssertEqual(names, ["c", "a", "b"])
	}

	func testGenericTileSynthesizesWidgetCard() {
		let config = CardConfig(renames: ["acme-app": "Acme"])
		let tile = DashboardTile.generic(container("acme-app", image: "ghcr.io/acme/acme-app"), nil)
		let card = tile.asWidgetCard(config: config)
		XCTAssertEqual(card.id, "acme-app")   // deep-link target = container name
		XCTAssertEqual(card.title, "Acme")
		XCTAssertEqual(card.status, .up)
	}
}

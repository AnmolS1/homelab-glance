import XCTest
@testable import GlanceKit

final class ServiceTypeTests: XCTestCase {
	// MARK: - Detection

	func testDetectsFromImageRef() {
		XCTAssertEqual(ServiceType.detect(image: "jellyfin/jellyfin:latest", name: "media"), .jellyfin)
		XCTAssertEqual(ServiceType.detect(image: "lscr.io/linuxserver/sonarr:4.0", name: "tv"), .sonarr)
		XCTAssertEqual(ServiceType.detect(image: "pihole/pihole:2024.07", name: "dns"), .pihole)
		XCTAssertEqual(ServiceType.detect(image: "ghcr.io/qbittorrent/qbittorrent", name: "dl"), .qbittorrent)
	}

	func testDetectsFromNameWhenImageIsOpaque() {
		XCTAssertEqual(ServiceType.detect(image: "ghcr.io/custom/build:1", name: "radarr"), .radarr)
		XCTAssertEqual(ServiceType.detect(image: nil, name: "prowlarr"), .prowlarr)
	}

	func testImageWinsOverName() {
		// Image says jellyfin even though the name says sonarr.
		XCTAssertEqual(ServiceType.detect(image: "jellyfin/jellyfin", name: "sonarr"), .jellyfin)
	}

	func testUnknownContainerDetectsNil() {
		XCTAssertNil(ServiceType.detect(image: "ghcr.io/acme/acme-app:1.4.2", name: "acme-app"))
		XCTAssertNil(ServiceType.detect(image: nil, name: "backup-runner"))
	}

	func testPiHoleHyphenVariant() {
		XCTAssertEqual(ServiceType.detect(image: nil, name: "pi-hole"), .pihole)
	}

	// MARK: - Merge

	private func container(_ name: String, image: String? = nil, running: Bool = true) -> DockerContainer {
		DockerContainer(id: String(name.prefix(12)), name: name, image: image,
		                state: running ? "running" : "exited",
		                status: running ? "Up 2 days" : "Exited (0)", controllable: true)
	}

	func testRichWinsWhenCardPresent() {
		let cards = [Card(id: "jellyfin", title: "Jellyfin", group: "Media")]
		let containers = [container("jellyfin", image: "jellyfin/jellyfin")]
		let tiles = mergeTiles(cards: cards, containers: containers)
		XCTAssertEqual(tiles.count, 1)
		guard case .rich(let card) = tiles[0] else { return XCTFail("expected rich tile") }
		XCTAssertEqual(card.id, "jellyfin")
	}

	func testUnknownContainerFallsBackToGeneric() {
		let cards = [Card(id: "jellyfin", title: "Jellyfin", group: "Media")]
		let containers = [
			container("jellyfin", image: "jellyfin/jellyfin"),
			container("acme-app", image: "ghcr.io/acme/acme-app"),
		]
		let tiles = mergeTiles(cards: cards, containers: containers)
		XCTAssertEqual(tiles.count, 2)
		guard case .generic(let c, let type) = tiles[1] else { return XCTFail("expected generic tile") }
		XCTAssertEqual(c.name, "acme-app")
		XCTAssertNil(type)
	}

	func testKnownTypeWithoutRichCardRendersGeneric() {
		// Sonarr container detected, but the aggregator has no sonarr poller
		// configured → no rich card → generic tile (degrade gracefully).
		let tiles = mergeTiles(cards: [], containers: [container("sonarr", image: "linuxserver/sonarr")])
		XCTAssertEqual(tiles.count, 1)
		guard case .generic(let c, let type) = tiles[0] else { return XCTFail("expected generic tile") }
		XCTAssertEqual(c.name, "sonarr")
		XCTAssertEqual(type, .sonarr)
	}

	func testHomeCardKeyedByContainerNameIsNotDuplicated() {
		// The aggregator's fixed Home cards use the container name as the card id.
		let cards = [Card(id: "mosquitto", title: "Mosquitto", group: "Home")]
		let tiles = mergeTiles(cards: cards, containers: [container("mosquitto", image: "eclipse-mosquitto")])
		XCTAssertEqual(tiles.count, 1)
		guard case .rich = tiles[0] else { return XCTFail("expected rich tile only") }
	}

	func testSampleDashboardDecodesContainers() throws {
		let dash = try MockData.sampleDashboard()
		let containers = try XCTUnwrap(dash.containers)
		XCTAssertEqual(containers.count, 4)
		let tiles = mergeTiles(cards: dash.cards, containers: containers)
		let genericNames = tiles.compactMap { tile -> String? in
			if case .generic(let c, _) = tile { c.name } else { nil }
		}
		// jellyfin folds into its rich card; the unknowns render generic.
		XCTAssertFalse(genericNames.contains("jellyfin"))
		XCTAssertTrue(genericNames.contains("acme-app"))
		XCTAssertTrue(genericNames.contains("backup-runner"))
	}
}

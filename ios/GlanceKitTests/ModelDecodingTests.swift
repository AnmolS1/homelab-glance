import XCTest
@testable import GlanceKit

final class ModelDecodingTests: XCTestCase {

	func testDecodesBundledSample() throws {
		let dash = try MockData.sampleDashboard()

		XCTAssertEqual(dash.generatedAt, 1_751_212_800)
		XCTAssertEqual(dash.pollSeconds, 15)
		XCTAssertEqual(dash.cards.count, 8)

		// Host
		XCTAssertEqual(dash.host.name, "demo-server")
		XCTAssertEqual(dash.host.status, .up)
		XCTAssertEqual(dash.host.cpuPct, 8.4)
		XCTAssertEqual(dash.host.ramTotalGb, 32)
		XCTAssertEqual(dash.host.uptime, 824_400)

		// Sensors + histories
		let s = try XCTUnwrap(dash.host.sensors)
		XCTAssertEqual(s.nvmeTemp, 41)
		XCTAssertEqual(s.gpuTemp, 53)
		XCTAssertEqual(s.nvmeTempHistory?.count, 30)
		XCTAssertEqual(s.gpuTempHistory?.count, 30)
		XCTAssertEqual(s.gpuVramTotalMb, 16384)
		XCTAssertTrue(s.hasReadings)
	}

	func testGroupOrderingPresent() throws {
		let dash = try MockData.sampleDashboard()
		let groups = Set(dash.cards.compactMap(\.group))
		XCTAssertEqual(groups, ["Media", "Acquisition", "Infrastructure", "Home"])
	}

	func testServiceSpecificData() throws {
		let dash = try MockData.sampleDashboard()
		func card(_ id: String) throws -> Card {
			try XCTUnwrap(dash.cards.first { $0.id == id })
		}

		let jf = try card("jellyfin")
		XCTAssertEqual(jf.data?.streams, 1)
		XCTAssertEqual(jf.data?.nowPlaying?.first?.title, "The Bear — S03E01")

		let qb = try card("qbittorrent")
		XCTAssertEqual(qb.data?.dlMibps, 4.2)
		XCTAssertEqual(qb.data?.seeding, 12)

		XCTAssertEqual(try card("sonarr").data?.wanted, 5)
		XCTAssertEqual(try card("radarr").data?.missing, 8)
		XCTAssertEqual(try card("prowlarr").data?.grabs, 134)

		let ph = try card("pihole")
		XCTAssertEqual(ph.data?.queries, 84_210)
		XCTAssertEqual(ph.data?.gravity, 150_000)
		XCTAssertEqual(ph.data?.blockedPct, 14.3)
	}

	func testDownAndStaleStates() throws {
		let dash = try MockData.sampleDashboard()
		let radarr = try XCTUnwrap(dash.cards.first { $0.id == "radarr" })
		XCTAssertEqual(radarr.stale, true)

		let z2m = try XCTUnwrap(dash.cards.first { $0.id == "zigbee2mqtt" })
		XCTAssertEqual(z2m.status, .down)
		XCTAssertEqual(z2m.containerRunning, false)
		XCTAssertNil(z2m.cpuPct)
	}

	func testGraceEnvelopeDecodes() throws {
		let json = #"{"generated_at": null, "poll_seconds": 15, "host": {}, "cards": []}"#
		let dash = try JSONDecoder.glance.decode(Dashboard.self, from: Data(json.utf8))
		XCTAssertNil(dash.generatedAt)
		XCTAssertNil(dash.host.name)
		XCTAssertNil(dash.host.sensors)
		XCTAssertTrue(dash.cards.isEmpty)
	}

	func testUnknownStatusFallsBack() throws {
		let json = #"{"poll_seconds":15,"host":{"status":"degraded"},"cards":[{"id":"x","title":"X","status":"weird"}]}"#
		let dash = try JSONDecoder.glance.decode(Dashboard.self, from: Data(json.utf8))
		XCTAssertEqual(dash.host.status, .unknown)
		XCTAssertEqual(dash.cards.first?.status, .unknown)
	}
}

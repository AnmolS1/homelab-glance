import XCTest
@testable import GlanceKit

/// Pins every `Format.spoken*` helper against its visual twin so the two can't
/// drift. Where the spoken form deliberately differs (words for glyphs, trimmed
/// trailing zeros) the test asserts the intended prose explicitly and checks the
/// underlying value matches the visual string.
final class FormatSpokenTests: XCTestCase {

	// MARK: nil / dash

	func testDashSpeaksAsNoData() {
		XCTAssertEqual(Format.dash, "—")
		XCTAssertEqual(Format.spokenDash, "no data")
		// Every spoken helper falls back to the same phrase on nil.
		XCTAssertEqual(Format.spokenInt(nil), "no data")
		XCTAssertEqual(Format.spokenCompact(nil), "no data")
		XCTAssertEqual(Format.spokenMemGB(nil), "no data")
		XCTAssertEqual(Format.spokenPair(used: nil, total: 27, unit: "gigabytes"), "no data")
		XCTAssertEqual(Format.spokenUptime(nil), "no data")
		XCTAssertEqual(Format.spokenUptime(0), "no data")
		XCTAssertEqual(Format.spokenTemp(nil), "no data")
		XCTAssertEqual(Format.spokenPercent(nil), "no data")
		XCTAssertEqual(Format.spokenRelative(nil), "no data")
	}

	// MARK: integers & compact counts

	func testSpokenIntGroups() {
		XCTAssertEqual(Format.int(1234), "1234")           // visual: no grouping
		XCTAssertEqual(Format.spokenInt(1234), "1,234")    // spoken: grouped
		XCTAssertEqual(Format.spokenInt(5), "5")
		XCTAssertEqual(Format.spokenInt(1_000_000), "1,000,000")
	}

	func testSpokenCompactMirrorsCompact() {
		// Visual "1.2k" ↔ spoken "1.2 thousand"
		XCTAssertEqual(Format.compact(1234), "1.2k")
		XCTAssertEqual(Format.spokenCompact(1234), "1.2 thousand")
		// Visual "3.4M" ↔ spoken "3.4 million"
		XCTAssertEqual(Format.compact(3_400_000), "3.4M")
		XCTAssertEqual(Format.spokenCompact(3_400_000), "3.4 million")
		// Below 1000: plain grouped integer, no unit word.
		XCTAssertEqual(Format.compact(934), "934")
		XCTAssertEqual(Format.spokenCompact(934), "934")
		// Trailing-zero trim: "5.0k" reads "5 thousand".
		XCTAssertEqual(Format.compact(5000), "5.0k")
		XCTAssertEqual(Format.spokenCompact(5000), "5 thousand")
	}

	// MARK: memory / paired used-of-total

	func testSpokenMemGBMirrorsMemGB() {
		XCTAssertEqual(Format.memGB(593), "0.58 GB")
		XCTAssertEqual(Format.spokenMemGB(593), "0.58 gigabytes")
		XCTAssertEqual(Format.memGB(2048), "2.00 GB")
		XCTAssertEqual(Format.spokenMemGB(2048), "2 gigabytes")   // trailing zeros trimmed
	}

	func testSpokenPairRAM() {
		// HostHeaderView RAM twin: "5.7/27G"
		XCTAssertEqual("\(Format.num(5.7))/\(Format.num(27, unit: "G", decimals: 0))", "5.7/27G")
		XCTAssertEqual(Format.spokenPair(used: 5.7, total: 27, unit: "gigabytes"),
		               "5.7 of 27 gigabytes")
	}

	func testSpokenPairDisk() {
		// HostHeaderView DISK twin: "1.2/4.0T"
		XCTAssertEqual("\(Format.num(1.2))/\(Format.num(4, unit: "T"))", "1.2/4.0T")
		XCTAssertEqual(Format.spokenPair(used: 1.2, total: 4, unit: "terabytes",
		                                 usedDecimals: 1, totalDecimals: 1),
		               "1.2 of 4 terabytes")
	}

	func testSpokenPairDropsMissingTotal() {
		XCTAssertEqual(Format.spokenPair(used: 5.7, total: nil, unit: "gigabytes"),
		               "5.7 gigabytes")
	}

	// MARK: uptime

	func testSpokenUptimeMirrorsUptime() {
		let dayPlus = Double(5 * 86_400 + 7 * 3_600)
		XCTAssertEqual(Format.uptime(dayPlus), "5d 7h")
		XCTAssertEqual(Format.spokenUptime(dayPlus), "5 days, 7 hours")

		let hoursOnly = Double(7 * 3_600)
		XCTAssertEqual(Format.uptime(hoursOnly), "7h")
		XCTAssertEqual(Format.spokenUptime(hoursOnly), "7 hours")

		// Singular grammar.
		let oneOne = Double(86_400 + 3_600)
		XCTAssertEqual(Format.spokenUptime(oneOne), "1 day, 1 hour")

		// Days with zero remaining hours mirror the visual "5d 0h".
		let daysFlat = Double(5 * 86_400)
		XCTAssertEqual(Format.uptime(daysFlat), "5d 0h")
		XCTAssertEqual(Format.spokenUptime(daysFlat), "5 days, 0 hours")

		// Under an hour.
		XCTAssertEqual(Format.spokenUptime(600), "less than an hour")
	}

	// MARK: temperature

	func testSpokenTempMirrorsNum() {
		XCTAssertEqual(Format.num(39, unit: "°", decimals: 0), "39°")
		XCTAssertEqual(Format.spokenTemp(39), "39 degrees")
	}

	// MARK: percent

	func testSpokenPercentMirrorsNum() {
		XCTAssertEqual(Format.num(42.5, unit: "%"), "42.5%")
		XCTAssertEqual(Format.spokenPercent(42.5, decimals: 1), "42.5 percent")
		// CPU visual "0.0%" ↔ trimmed "0 percent".
		XCTAssertEqual(Format.num(0, unit: "%"), "0.0%")
		XCTAssertEqual(Format.spokenPercent(0, decimals: 1), "0 percent")
		// Zero-decimal (GPU load) form.
		XCTAssertEqual(Format.spokenPercent(66), "66 percent")
	}

	// MARK: transfer rates

	func testSpokenRates() {
		XCTAssertEqual(Format.num(0), "0.0")   // visual qB row
		XCTAssertEqual(Format.spokenRates(down: 0, up: 0),
		               "0 megabytes per second down, 0 up")
		XCTAssertEqual(Format.spokenRates(down: 1.5, up: 0.3),
		               "1.5 megabytes per second down, 0.3 up")
	}

	// MARK: chips

	func testSpokenChip() {
		XCTAssertEqual(Format.spokenChip("Queue", Format.spokenInt(4)), "queue 4")
		XCTAssertEqual(Format.spokenChip("Wanted", Format.spokenInt(3)), "wanted 3")
	}

	// MARK: series trend

	func testSpokenTrend() {
		XCTAssertEqual(Format.spokenTrend([38, 40, 45, 49]), "rising")
		XCTAssertEqual(Format.spokenTrend([49, 45, 40, 38]), "falling")
		// Jitter within tolerance reads as steady, not a trend.
		XCTAssertEqual(Format.spokenTrend([40, 41, 40, 40.3]), "steady")
		XCTAssertEqual(Format.spokenTrend([]), "steady")
		XCTAssertEqual(Format.spokenTrend([42]), "steady")
	}

	// MARK: relative timestamp

	func testSpokenRelative() {
		let now = Date(timeIntervalSince1970: 1_000_000)
		let twoMinAgo = now.addingTimeInterval(-120)
		XCTAssertEqual(Format.spokenRelative(twoMinAgo, relativeTo: now),
		               "updated 2 minutes ago")
		let oneHourAgo = now.addingTimeInterval(-3_600)
		XCTAssertEqual(Format.spokenRelative(oneHourAgo, relativeTo: now),
		               "updated 1 hour ago")
	}
}

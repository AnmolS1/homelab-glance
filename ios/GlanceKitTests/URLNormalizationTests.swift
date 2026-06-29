import XCTest
@testable import GlanceKit

final class URLNormalizationTests: XCTestCase {

	private func base(_ input: String) -> String? {
		LiveDashboardClient(baseURLString: input, token: "t")?.baseURL.absoluteString
	}

	func testRootURLUnchanged() {
		XCTAssertEqual(base("http://discofin-server.tail40f2e5.ts.net:8765"),
		               "http://discofin-server.tail40f2e5.ts.net:8765")
	}

	func testStripsDashboardSuffix() {
		XCTAssertEqual(base("http://discofin-server.tail40f2e5.ts.net:8765/api/dashboard"),
		               "http://discofin-server.tail40f2e5.ts.net:8765")
	}

	func testStripsHealthzAndTrailingSlash() {
		XCTAssertEqual(base("http://host:8765/healthz/"), "http://host:8765")
		XCTAssertEqual(base("http://host:8765/"), "http://host:8765")
	}

	func testAddsDefaultScheme() {
		XCTAssertEqual(base("discofin-server.tail40f2e5.ts.net:8765"),
		               "http://discofin-server.tail40f2e5.ts.net:8765")
	}

	func testEndpointsBuildCorrectly() throws {
		let client = try XCTUnwrap(
			LiveDashboardClient(baseURLString: "http://host:8765/api/dashboard", token: "t"))
		// baseURL is the root; the client appends the paths itself.
		XCTAssertEqual(client.baseURL.appendingPathComponent("api/dashboard").absoluteString,
		               "http://host:8765/api/dashboard")
		XCTAssertEqual(client.baseURL.appendingPathComponent("healthz").absoluteString,
		               "http://host:8765/healthz")
	}

	func testEmptyIsNil() {
		XCTAssertNil(LiveDashboardClient(baseURLString: "   ", token: "t"))
	}
}

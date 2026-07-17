import Foundation

/// Value formatting helpers mirroring the `fmt` / `fmtNum` / `uptimeStr`
/// functions in the web dashboards, so the native app renders identically.
public enum Format {
	public static let dash = "—"

	/// Fixed-decimal number with optional unit suffix; `dash` when nil.
	public static func num(_ value: Double?, unit: String = "", decimals: Int = 1) -> String {
		guard let value else { return dash }
		return String(format: "%.\(decimals)f", value) + unit
	}

	/// Integer; `dash` when nil.
	public static func int(_ value: Int?) -> String {
		guard let value else { return dash }
		return String(value)
	}

	/// Compact count: 1.2k / 3.4M; `dash` when nil.
	public static func compact(_ value: Int?) -> String {
		guard let value else { return dash }
		let v = Double(value)
		if v >= 1_000_000 { return String(format: "%.1fM", v / 1_000_000) }
		if v >= 1_000 { return String(format: "%.1fk", v / 1_000) }
		return String(value)
	}

	/// Uptime seconds → "Xd Yh" / "Yh".
	public static func uptime(_ seconds: Double?) -> String {
		guard let seconds, seconds > 0 else { return dash }
		let s = Int(seconds)
		let d = s / 86_400
		let h = (s % 86_400) / 3_600
		return d > 0 ? "\(d)d \(h)h" : "\(h)h"
	}

	/// Memory MB → "x.xx GB"; `dash` when nil.
	public static func memGB(_ mb: Double?) -> String {
		guard let mb else { return dash }
		return String(format: "%.2f GB", mb / 1024)
	}

	private static let timeFormatter: DateFormatter = {
		let f = DateFormatter()
		f.dateFormat = "HH:mm:ss"
		return f
	}()

	/// "HH:mm:ss" for the footer timestamp.
	public static func clock(_ date: Date?) -> String {
		guard let date else { return dash }
		return timeFormatter.string(from: date)
	}
}

// MARK: - Spoken (accessibility) counterparts
//
// These mirror the visual formatters above but emit VoiceOver-friendly prose:
// words instead of glyphs ("—" → "no data", "°" → "degrees"), grouped counts,
// and expanded units. They are used ONLY for `accessibilityLabel`/`Value`; the
// on-screen strings stay exactly as the visual `Format.*` helpers produce them.
// Each has a unit test pinning it against its visual twin so the two can't drift.
public extension Format {
	/// Spoken stand-in for `dash` — VoiceOver reads "—" as "em dash".
	static let spokenDash = "no data"

	/// Grouped integer, locale-independent ("1,234"); `spokenDash` when nil.
	static func spokenInt(_ value: Int?) -> String {
		guard let value else { return spokenDash }
		return grouped(value)
	}

	/// Compact count spoken in words: "934" / "1.2 thousand" / "3.4 million".
	/// Twin of `compact` ("1.2k" / "3.4M"); `spokenDash` when nil.
	static func spokenCompact(_ value: Int?) -> String {
		guard let value else { return spokenDash }
		let v = Double(value)
		if v >= 1_000_000 { return spokenDecimal(v / 1_000_000, 1) + " million" }
		if v >= 1_000 { return spokenDecimal(v / 1_000, 1) + " thousand" }
		return grouped(value)
	}

	/// Single memory value MB → "0.58 gigabytes". Twin of `memGB`; `spokenDash` when nil.
	static func spokenMemGB(_ mb: Double?) -> String {
		guard let mb else { return spokenDash }
		return spokenDecimal(mb / 1024, 2) + " gigabytes"
	}

	/// Used/total pair → "5.7 of 27 gigabytes". `usedDecimals`/`totalDecimals`
	/// mirror the visual twins (RAM uses 1/0, disk 1/1). `spokenDash` when `used`
	/// is nil; drops the total clause when `total` is nil.
	static func spokenPair(used: Double?, total: Double?, unit: String,
	                       usedDecimals: Int = 1, totalDecimals: Int = 0) -> String {
		guard let used else { return spokenDash }
		let u = spokenDecimal(used, usedDecimals)
		guard let total else { return "\(u) \(unit)" }
		return "\(u) of \(spokenDecimal(total, totalDecimals)) \(unit)"
	}

	/// Uptime seconds → "5 days, 0 hours" / "7 hours" / "less than an hour".
	/// Twin of `uptime` ("5d 0h" / "7h"); `spokenDash` when nil/zero.
	static func spokenUptime(_ seconds: Double?) -> String {
		guard let seconds, seconds > 0 else { return spokenDash }
		let s = Int(seconds)
		let d = s / 86_400
		let h = (s % 86_400) / 3_600
		func plural(_ n: Int, _ word: String) -> String { "\(n) \(word)\(n == 1 ? "" : "s")" }
		if d > 0 { return "\(plural(d, "day")), \(plural(h, "hour"))" }
		if h > 0 { return plural(h, "hour") }
		return "less than an hour"
	}

	/// Temperature → "39 degrees". Twin of `num(_, unit: "°", decimals: 0)`.
	static func spokenTemp(_ celsius: Double?, decimals: Int = 0) -> String {
		guard let celsius else { return spokenDash }
		return spokenDecimal(celsius, decimals) + " degrees"
	}

	/// Percentage whose value is already in percent units (42.0 == 42%) → "42 percent".
	/// Twin of `num(_, unit: "%")`. Uses the explicit word (not the "%" glyph) so the
	/// spoken form is deterministic and locale-independent; VoiceOver reads both the same.
	static func spokenPercent(_ value: Double?, decimals: Int = 0) -> String {
		guard let value else { return spokenDash }
		return spokenDecimal(value, decimals) + " percent"
	}

	/// Down/up transfer rates → "0 megabytes per second down, 0 up".
	/// Twin of the qBittorrent `↓/↑ MiB/s` rows.
	static func spokenRates(down: Double?, up: Double?, decimals: Int = 1) -> String {
		let d = down.map { spokenDecimal($0, decimals) } ?? spokenDash
		let u = up.map { spokenDecimal($0, decimals) } ?? spokenDash
		return "\(d) megabytes per second down, \(u) up"
	}

	/// Label/value chip → "queue 4". Used by the "Q4"-style widget chips and card rows;
	/// `value` should already be spoken (e.g. via `spokenInt`).
	static func spokenChip(_ label: String, _ value: String) -> String {
		"\(label.lowercased()) \(value)"
	}

	/// Status → spoken phrase. Stale wins (as in the visual badge), and is expanded
	/// to explain what "stale" means rather than just speaking the word.
	static func spokenStatus(_ status: ServiceStatus?, stale: Bool? = nil) -> String {
		if stale == true { return "stale, data may be out of date" }
		switch status {
		case .up: return "up"
		case .down: return "down"
		default: return "status unknown"
		}
	}

	/// Direction of a short series → "rising" / "falling" / "steady", judged by the
	/// first-vs-last endpoints past a tolerance (defaults to 15% of the series range,
	/// floored at 0.5) so sensor jitter doesn't read as a trend.
	static func spokenTrend(_ data: [Double], tolerance: Double? = nil) -> String {
		guard let first = data.first, let last = data.last,
		      let lo = data.min(), let hi = data.max() else { return "steady" }
		let tol = tolerance ?? Swift.max(0.5, (hi - lo) * 0.15)
		if last > first + tol { return "rising" }
		if last < first - tol { return "falling" }
		return "steady"
	}

	/// Relative timestamp → "updated 2 minutes ago". `spokenDash` when nil.
	static func spokenRelative(_ date: Date?, relativeTo now: Date = Date()) -> String {
		guard let date else { return spokenDash }
		return "updated " + relativeFormatter.localizedString(for: date, relativeTo: now)
	}

	// MARK: private helpers

	/// Locale-independent decimal: up to `decimals` places, trailing zeros trimmed,
	/// no grouping (all spoken decimals here are small: GB/TB/temps/rates/percents).
	private static func spokenDecimal(_ v: Double, _ decimals: Int) -> String {
		var s = String(format: "%.\(decimals)f", v)   // %f is C-locale → always "."
		if s.contains(".") {
			while s.hasSuffix("0") { s.removeLast() }
			if s.hasSuffix(".") { s.removeLast() }
		}
		return s
	}

	private static func grouped(_ n: Int) -> String {
		intFormatter.string(from: NSNumber(value: n)) ?? String(n)
	}

	/// Grouped integers ("1,234"), pinned to a stable locale + explicit grouping so
	/// the separator can't drift with the device region (POSIX/C would drop it).
	/// Never mutated after init.
	private static let intFormatter: NumberFormatter = {
		let f = NumberFormatter()
		f.locale = Locale(identifier: "en_US")
		f.numberStyle = .decimal
		f.usesGroupingSeparator = true
		f.groupingSeparator = ","
		f.groupingSize = 3
		f.maximumFractionDigits = 0
		return f
	}()

	/// Full-words relative phrasing ("2 minutes ago"), pinned to English. Never mutated.
	nonisolated(unsafe) private static let relativeFormatter: RelativeDateTimeFormatter = {
		let f = RelativeDateTimeFormatter()
		f.locale = Locale(identifier: "en_US")
		f.unitsStyle = .full
		return f
	}()
}

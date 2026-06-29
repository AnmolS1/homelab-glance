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

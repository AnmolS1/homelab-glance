import SwiftUI

public extension Color {
	/// Hex initializer supporting `#RRGGBB` / `RRGGBB` and an optional alpha 0…1.
	init(hex: String, alpha: Double = 1) {
		var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
		if s.hasPrefix("#") { s.removeFirst() }
		var v: UInt64 = 0
		Scanner(string: s).scanHexInt64(&v)
		let r = Double((v & 0xFF0000) >> 16) / 255
		let g = Double((v & 0x00FF00) >> 8) / 255
		let b = Double(v & 0x0000FF) / 255
		self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
	}
}

/// The ponderance blueprint palette. Exact tokens from the app spec; `up` is a
/// derived muted green (the spec palette has no "healthy" color), while `down`
/// maps to crane and `stale` to sax.
public struct BlueprintColors: Sendable, Equatable {
	public var graph: Color        // page ground
	public var card: Color         // card fill
	public var cardQuiet: Color    // healthy-card fill: card@0.55 over graph, PRE-COMPOSITED
	                               // to a solid colour (a real .opacity(0.55) fill blanks out
	                               // on macOS when the window is occluded)
	public var ink: Color          // primary text
	public var ink60: Color        // secondary text
	public var crease: Color       // hairlines / blue accent
	public var creaseLine: Color   // faint grid + dividers
	public var crane: Color        // primary accent / down
	public var sax: Color          // gold accent / stale
	public var up: Color           // derived healthy green
	public var upText: Color       // accessible status-badge/label text (green)
	public var craneText: Color    // accessible status-badge/label text (red)
	public var saxText: Color      // accessible status-badge/label text (gold)

	public static let dark = BlueprintColors(
		graph: Color(hex: "#13202A"),
		card: Color(hex: "#182530"),
		cardQuiet: Color(hex: "#16232D"),   // #182530 @ 0.55 over #13202A
		ink: Color(hex: "#E9ECE7"),
		ink60: Color(hex: "#E9ECE7", alpha: 0.66),
		crease: Color(hex: "#82A9CE"),
		creaseLine: Color(hex: "#82A9CE", alpha: 0.22),
		crane: Color(hex: "#F5613C"),
		sax: Color(hex: "#D9A521"),
		up: Color(hex: "#6FB58A"),
		upText: Color(hex: "#6FB58A"),
		craneText: Color(hex: "#FF7A57"),
		saxText: Color(hex: "#D9A521")
	)

	public static let light = BlueprintColors(
		graph: Color(hex: "#EEF0EC"),
		card: Color(hex: "#FFFFFF"),
		cardQuiet: Color(hex: "#F7F8F6"),   // #FFFFFF @ 0.55 over #EEF0EC
		ink: Color(hex: "#1B2A33"),
		// 0.66 (not the spec's 0.62) so 12–13pt secondary text clears WCAG AA
		// (4.5:1) on both card and graph grounds; matches the dark theme's alpha.
		ink60: Color(hex: "#1B2A33", alpha: 0.66),
		crease: Color(hex: "#2E5E8C"),
		creaseLine: Color(hex: "#2E5E8C", alpha: 0.20),
		crane: Color(hex: "#E84A27"),
		sax: Color(hex: "#B8860B"),
		up: Color(hex: "#3E8E5E"),
		upText: Color(hex: "#1F6B3F"),
		craneText: Color(hex: "#A83214"),
		saxText: Color(hex: "#7A5A00")
	)

	public static func resolve(_ scheme: ColorScheme) -> BlueprintColors {
		scheme == .light ? .light : .dark
	}

	/// Status → accent color, honoring `stale` dimming first (matches glance.jsx).
	public func statusColor(_ status: ServiceStatus?, stale: Bool?) -> Color {
		if stale == true { return sax }
		switch status {
		case .up: return up
		case .down: return crane
		default: return ink60
		}
	}

	/// Accessible foreground for status badges/labels (darker in light, brighter
	/// in dark) so the small badge text clears WCAG AA on its tinted pill. Non-text
	/// status color (dots/borders/sparklines) still uses `statusColor`.
	public func statusTextColor(_ status: ServiceStatus?, stale: Bool?) -> Color {
		if stale == true { return saxText }
		switch status {
		case .up: return upText
		case .down: return craneText
		default: return ink60
		}
	}
}

// MARK: - Environment

private struct BlueprintColorsKey: EnvironmentKey {
	static let defaultValue = BlueprintColors.dark
}

public extension EnvironmentValues {
	var blueprint: BlueprintColors {
		get { self[BlueprintColorsKey.self] }
		set { self[BlueprintColorsKey.self] = newValue }
	}
}

import SwiftUI
import CoreText
import CoreGraphics

/// Registers the self-hosted OFL faces (Bricolage Grotesque, Hanken Grotesk,
/// IBM Plex Mono) bundled in GlanceKit and resolves their PostScript names by
/// keyword so variable-font naming doesn't have to be hard-coded. If a face is
/// missing, `Typography` falls back to a comparable system font.
public enum BlueprintFonts {
	nonisolated(unsafe) private static var psNames: [String: String] = [:]
	nonisolated(unsafe) private static var didRegister = false
	private static let lock = NSLock()

	/// Register all bundled `.ttf`/`.otf` faces. Idempotent; call once at launch.
	public static func registerAll() {
		lock.lock(); defer { lock.unlock() }
		guard !didRegister else { return }
		didRegister = true

		var urls: [URL] = []
		for ext in ["ttf", "otf"] {
			urls += MockData.bundle.urls(forResourcesWithExtension: ext, subdirectory: nil) ?? []
			urls += MockData.bundle.urls(forResourcesWithExtension: ext, subdirectory: "Fonts") ?? []
		}

		for url in urls {
			CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
			guard let provider = CGDataProvider(url: url as CFURL),
			      let cg = CGFont(provider),
			      let ps = cg.postScriptName as String? else { continue }
			let lower = ps.lowercased()
			if lower.contains("bricolage") {
				psNames["display"] = ps
			} else if lower.contains("hanken") {
				psNames["text"] = ps
			} else if lower.contains("mono") {
				if lower.contains("semibold") || lower.contains("medium") || lower.contains("bold") {
					psNames["monoSemibold"] = ps
				} else {
					psNames["mono"] = ps
				}
			}
		}
	}

	static func name(_ key: String) -> String? {
		lock.lock(); defer { lock.unlock() }
		return psNames[key]
	}
}

/// Semantic type ramp for the blueprint theme.
///
/// Every face is registered with `.custom(_:size:relativeTo:)` so it scales with
/// Dynamic Type (iOS) and system text-size (macOS) while keeping its exact base
/// size at the default content-size category — the current look is preserved and
/// only grows for larger settings. Callers keep passing raw point sizes; the
/// matching Dynamic Type text style is inferred from the size unless overridden.
public enum Typography {
	/// The Dynamic Type text style whose scaling curve best fits a given point size.
	static func textStyle(for size: CGFloat) -> Font.TextStyle {
		switch size {
		case ..<10.5: return .caption2
		case ..<12.5: return .footnote
		case ..<14.5: return .subheadline
		case ..<17.5: return .body
		case ..<21: return .title3
		case ..<27: return .title
		default: return .largeTitle
		}
	}

	/// Display / headings — Bricolage Grotesque, else system default.
	public static func display(_ size: CGFloat, weight: Font.Weight = .bold, relativeTo: Font.TextStyle? = nil) -> Font {
		let style = relativeTo ?? textStyle(for: size)
		if let ps = BlueprintFonts.name("display") { return .custom(ps, size: size, relativeTo: style).weight(weight) }
		return .system(style, design: .default).weight(weight)
	}

	/// Body / labels — Hanken Grotesk, else system default.
	public static func text(_ size: CGFloat, weight: Font.Weight = .regular, relativeTo: Font.TextStyle? = nil) -> Font {
		let style = relativeTo ?? textStyle(for: size)
		if let ps = BlueprintFonts.name("text") { return .custom(ps, size: size, relativeTo: style).weight(weight) }
		return .system(style, design: .default).weight(weight)
	}

	/// Numeric / monospace — IBM Plex Mono, else system monospaced.
	public static func mono(_ size: CGFloat, weight: Font.Weight = .semibold, relativeTo: Font.TextStyle? = nil) -> Font {
		let style = relativeTo ?? textStyle(for: size)
		let key = (weight == .regular || weight == .light) ? "mono" : "monoSemibold"
		if let ps = BlueprintFonts.name(key) ?? BlueprintFonts.name("mono") {
			return .custom(ps, size: size, relativeTo: style).weight(weight)
		}
		return .system(style, design: .monospaced).weight(weight)
	}
}

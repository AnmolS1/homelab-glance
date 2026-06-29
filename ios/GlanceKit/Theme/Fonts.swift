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
public enum Typography {
	/// Display / headings — Bricolage Grotesque, else system default.
	public static func display(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
		if let ps = BlueprintFonts.name("display") { return .custom(ps, size: size).weight(weight) }
		return .system(size: size, weight: weight)
	}

	/// Body / labels — Hanken Grotesk, else system default.
	public static func text(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
		if let ps = BlueprintFonts.name("text") { return .custom(ps, size: size).weight(weight) }
		return .system(size: size, weight: weight)
	}

	/// Numeric / monospace — IBM Plex Mono, else system monospaced.
	public static func mono(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
		let key = (weight == .regular || weight == .light) ? "mono" : "monoSemibold"
		if let ps = BlueprintFonts.name(key) ?? BlueprintFonts.name("mono") {
			return .custom(ps, size: size).weight(weight)
		}
		return .system(size: size, weight: weight, design: .monospaced)
	}
}

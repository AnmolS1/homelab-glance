import SwiftUI

/// The visual weight a card carries, derived from service health (v1.2
/// status-weighted redesign). Healthy recedes, trouble dominates. `down` beats
/// `stale` beats `up`, matching the within-section sort in `DashboardView`.
public enum StatusWeight: Sendable {
	case up, stale, down

	public init(status: ServiceStatus?, stale: Bool?) {
		if status == .down { self = .down }
		else if stale == true { self = .stale }
		else { self = .up }
	}
}

/// Density-derived chrome metrics shared by the app (comfortable) and the widget
/// (compact) card surfaces, so the two treatments can't drift. Values from the
/// v1.2 spec §4.
struct CardMetrics {
	let padV: CGFloat
	let padH: CGFloat
	let radius: CGFloat
	let spine: CGFloat
	let pillRadius: CGFloat
	let rowSpacing: CGFloat

	static func of(compact: Bool) -> CardMetrics {
		compact
			? CardMetrics(padV: 7, padH: 8, radius: 9, spine: 2, pillRadius: 4, rowSpacing: 3)
			: CardMetrics(padV: 8, padH: 10, radius: 12, spine: 3, pillRadius: 5, rowSpacing: 5)
	}
}

extension View {
	/// The status-weighted card surface: healthy is translucent with a faint
	/// hairline (recedes); stale gets a leading amber spine; down gets a loud
	/// status border. Clips content to the rounded rect and adds the folded corner.
	func statusCardChrome(_ weight: StatusWeight, metrics: CardMetrics,
	                      bp: BlueprintColors, increasedContrast: Bool) -> some View {
		modifier(StatusCardChrome(weight: weight, metrics: metrics, bp: bp,
		                          increasedContrast: increasedContrast))
	}
}

private struct StatusCardChrome: ViewModifier {
	let weight: StatusWeight
	let metrics: CardMetrics
	let bp: BlueprintColors
	let increasedContrast: Bool

	// Healthy cards recede on a quieter panel (a pre-composited SOLID colour, not a
	// real .opacity(0.55) — that blanks out on macOS when the window is occluded).
	// Under Increase Contrast, use the full card for maximum separation.
	private var fill: Color { weight == .up && !increasedContrast ? bp.cardQuiet : bp.card }

	private var borderColor: Color {
		switch weight {
		case .up:    return bp.crease.opacity(0.13)
		case .stale: return bp.creaseLine
		case .down:  return bp.crane.opacity(0.55)
		}
	}

	func body(content: Content) -> some View {
		let shape = RoundedRectangle(cornerRadius: metrics.radius, style: .continuous)
		content
			.padding(.vertical, metrics.padV)
			.padding(.horizontal, metrics.padH)
			// Hug content vertically: down cards render full-width outside the grid, so
			// a maxHeight fill would balloon them. Grid cards stay compact (no stretched
			// empty bottoms — the wasted space the widget pass also removed).
			.frame(maxWidth: .infinity, alignment: .topLeading)
			.background {
				ZStack(alignment: .leading) {
					shape.fill(fill)
					if weight == .stale {
						bp.sax.frame(width: metrics.spine)
					}
				}
				.clipShape(shape)
			}
			.overlay { shape.strokeBorder(borderColor, lineWidth: 1) }
			.overlay(alignment: .topTrailing) { FoldedCorner().padding(5) }
	}
}

/// The loud full-width `● DOWN` strip at the top of a down card (app density).
/// Text is the accessible down-label colour rendered directly on the card — no
/// extra tint behind it (spec §8: down-on-down-tint fails WCAG in dark).
struct DownBanner: View {
	@Environment(\.blueprint) private var bp
	var compact: Bool = false

	var body: some View {
		HStack(spacing: 5) {
			Circle().fill(bp.crane).frame(width: 6, height: 6)
			Text("DOWN")
				.font(Typography.mono(11, weight: .medium))
				.tracking(0.7)
				.foregroundStyle(bp.statusTextColor(.down, stale: false))
			Spacer(minLength: 0)
		}
		.padding(.bottom, compact ? 1 : 3)
		.overlay(alignment: .bottom) {
			if !compact { bp.crane.opacity(0.3).frame(height: 1) }
		}
		.accessibilityHidden(true)   // the card's spokenSummary already says "down"
	}
}

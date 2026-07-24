import WidgetKit
import SwiftUI
import GlanceKit

// The reusable layout pieces (host line, mini card, sensors, footer, grid body)
// live in GlanceKit/WidgetCards.swift so they render headlessly for verification.
// This file keeps only the WidgetKit-specific wrappers: the per-family layouts and
// the entry view (family switch, containerBackground, widgetURL).

// MARK: - System families

private struct SmallView: View {
	@Environment(\.blueprint) private var bp
	let dash: Dashboard

	var body: some View {
		VStack(alignment: .leading, spacing: 4) {
			HStack(spacing: 5) {
				LogoMark(size: 15)
				Text(dash.host.name ?? "homelab")
					.font(Typography.display(12, weight: .semibold))
					.foregroundStyle(bp.ink).lineLimit(1)
			}
			Spacer(minLength: 0)
			Text(dash.downCount == 0 ? "All up" : "\(dash.downCount) down")
				.font(Typography.display(22, weight: .bold))
				.foregroundStyle(dash.downCount == 0 ? bp.up : bp.crane)
				.minimumScaleFactor(0.6).lineLimit(1)
			Spacer(minLength: 0)
			HStack {
				StatPair(label: "CPU", value: Format.num(dash.host.cpuPct, unit: "%"))
				Spacer()
				StatPair(label: "DISK",
				         value: dash.diskPercent != nil ? Format.num(dash.diskPercent, unit: "%", decimals: 0) : Format.dash,
				         alignment: .trailing)
			}
		}
		.accessibilityElement(children: .ignore)
		.accessibilityLabel(summaryLabel)
	}

	private var summaryLabel: String {
		let health = dash.downCount == 0 ? "all services up" : "\(dash.downCount) down"
		var out = "\(dash.host.name ?? "homelab"), \(health). CPU \(Format.spokenPercent(dash.host.cpuPct, decimals: 1))"
		if let d = dash.diskPercent { out += ", disk \(Format.spokenPercent(d, decimals: 0))" }
		return out
	}
}

private struct MediumView: View {
	@Environment(\.blueprint) private var bp
	let dash: Dashboard
	let cards: [Card]
	let layout: WidgetLayoutOption
	let density: WidgetDensity

	private var cols: [GridItem] {
		layout == .list
			? [GridItem(.flexible())]
			: [GridItem(.flexible()), GridItem(.flexible())]
	}
	private var limit: Int {
		switch (layout, density) {
		case (.grid, .compact): 10
		case (.grid, .regular): 8
		case (.list, .compact): 5
		case (.list, .regular): 4
		}
	}

	var body: some View {
		VStack(alignment: .leading, spacing: 8) {
			WidgetHostLine(dash: dash)
			Rectangle().fill(bp.creaseLine).frame(height: 1)
			LazyVGrid(columns: cols, alignment: .leading, spacing: density == .compact ? 3 : 4) {
				ForEach(cards.prefix(limit)) { WidgetServiceChip(card: $0) }
			}
			Spacer(minLength: 0)
		}
	}
}

/// iOS / macOS `systemLarge` — host line, an equal-height grid of every selected
/// card, dual-sparkline sensors, and the footer. Thin wrapper: maps the intent to
/// `WidgetGridBody`, which does the (renderable, ViewThatFits-free) layout.
private struct LargeView: View {
	let dash: Dashboard
	let cards: [Card]
	let layout: WidgetLayoutOption
	let density: WidgetDensity
	let updated: Date

	private var limit: Int {
		switch (layout, density) {
		case (.grid, .compact): 10
		case (.grid, .regular): 8
		case (.list, .compact): 7
		case (.list, .regular): 5
		}
	}

	var body: some View {
		WidgetGridBody(dash: dash,
		               cards: Array(cards.prefix(limit)),
		               columns: layout == .list ? 1 : 2,
		               cardSpacing: density == .compact ? 4 : 5,
		               updated: updated)
	}
}

/// iPad / macOS `systemExtraLarge` — a WIDE, short tile: every service in a 4–5
/// column grid via the same `WidgetGridBody`.
private struct ExtraLargeView: View {
	let dash: Dashboard
	let cards: [Card]
	let layout: WidgetLayoutOption
	let density: WidgetDensity
	let updated: Date

	var body: some View {
		WidgetGridBody(dash: dash,
		               cards: Array(cards.prefix(density == .compact ? 15 : 12)),
		               columns: layout == .list ? 2 : (density == .compact ? 5 : 4),
		               cardSpacing: 8,
		               updated: updated)
	}
}

// MARK: - Lock Screen accessories (iOS)

#if os(iOS)
private struct CircularView: View {
	let dash: Dashboard
	var body: some View {
		Gauge(value: min(max((dash.diskPercent ?? 0) / 100, 0), 1)) {
			Text("DISK")
		} currentValueLabel: {
			Text(Format.num(dash.diskPercent, unit: "", decimals: 0))
		}
		.gaugeStyle(.accessoryCircularCapacity)
			.accessibilityLabel("Disk usage")
			.accessibilityValue(Format.spokenPercent(dash.diskPercent, decimals: 0))
	}
}

private struct RectangularView: View {
	let dash: Dashboard
	var body: some View {
		VStack(alignment: .leading, spacing: 1) {
			Text(dash.host.name ?? "homelab").font(.headline).lineLimit(1)
			Text(dash.healthLine).font(.caption)
			Text("CPU \(Format.num(dash.host.cpuPct, unit: "%"))  RAM \(Format.num(dash.host.ramUsedGb, unit: "G"))")
				.font(.caption2)
		}
		.accessibilityElement(children: .combine)
	}
}
#endif

// MARK: - Entry view

struct DashboardWidgetEntryView: View {
	@Environment(\.widgetFamily) private var family
	@Environment(\.colorScheme) private var scheme
	var entry: DashboardEntry

	private var isAccessory: Bool {
		#if os(iOS)
		return family == .accessoryInline || family == .accessoryCircular || family == .accessoryRectangular
		#else
		return false
		#endif
	}

	var body: some View {
		let bp = BlueprintColors.resolve(scheme)
		content(bp)
			.environment(\.blueprint, bp)
			// Fixed-frame backstop: widgets can't scroll and the large tiles have no
			// runtime fallback now (density is tuned to fit at default), so cap
			// enlargement at a level the tiles can still lay out. Still honors Dynamic
			// Type up through accessibility1 (the v1.1 a11y scaling).
			.dynamicTypeSize(...DynamicTypeSize.accessibility1)
			.overlay(alignment: .topTrailing) {
				if !isAccessory { FoldedCorner().padding(6) }
			}
			.containerBackground(for: .widget) {
				if isAccessory { Color.clear } else { GraphPaperBackground() }
			}
			// Whole-widget tap target (small tile + gaps between cards): open the
			// container list. Per-card `Link`s override their own regions to open logs.
			.widgetURL(DeepLink.containers.url)
	}

	@ViewBuilder
	private func content(_ bp: BlueprintColors) -> some View {
		if let dash = entry.dashboard {
			switch family {
			case .systemSmall: SmallView(dash: dash)
			case .systemMedium: MediumView(dash: dash, cards: entry.cards, layout: entry.layout, density: entry.density)
			case .systemLarge: LargeView(dash: dash, cards: entry.cards, layout: entry.layout, density: entry.density, updated: dash.generatedAtDate ?? entry.date)
			case .systemExtraLarge: ExtraLargeView(dash: dash, cards: entry.cards, layout: entry.layout, density: entry.density, updated: dash.generatedAtDate ?? entry.date)
			#if os(iOS)
			case .accessoryInline: Text(dash.healthLine)
			case .accessoryCircular: CircularView(dash: dash)
			case .accessoryRectangular: RectangularView(dash: dash)
			#endif
			default: SmallView(dash: dash)
			}
		} else {
			VStack(spacing: 4) {
				Image(systemName: "wifi.exclamationmark").foregroundStyle(bp.crane).accessibilityHidden(true)
				Text(entry.unreachable ? "Unreachable" : "Open app to set up")
					.font(Typography.text(11)).foregroundStyle(bp.ink60)
					.multilineTextAlignment(.center)
			}
		}
	}
}

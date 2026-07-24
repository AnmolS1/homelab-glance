import WidgetKit
import SwiftUI
import GlanceKit

// MARK: - Compact pieces

/// A compact status chip: status dot + service name + a short metric. Tapping it
/// deep-links to the service's logs in the app.
private struct ServiceChip: View {
	@Environment(\.blueprint) private var bp
	let card: Card

	var body: some View {
		CardLink(card: card) {
			HStack(spacing: 5) {
				Circle()
					.fill(bp.statusColor(card.status, stale: card.stale))
					.frame(width: 6, height: 6)
				Text(card.title)
					.font(Typography.text(11, weight: .medium))
					.foregroundStyle(bp.ink)
					.lineLimit(1)
				Spacer(minLength: 2)
				if let m = card.widgetMetric {
					Text(m)
						.font(Typography.mono(10, weight: .semibold))
						.foregroundStyle(bp.ink60)
						.lineLimit(1)
				}
			}
			.accessibilityElement(children: .ignore)
			.accessibilityLabel(chipLabel)
		}
	}

	private var chipLabel: String {
		var out = "\(card.title), \(Format.spokenStatus(card.status, stale: card.stale))"
		if let m = card.spokenWidgetMetric { out += ", \(m)" }
		return out
	}
}

/// Wraps a card view in a `Link` to the service's logs. `.widgetURL` only allows
/// one URL per widget, so the multi-card families use per-card `Link`s instead;
/// `Link` inside a widget is supported on iOS 17 / macOS 14.
private struct CardLink<Content: View>: View {
	let card: Card
	@ViewBuilder let content: () -> Content

	var body: some View {
		if let url = DeepLink.logs(container: card.id).url {
			Link(destination: url) { content() }
		} else {
			content()
		}
	}
}

/// Compact host line: rosette + name + UP/DOWN + key host stats.
private struct HostLine: View {
	@Environment(\.blueprint) private var bp
	let dash: Dashboard
	var showStats: Bool = true

	var body: some View {
		VStack(alignment: .leading, spacing: 4) {
			HStack(spacing: 6) {
				LogoMark(size: 16)
				Text(dash.host.name ?? "homelab")
					.font(Typography.display(13, weight: .bold))
					.foregroundStyle(bp.ink)
					.lineLimit(1)
				StatusBadge(status: dash.host.status, stale: dash.host.stale)
				Spacer(minLength: 0)
			}
			if showStats {
				HStack(spacing: 10) {
					Text("CPU \(Format.num(dash.host.cpuPct, unit: "%"))")
					Text("RAM \(Format.num(dash.host.ramUsedGb))/\(Format.num(dash.host.ramTotalGb, unit: "G", decimals: 0))")
					Text("DISK \(Format.num(dash.host.diskUsedTb))/\(Format.num(dash.host.diskTotalTb, unit: "T"))")
					Text("UP \(Format.uptime(dash.host.uptime))")
				}
				.font(Typography.mono(9, weight: .regular))
				.foregroundStyle(bp.ink60)
				.lineLimit(1)
				.minimumScaleFactor(0.7)
			}
		}
		.accessibilityElement(children: .ignore)
		.accessibilityLabel(hostLabel)
	}

	private var hostLabel: String {
		var parts = [dash.host.name ?? "homelab", Format.spokenStatus(dash.host.status, stale: dash.host.stale)]
		if showStats {
			parts.append("CPU \(Format.spokenPercent(dash.host.cpuPct, decimals: 1)), "
				+ "RAM \(Format.spokenPair(used: dash.host.ramUsedGb, total: dash.host.ramTotalGb, unit: "gigabytes")), "
				+ "disk \(Format.spokenPair(used: dash.host.diskUsedTb, total: dash.host.diskTotalTb, unit: "terabytes", usedDecimals: 1, totalDecimals: 1)), "
				+ "uptime \(Format.spokenUptime(dash.host.uptime))")
		}
		return parts.joined(separator: ". ")
	}
}

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
			HostLine(dash: dash)
			Rectangle().fill(bp.creaseLine).frame(height: 1)
			LazyVGrid(columns: cols, alignment: .leading, spacing: density == .compact ? 3 : 4) {
				ForEach(cards.prefix(limit)) { ServiceChip(card: $0) }
			}
			Spacer(minLength: 0)
		}
	}
}

/// Footer "updated HH:MM:SS".
private struct UpdatedFooter: View {
	@Environment(\.blueprint) private var bp
	let date: Date
	var body: some View {
		HStack {
			Spacer()
			Text("updated \(Format.clock(date))")
				.font(Typography.mono(9, weight: .regular))
				.foregroundStyle(bp.ink60.opacity(0.7))
		}
	}
}

/// Tight sensors block for the systemLarge tile: NVMe + GPU temps each with their
/// own sparkline, plus a load/power/VRAM line. Denser than the in-app `SensorsView`.
private struct CompactSensors: View {
	@Environment(\.blueprint) private var bp
	let s: Sensors
	/// Drop the LOAD/POWER/VRAM line, keeping only the two temperature sparklines —
	/// the medium-detail fallback the large tiles fall back to when space is tight.
	var tempsOnly: Bool = false

	private func row(_ label: String, _ temp: Double, _ history: [Double]?, _ color: Color) -> some View {
		let data = history ?? []
		let accessible = data.count >= 2
		return HStack(spacing: 6) {
			Text(label).frame(width: 34, alignment: .leading).foregroundStyle(bp.ink60)
				.accessibilityHidden(accessible)
			Text(Format.num(temp, unit: "°", decimals: 0)).frame(width: 26, alignment: .leading).foregroundStyle(bp.ink)
				.accessibilityLabel("\(label) temperature, \(Format.spokenTemp(temp))")
				.accessibilityHidden(accessible)
			SparklineView(data: data, color: color,
			              accessibilityLabel: accessible ? "\(label) temperature" : nil,
			              accessibilityValue: accessible ? "\(Format.spokenTemp(temp)), range \(Int((data.min() ?? temp).rounded())) to \(Int((data.max() ?? temp).rounded())) over the last \(data.count) readings, trending \(Format.spokenTrend(data))" : nil,
			              unitLabel: "degrees")
				.frame(height: 12).frame(maxWidth: .infinity)
		}
	}

	var body: some View {
		VStack(alignment: .leading, spacing: 2) {
			if let t = s.nvmeTemp { row("NVMe", t, s.nvmeTempHistory, bp.sax) }
			if let t = s.gpuTemp { row("GPU", t, s.gpuTempHistory, bp.up) }
			if !tempsOnly {
				HStack(spacing: 12) {
					if let l = s.gpuLoadPct { Text("LOAD \(Format.num(l, unit: "%", decimals: 0))") }
					if let p = s.gpuPowerW { Text("POWER \(Format.num(p, unit: "W", decimals: 0))") }
					if let u = s.gpuVramUsedMb, let tot = s.gpuVramTotalMb {
						Text("VRAM \(Format.num(u / 1024))/\(Format.num(tot / 1024, unit: "G", decimals: 0))")
					}
				}
				.foregroundStyle(bp.ink60)
				.accessibilityElement(children: .ignore)
				.accessibilityLabel(gpuSpoken)
			}
		}
		.font(Typography.mono(8, weight: .semibold))
	}

	private var gpuSpoken: String {
		var out: [String] = []
		if let l = s.gpuLoadPct { out.append("load \(Format.spokenPercent(l, decimals: 0))") }
		if let p = s.gpuPowerW { out.append("power \(Int(p.rounded())) watts") }
		if let u = s.gpuVramUsedMb, let tot = s.gpuVramTotalMb {
			out.append("VRAM \(Format.spokenPair(used: u / 1024, total: tot / 1024, unit: "gigabytes"))")
		}
		return out.joined(separator: ", ")
	}
}

/// A tight 2–3 line service card tuned for the dense `systemLarge` tile: title +
/// UP/STALE/DOWN badge, a small CPU·MEM line, and the service's key metrics.
/// (Extra-large / macOS use the full in-app `ServiceCardView`.)
private struct MiniCard: View {
	@Environment(\.blueprint) private var bp
	let card: Card

	private var borderColor: Color {
		if card.stale == true { return bp.sax.opacity(0.45) }
		if card.status == .down { return bp.crane.opacity(0.4) }
		return bp.creaseLine
	}

	private var metrics: [String] {
		let d = card.data ?? CardData()
		switch card.id {
		case "jellyfin":
			var out = ["STREAMS \(Format.int(d.streams))"]
			if let np = d.nowPlaying?.first { out.append("▶ \(np.title)") }
			return out
		case "qbittorrent":
			return ["↓\(Format.num(d.dlMibps)) ↑\(Format.num(d.ulMibps))",
			        "ACT/SEED \(Format.int(d.active))/\(Format.int(d.seeding))"]
		case "sonarr": return ["QUEUE \(Format.int(d.queue)) · WANT \(Format.int(d.wanted))"]
		case "radarr": return ["QUEUE \(Format.int(d.queue)) · MISS \(Format.int(d.missing))"]
		case "pihole":
			return ["BLK \(d.blockedPct != nil ? Format.num(d.blockedPct, unit: "%", decimals: 0) : Format.dash) · \(Format.compact(d.queries))",
			        "GRAV \(d.gravity != nil ? String(format: "%.2fM", (d.gravity ?? 0) / 1_000_000) : Format.dash)"]
		default: return []
		}
	}

	var body: some View {
		CardLink(card: card) {
			VStack(alignment: .leading, spacing: 1) {
				HStack(spacing: 4) {
					Text(card.title).font(Typography.display(11, weight: .semibold))
						.foregroundStyle(bp.ink).lineLimit(1)
					Spacer(minLength: 2)
					StatusBadge(status: card.status, stale: card.stale)
				}
				if card.cpuPct != nil || card.memMb != nil {
					Text("CPU \(Format.num(card.cpuPct, unit: "%")) · MEM \(Format.memGB(card.memMb))")
						.font(Typography.mono(8, weight: .regular)).foregroundStyle(bp.ink60).lineLimit(1)
				}
				ForEach(metrics, id: \.self) { m in
					Text(m).font(Typography.mono(9, weight: .semibold)).foregroundStyle(bp.ink)
						.lineLimit(1).minimumScaleFactor(0.7)
				}
			}
			.padding(7)
			// Hug content vertically (no maxHeight fill): stretching short cards to the
			// row's tallest left empty bottoms that read as wasted space. Full width
			// still equalizes columns.
			.frame(maxWidth: .infinity, alignment: .topLeading)
			.background(bp.card, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
			.overlay { RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(borderColor, lineWidth: 1) }
			.opacity(card.status == .down ? 0.6 : 1)
			.accessibilityElement(children: .ignore)
			.accessibilityLabel(card.spokenSummary)
		}
	}
}

/// iOS / macOS `systemLarge` — Scriptable-parity density: slim host line
/// (CPU/RAM/DISK/UPTIME + UP), a `MiniCard` per selected tile (CPU/MEM + key
/// metrics + status), a compact dual-sparkline sensors block, and the footer.
private struct LargeView: View {
	@Environment(\.blueprint) private var bp
	let dash: Dashboard
	let cards: [Card]
	let layout: WidgetLayoutOption
	let density: WidgetDensity
	let updated: Date

	private var cols: [GridItem] {
		layout == .list
			? [GridItem(.flexible())]
			: [GridItem(.flexible(), spacing: 5), GridItem(.flexible(), spacing: 5)]
	}
	private var limit: Int {
		switch (layout, density) {
		case (.grid, .compact): 10
		case (.grid, .regular): 8
		case (.list, .compact): 7
		case (.list, .regular): 5
		}
	}

	var body: some View {
		let shown = Array(cards.prefix(limit))
		// The square tile can't scroll, so pick the richest layout that FITS instead
		// of overflowing and clipping the header. Candidates are ordered richest →
		// lightest and are all Spacer-free — a flexible Spacer would report "fits" at
		// any height and defeat the fallback (see the MiniCard/ViewThatFits note).
		ViewThatFits(in: .vertical) {
			column(shown, sensors: .full)
			column(shown, sensors: .tempsOnly)
			column(shown, sensors: .none)
			column(WidgetPriority.problemsFirst(shown, keeping: 4), sensors: .none)
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
	}

	@ViewBuilder
	private func column(_ cards: [Card], sensors: SensorDetail) -> some View {
		VStack(alignment: .leading, spacing: 5) {
			HostLine(dash: dash)
			Rectangle().fill(bp.creaseLine).frame(height: 1)
			LazyVGrid(columns: cols, alignment: .leading, spacing: density == .compact ? 4 : 5) {
				ForEach(cards) { MiniCard(card: $0) }
			}
			if let s = dash.host.sensors, s.hasReadings, sensors != .none {
				CompactSensors(s: s, tempsOnly: sensors == .tempsOnly)
			}
			UpdatedFooter(date: updated)
		}
	}
}

/// How much of the sensor block a large tile shows, richest first. `full` = temps +
/// LOAD/POWER/VRAM; `tempsOnly` = just the two sparklines; `none` = omit entirely.
private enum SensorDetail { case full, tempsOnly, none }

/// Truncation helper for the tightest widget fallbacks: surface down/stale services
/// first so a problem is never the card that gets dropped, then keep the original
/// (CardConfig) order within each tier.
private enum WidgetPriority {
	static func problemsFirst(_ cards: [Card], keeping count: Int) -> [Card] {
		func rank(_ c: Card) -> Int {
			if c.status == .down { return 0 }
			if c.stale == true { return 1 }
			return 2
		}
		// Stable: enumerate so equal-rank cards keep their original CardConfig order.
		return Array(cards.enumerated()
			.sorted { (rank($0.element), $0.offset) < (rank($1.element), $1.offset) }
			.map(\.element)
			.prefix(count))
	}
}

/// iPad / macOS `systemExtraLarge` — a WIDE, short tile. Every service (adds
/// Prowlarr + HOME) as a `MiniCard` in a 4-column grid (2 rows), with a slim host
/// line and compact sensors so nothing clips top/bottom on the short tile.
private struct ExtraLargeView: View {
	@Environment(\.blueprint) private var bp
	let dash: Dashboard
	let cards: [Card]
	let layout: WidgetLayoutOption
	let density: WidgetDensity
	let updated: Date

	private var cols: [GridItem] {
		let count = layout == .list ? 2 : (density == .compact ? 5 : 4)
		return Array(repeating: GridItem(.flexible(), spacing: 8), count: count)
	}

	var body: some View {
		let shown = Array(cards.prefix(density == .compact ? 15 : 12))
		// Same fit-not-clip strategy as the large tile: this wide-short tile overflows
		// at large text sizes too. Spacer-free candidates, richest → lightest.
		ViewThatFits(in: .vertical) {
			column(shown, sensors: .full)
			column(shown, sensors: .tempsOnly)
			column(shown, sensors: .none)
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
	}

	@ViewBuilder
	private func column(_ cards: [Card], sensors: SensorDetail) -> some View {
		VStack(alignment: .leading, spacing: 8) {
			HostLine(dash: dash)
			Rectangle().fill(bp.creaseLine).frame(height: 1)
			LazyVGrid(columns: cols, alignment: .leading, spacing: 8) {
				ForEach(cards) { MiniCard(card: $0) }
			}
			if let s = dash.host.sensors, s.hasReadings, sensors != .none {
				CompactSensors(s: s, tempsOnly: sensors == .tempsOnly)
			}
			UpdatedFooter(date: updated)
		}
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
			// Fixed-frame backstop: widgets can't scroll, so cap enlargement at a level
			// the tiles can still lay out. ViewThatFits does the real graceful
			// degradation on the large tiles; this bounds small/medium/accessory. Still
			// honors Dynamic Type up through accessibility1 (the v1.1 a11y scaling).
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

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
		}
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

	private func row(_ label: String, _ temp: Double, _ history: [Double]?, _ color: Color) -> some View {
		HStack(spacing: 6) {
			Text(label).frame(width: 34, alignment: .leading).foregroundStyle(bp.ink60)
			Text(Format.num(temp, unit: "°", decimals: 0)).frame(width: 26, alignment: .leading).foregroundStyle(bp.ink)
			SparklineView(data: history ?? [], color: color).frame(height: 12).frame(maxWidth: .infinity)
		}
	}

	var body: some View {
		VStack(alignment: .leading, spacing: 2) {
			if let t = s.nvmeTemp { row("NVMe", t, s.nvmeTempHistory, bp.sax) }
			if let t = s.gpuTemp { row("GPU", t, s.gpuTempHistory, bp.up) }
			HStack(spacing: 12) {
				if let l = s.gpuLoadPct { Text("LOAD \(Format.num(l, unit: "%", decimals: 0))") }
				if let p = s.gpuPowerW { Text("POWER \(Format.num(p, unit: "W", decimals: 0))") }
				if let u = s.gpuVramUsedMb, let tot = s.gpuVramTotalMb {
					Text("VRAM \(Format.num(u / 1024))/\(Format.num(tot / 1024, unit: "G", decimals: 0))")
				}
			}
			.foregroundStyle(bp.ink60)
		}
		.font(Typography.mono(8, weight: .semibold))
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
			// Fill the grid cell so cards in the same row share the tallest's height.
			.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
			.background(bp.card, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
			.overlay { RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(borderColor, lineWidth: 1) }
			.opacity(card.status == .down ? 0.6 : 1)
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
		VStack(alignment: .leading, spacing: 5) {
			HostLine(dash: dash)
			Rectangle().fill(bp.creaseLine).frame(height: 1)
			LazyVGrid(columns: cols, alignment: .leading, spacing: density == .compact ? 4 : 5) {
				ForEach(cards.prefix(limit)) { MiniCard(card: $0) }
			}
			if let s = dash.host.sensors, s.hasReadings {
				CompactSensors(s: s)
			}
			Spacer(minLength: 0)
			UpdatedFooter(date: updated)
		}
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
		VStack(alignment: .leading, spacing: 8) {
			HostLine(dash: dash)
			Rectangle().fill(bp.creaseLine).frame(height: 1)
			LazyVGrid(columns: cols, alignment: .leading, spacing: 8) {
				ForEach(cards.prefix(density == .compact ? 15 : 12)) { MiniCard(card: $0) }
			}
			if let s = dash.host.sensors, s.hasReadings {
				CompactSensors(s: s)
			}
			Spacer(minLength: 0)
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
				Image(systemName: "wifi.exclamationmark").foregroundStyle(bp.crane)
				Text(entry.unreachable ? "Unreachable" : "Open app to set up")
					.font(Typography.text(11)).foregroundStyle(bp.ink60)
					.multilineTextAlignment(.center)
			}
		}
	}
}

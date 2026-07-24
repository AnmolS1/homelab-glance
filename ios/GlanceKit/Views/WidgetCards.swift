import SwiftUI

// Widget layout pieces, kept in GlanceKit (not the widget appex) so they render
// headlessly via ImageRenderer for verification — the whole reason the widget fit
// was hard to get right blind. The appex composes these; only the WidgetKit
// wrappers (family switch, containerBackground, widgetURL) stay in the extension.

/// Wraps card content in a `Link` to the service's logs. `.widgetURL` allows only
/// one URL per widget, so multi-card families use per-card `Link`s. In a plain
/// (non-widget) render context the Link is inert — fine for snapshots.
public struct WidgetCardLink<Content: View>: View {
	let card: Card
	@ViewBuilder let content: () -> Content

	public init(card: Card, @ViewBuilder content: @escaping () -> Content) {
		self.card = card
		self.content = content
	}

	public var body: some View {
		if let url = DeepLink.logs(container: card.id).url {
			Link(destination: url) { content() }
		} else {
			content()
		}
	}
}

/// A compact status chip (medium tile): dot + name + short metric.
public struct WidgetServiceChip: View {
	@Environment(\.blueprint) private var bp
	let card: Card
	public init(card: Card) { self.card = card }

	public var body: some View {
		WidgetCardLink(card: card) {
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

/// Compact host line: rosette + name + status badge + key host stats.
public struct WidgetHostLine: View {
	@Environment(\.blueprint) private var bp
	let dash: Dashboard
	var showStats: Bool

	public init(dash: Dashboard, showStats: Bool = true) {
		self.dash = dash
		self.showStats = showStats
	}

	public var body: some View {
		VStack(alignment: .leading, spacing: 3) {
			HStack(spacing: 6) {
				LogoMark(size: 15)
				Text(dash.host.name ?? "homelab")
					.font(Typography.display(12.5, weight: .bold))
					.foregroundStyle(bp.ink)
					.lineLimit(1)
				StatusBadge(status: dash.host.status, stale: dash.host.stale)
				Spacer(minLength: 0)
			}
			if showStats {
				HStack(spacing: 9) {
					Text("CPU \(Format.num(dash.host.cpuPct, unit: "%"))")
					Text("RAM \(Format.num(dash.host.ramUsedGb))/\(Format.num(dash.host.ramTotalGb, unit: "G", decimals: 0))")
					Text("DISK \(Format.num(dash.host.diskUsedTb))/\(Format.num(dash.host.diskTotalTb, unit: "T"))")
					Text("UP \(Format.uptime(dash.host.uptime))")
				}
				.font(Typography.mono(8.5, weight: .regular))
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

/// Footer "updated HH:MM:SS".
public struct WidgetUpdatedFooter: View {
	@Environment(\.blueprint) private var bp
	let date: Date
	public init(date: Date) { self.date = date }
	public var body: some View {
		HStack {
			Spacer()
			Text("updated \(Format.clock(date))")
				.font(Typography.mono(8.5, weight: .regular))
				.foregroundStyle(bp.ink60.opacity(0.7))
		}
	}
}

/// Tight dual-sparkline sensors block for the large tiles: NVMe + GPU temps each
/// with a sparkline, plus a load/power/VRAM line (dropped when `tempsOnly`).
public struct WidgetCompactSensors: View {
	@Environment(\.blueprint) private var bp
	let s: Sensors
	var tempsOnly: Bool

	public init(s: Sensors, tempsOnly: Bool = false) {
		self.s = s
		self.tempsOnly = tempsOnly
	}

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
				.frame(height: 13).frame(maxWidth: .infinity)
		}
	}

	public var body: some View {
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

/// A tight 2–3 line service card for the large tiles: title + status badge, a
/// small CPU·MEM line, and the service's key metrics. Equal-height (fills its grid
/// cell) so cards in a row align instead of centring raggedly.
public struct WidgetMiniCard: View {
	@Environment(\.blueprint) private var bp
	let card: Card
	public init(card: Card) { self.card = card }

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
		case "prowlarr": return ["QUEUE \(Format.int(d.queue)) · GRABS \(Format.int(d.grabs))"]
		case "pihole":
			return ["BLK \(d.blockedPct != nil ? Format.num(d.blockedPct, unit: "%", decimals: 0) : Format.dash) · \(Format.compact(d.queries))",
			        "GRAV \(d.gravity != nil ? String(format: "%.2fM", (d.gravity ?? 0) / 1_000_000) : Format.dash)"]
		default: return []
		}
	}

	public var body: some View {
		WidgetCardLink(card: card) {
			VStack(alignment: .leading, spacing: 1) {
				HStack(spacing: 4) {
					Text(card.title).font(Typography.display(10.5, weight: .semibold))
						.foregroundStyle(bp.ink).lineLimit(1)
					Spacer(minLength: 2)
					StatusBadge(status: card.status, stale: card.stale)
				}
				if card.cpuPct != nil || card.memMb != nil {
					Text("CPU \(Format.num(card.cpuPct, unit: "%")) · MEM \(Format.memGB(card.memMb))")
						.font(Typography.mono(7.5, weight: .regular)).foregroundStyle(bp.ink60).lineLimit(1)
				}
				ForEach(metrics, id: \.self) { m in
					Text(m).font(Typography.mono(8.5, weight: .semibold)).foregroundStyle(bp.ink)
						.lineLimit(1).minimumScaleFactor(0.7)
				}
			}
			.padding(.vertical, 6).padding(.horizontal, 7)
			// Fill the grid cell so cards in a row share the tallest's height — the
			// aligned look. Content top-anchors within that height.
			.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
			.background(bp.card, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
			.overlay { RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(borderColor, lineWidth: 1) }
			.opacity(card.status == .down ? 0.6 : 1)
			.accessibilityElement(children: .ignore)
			.accessibilityLabel(card.spokenSummary)
		}
	}
}

/// The large / extra-large tile body: host line, an equal-height grid of every
/// selected card, the sensors block, and the footer. No `ViewThatFits` — a
/// `LazyVGrid` inside it mis-measured and dropped cards/sensors, leaving a sparse,
/// half-empty tile. Density is tuned so host + cards + sensors + footer ≈ the tile,
/// and the Dynamic Type cap (on the entry view) is the large-text backstop.
public struct WidgetGridBody: View {
	@Environment(\.blueprint) private var bp
	let dash: Dashboard
	let cards: [Card]
	let columns: Int
	let cardSpacing: CGFloat
	let showSensors: Bool
	let updated: Date

	public init(dash: Dashboard, cards: [Card], columns: Int, cardSpacing: CGFloat = 5,
	            showSensors: Bool = true, updated: Date) {
		self.dash = dash
		self.cards = cards
		self.columns = columns
		self.cardSpacing = cardSpacing
		self.showSensors = showSensors
		self.updated = updated
	}

	/// Cards chunked into rows of `columns`.
	private var rows: [[Card]] {
		stride(from: 0, to: cards.count, by: columns).map {
			Array(cards[$0 ..< min($0 + columns, cards.count)])
		}
	}

	public var body: some View {
		VStack(alignment: .leading, spacing: cardSpacing) {
			WidgetHostLine(dash: dash)
			Rectangle().fill(bp.creaseLine).frame(height: 1)
			// Equal-height rows (cards align within a row), but each row hugs its
			// tallest card — the block keeps its natural height and sits at the TOP of
			// the tile. `.fixedSize` bounds the row so the cards' maxHeight fill equalises
			// to content height instead of stretching to fill the whole tile (which
			// crammed the title against the top edge).
			ForEach(rows.indices, id: \.self) { i in
				HStack(spacing: cardSpacing) {
					ForEach(rows[i]) { WidgetMiniCard(card: $0) }
					if rows[i].count < columns {
						ForEach(0 ..< (columns - rows[i].count), id: \.self) { _ in
							Color.clear.frame(maxWidth: .infinity)
						}
					}
				}
				.fixedSize(horizontal: false, vertical: true)
			}
			if showSensors, let s = dash.host.sensors, s.hasReadings {
				WidgetCompactSensors(s: s)
			}
		}
		// Centre the block so the spare space splits evenly top/bottom (was crammed
		// against the top edge). The footer floats out of the flow in the lower margin,
		// bottom-right — absolute-positioned, so it doesn't shift the content.
		.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
		.overlay(alignment: .bottomTrailing) {
			Text("updated \(Format.clock(updated))")
				.font(Typography.mono(8.5, weight: .regular))
				.foregroundStyle(bp.ink60.opacity(0.7))
		}
	}
}

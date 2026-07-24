import SwiftUI

/// A single service card, status-weighted (v1.2): a healthy service recedes to a
/// dot + name + one condensed metric on a translucent panel; a stale one gains a
/// leading amber spine and a STALE pill; a down one turns loud — a `● DOWN`
/// banner and a status border. Trouble reads first. Shares `StatusCardChrome`
/// with `GenericContainerCardView` so the two card kinds can't drift.
public struct ServiceCardView: View {
	@Environment(\.blueprint) private var bp
	@Environment(\.colorSchemeContrast) private var contrast
	let card: Card
	var compact: Bool

	public init(card: Card, compact: Bool = false) {
		self.card = card
		self.compact = compact
	}

	private var weight: StatusWeight { StatusWeight(status: card.status, stale: card.stale) }

	public var body: some View {
		let m = CardMetrics.of(compact: compact)
		VStack(alignment: .leading, spacing: m.rowSpacing) {
			if weight == .down && !compact { DownBanner(compact: compact) }
			header
			if weight == .up {
				quietMetric
			} else {
				if !compact { containerStats }
				body(for: card)
			}
		}
		.statusCardChrome(weight, metrics: m, bp: bp, increasedContrast: contrast == .increased)
		// One VoiceOver stop per card: name → status → metrics, spoken via Format.
		.accessibilityElement(children: .ignore)
		.accessibilityLabel(card.spokenSummary)
	}

	private var header: some View {
		HStack(spacing: 6) {
			if weight == .up {
				Circle()
					.fill(bp.statusColor(card.status, stale: card.stale))
					.frame(width: 7, height: 7)
			}
			Text(card.title)
				.font(weight == .up
					? Typography.display(compact ? 12 : 12.5, weight: .medium)
					: Typography.display(compact ? 12 : 13, weight: .semibold))
				.foregroundStyle(weight == .up ? bp.ink60 : bp.ink)
				.lineLimit(1)
			Spacer(minLength: 4)
			if weight == .stale { StatusBadge(status: card.status, stale: card.stale) }
		}
	}

	/// The quiet card's single line: the service's key metric, else CPU/MEM.
	@ViewBuilder private var quietMetric: some View {
		if let metric = card.condensedMetric {
			Text(metric)
				.font(Typography.mono(compact ? 10 : 11, weight: .regular))
				.foregroundStyle(bp.ink60)
				.lineLimit(1)
		} else {
			containerStats
		}
	}

	@ViewBuilder private var containerStats: some View {
		if card.cpuPct != nil || card.memMb != nil {
			HStack(spacing: 12) {
				if let cpu = card.cpuPct { Text("CPU \(Format.num(cpu, unit: "%"))") }
				if let mem = card.memMb { Text("MEM \(Format.memGB(mem))") }
			}
			.font(Typography.mono(compact ? 9 : 10, weight: .regular))
			.foregroundStyle(bp.ink60)
		}
	}

	@ViewBuilder
	private func body(for card: Card) -> some View {
		let d = card.data ?? CardData()
		switch card.id {
		case "jellyfin":
			KVRow(key: "Streams", value: Format.int(d.streams))
			if let np = d.nowPlaying?.first {
				KVRow(key: "Playing", value: np.title, valueColor: bp.ink60)
			}
		case "qbittorrent":
			KVRow(key: "↓ MiB/s", value: Format.num(d.dlMibps))
			KVRow(key: "↑ MiB/s", value: Format.num(d.ulMibps))
			KVRow(key: "Active / Seed", value: "\(Format.int(d.active)) / \(Format.int(d.seeding))")
		case "sonarr":
			KVRow(key: "Queue", value: Format.int(d.queue))
			KVRow(key: "Wanted", value: Format.int(d.wanted))
		case "radarr":
			KVRow(key: "Queue", value: Format.int(d.queue))
			KVRow(key: "Missing", value: Format.int(d.missing))
		case "prowlarr":
			KVRow(key: "Queue", value: Format.int(d.queue))
			KVRow(key: "Grabs", value: Format.int(d.grabs))
		case "pihole":
			KVRow(key: "Blocked", value: d.blockedPct != nil ? Format.num(d.blockedPct, unit: "%") : Format.dash)
			KVRow(key: "Queries", value: Format.compact(d.queries))
			KVRow(key: "Gravity", value: d.gravity != nil ? String(format: "%.2fM", (d.gravity ?? 0) / 1_000_000) : Format.dash)
		default:
			EmptyView()  // home containers: header + container stats only
		}
	}
}

#if DEBUG
#Preview("Status weights") {
	let down = Card(id: "sonarr", title: "Sonarr", status: .down, cpuPct: 1.2, memMb: 300,
	                data: CardData(queue: 17, wanted: 17))
	let stale = Card(id: "radarr", title: "Radarr", status: .up, stale: true, cpuPct: 1.0, memMb: 290,
	                 data: CardData(queue: 0, missing: 3))
	let up = Card(id: "jellyfin", title: "Jellyfin", status: .up, cpuPct: 0.1, memMb: 720,
	              data: CardData(streams: 1))
	return VStack(alignment: .leading, spacing: 8) {
		ServiceCardView(card: down)
		LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 8)], spacing: 8) {
			ServiceCardView(card: stale)
			ServiceCardView(card: up)
		}
	}
	.padding(16)
	.background(BlueprintColors.dark.graph)
	.environment(\.blueprint, .dark)
}
#endif

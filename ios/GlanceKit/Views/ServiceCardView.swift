import SwiftUI

/// A single service card: card chrome (fill, folded corner, status border,
/// down-dimming) + a header (title, container CPU/MEM, status badge) + a
/// service-specific body keyed on `card.id` — mirroring glance.jsx's renderCard.
public struct ServiceCardView: View {
	@Environment(\.blueprint) private var bp
	let card: Card
	var compact: Bool

	public init(card: Card, compact: Bool = false) {
		self.card = card
		self.compact = compact
	}

	private var isDown: Bool { card.status == .down }

	private var borderColor: Color {
		if card.stale == true { return bp.sax.opacity(0.45) }
		if isDown { return bp.crane.opacity(0.4) }
		return bp.creaseLine
	}

	public var body: some View {
		VStack(alignment: .leading, spacing: 6) {
			header
			if !compact { containerStats }
			body(for: card)
		}
		.padding(compact ? 9 : 11)
		.frame(maxWidth: .infinity, alignment: .leading)
		.background(bp.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
		.overlay(alignment: .topTrailing) { FoldedCorner().padding(5) }
		.overlay {
			RoundedRectangle(cornerRadius: 12, style: .continuous)
				.strokeBorder(borderColor, lineWidth: 1)
		}
		.opacity(isDown ? 0.6 : 1)
	}

	private var header: some View {
		HStack(spacing: 6) {
			Text(card.title)
				.font(Typography.display(13, weight: .semibold))
				.foregroundStyle(bp.ink)
				.lineLimit(1)
			Spacer(minLength: 4)
			StatusBadge(status: card.status, stale: card.stale)
		}
	}

	@ViewBuilder private var containerStats: some View {
		if card.cpuPct != nil || card.memMb != nil {
			HStack(spacing: 12) {
				if let cpu = card.cpuPct {
					Text("CPU \(Format.num(cpu, unit: "%"))")
				}
				if let mem = card.memMb {
					Text("MEM \(Format.memGB(mem))")
				}
			}
			.font(Typography.mono(10, weight: .regular))
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

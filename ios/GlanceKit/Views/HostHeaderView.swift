import SwiftUI

/// Dashboard header: rosette + host name + UP/DOWN badge, then the
/// CPU / RAM / DISK / UPTIME stat strip.
public struct HostHeaderView: View {
	@Environment(\.blueprint) private var bp
	@Environment(\.dynamicTypeSize) private var dynamicTypeSize
	let host: HostSummary
	var rosetteAnimated: Bool
	/// Fleet alert counts, surfaced as chips right after the server name.
	var downCount: Int
	var staleCount: Int

	public init(host: HostSummary, rosetteAnimated: Bool = true,
	            downCount: Int = 0, staleCount: Int = 0) {
		self.host = host
		self.rosetteAnimated = rosetteAnimated
		self.downCount = downCount
		self.staleCount = staleCount
	}

	public var body: some View {
		VStack(alignment: .leading, spacing: 12) {
			HStack(spacing: 10) {
				LogoMark(size: 26)
				Text(host.name ?? "homelab")
					.font(Typography.display(18, weight: .semibold))
					.foregroundStyle(bp.ink)
					.lineLimit(1)
					.minimumScaleFactor(0.8)
				StatusBadge(status: host.status, stale: host.stale)
				Spacer(minLength: 0)
			}

			// Fleet alerts — the second thing read after the name. Omitted when clear.
			if downCount > 0 || staleCount > 0 {
				HStack(spacing: 8) {
					if downCount > 0 { AlertChip(count: downCount, down: true) }
					if staleCount > 0 { AlertChip(count: staleCount, down: false) }
					Spacer(minLength: 0)
				}
			}

			// Four-up horizontally, but at accessibility text sizes the row would
			// overflow — stack it (branch on isAccessibilitySize, never ViewThatFits).
			if dynamicTypeSize.isAccessibilitySize {
				VStack(alignment: .leading, spacing: 8) { statPairs }
			} else {
				HStack(alignment: .top, spacing: 18) { statPairs; Spacer(minLength: 0) }
			}
		}
		// The dashboard's top summary: one VoiceOver stop, and a rotor landmark.
		.accessibilityElement(children: .ignore)
		.accessibilityLabel(accessibilityDescription)
		.accessibilityAddTraits(.isHeader)
	}

	@ViewBuilder private var statPairs: some View {
		StatPair(label: "CPU", value: Format.num(host.cpuPct, unit: "%"))
		StatPair(label: "RAM",
		         value: "\(Format.num(host.ramUsedGb))/\(Format.num(host.ramTotalGb, unit: "G", decimals: 0))")
		StatPair(label: "DISK",
		         value: "\(Format.num(host.diskUsedTb))/\(Format.num(host.diskTotalTb, unit: "T"))")
		StatPair(label: "UPTIME", value: Format.uptime(host.uptime))
	}

	private var accessibilityDescription: String {
		var parts: [String] = [
			host.name ?? "homelab",
			Format.spokenStatus(host.status, stale: host.stale),
		]
		var stats: [String] = ["CPU \(Format.spokenPercent(host.cpuPct, decimals: 1))"]
		stats.append("RAM \(Format.spokenPair(used: host.ramUsedGb, total: host.ramTotalGb, unit: "gigabytes"))")
		stats.append("disk \(Format.spokenPair(used: host.diskUsedTb, total: host.diskTotalTb, unit: "terabytes", usedDecimals: 1, totalDecimals: 1))")
		stats.append("uptime \(Format.spokenUptime(host.uptime))")
		parts.append(stats.joined(separator: ", "))
		return parts.joined(separator: ". ")
	}
}

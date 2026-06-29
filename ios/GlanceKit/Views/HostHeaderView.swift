import SwiftUI

/// Dashboard header: rosette + host name + UP/DOWN badge, then the
/// CPU / RAM / DISK / UPTIME stat strip.
public struct HostHeaderView: View {
	@Environment(\.blueprint) private var bp
	let host: HostSummary
	var rosetteAnimated: Bool

	public init(host: HostSummary, rosetteAnimated: Bool = true) {
		self.host = host
		self.rosetteAnimated = rosetteAnimated
	}

	public var body: some View {
		VStack(alignment: .leading, spacing: 12) {
			HStack(spacing: 10) {
				LogoMark(size: 26)
				Text(host.name ?? "homelab")
					.font(Typography.display(20, weight: .bold))
					.foregroundStyle(bp.ink)
					.lineLimit(1)
					.minimumScaleFactor(0.6)
				StatusBadge(status: host.status, stale: host.stale)
				Spacer(minLength: 0)
			}

			HStack(alignment: .top, spacing: 18) {
				StatPair(label: "CPU", value: Format.num(host.cpuPct, unit: "%"))
				StatPair(label: "RAM",
				         value: "\(Format.num(host.ramUsedGb))/\(Format.num(host.ramTotalGb, unit: "G", decimals: 0))")
				StatPair(label: "DISK",
				         value: "\(Format.num(host.diskUsedTb))/\(Format.num(host.diskTotalTb, unit: "T"))")
				StatPair(label: "UPTIME", value: Format.uptime(host.uptime))
				Spacer(minLength: 0)
			}
		}
	}
}

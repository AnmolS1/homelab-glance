import SwiftUI

/// The universal container card for auto-detected containers no rich poller
/// covers. Status-weighted (v1.2) like `ServiceCardView`: a running container
/// recedes to a dot + name + uptime on a translucent panel; a stopped one turns
/// loud with a `● DOWN` banner and a status border. Shares `StatusCardChrome`.
public struct GenericContainerCardView: View {
	@Environment(\.blueprint) private var bp
	@Environment(\.colorSchemeContrast) private var contrast
	let container: DockerContainer
	let serviceType: ServiceType?
	let stats: ContainerStats?
	var compact: Bool

	public init(
		container: DockerContainer,
		serviceType: ServiceType? = nil,
		stats: ContainerStats? = nil,
		compact: Bool = false
	) {
		self.container = container
		self.serviceType = serviceType
		self.stats = stats
		self.compact = compact
	}

	private var weight: StatusWeight { container.isRunning ? .up : .down }

	public var body: some View {
		let m = CardMetrics.of(compact: compact)
		VStack(alignment: .leading, spacing: m.rowSpacing) {
			if weight == .down && !compact { DownBanner(compact: compact) }
			header
			if weight == .up {
				quietLine
			} else {
				if !compact { statsRow }
				if let status = container.status, !status.isEmpty {
					KVRow(key: "State", value: status, valueColor: bp.ink60)
				}
			}
		}
		.statusCardChrome(weight, metrics: m, bp: bp, increasedContrast: contrast == .increased)
		.accessibilityElement(children: .ignore)
		.accessibilityLabel(accessibilityDescription)
	}

	private var header: some View {
		HStack(spacing: 6) {
			if weight == .up {
				Circle().fill(bp.up).frame(width: 7, height: 7)
			}
			Text(container.name)
				.font(weight == .up
					? Typography.display(compact ? 12 : 12.5, weight: .medium)
					: Typography.display(compact ? 12 : 13, weight: .semibold))
				.foregroundStyle(weight == .up ? bp.ink60 : bp.ink)
				.lineLimit(1)
				.truncationMode(.middle)
			Spacer(minLength: 4)
			if !container.controllable {
				Image(systemName: "lock.fill")
					.font(.system(size: 9, weight: .semibold))
					.foregroundStyle(bp.ink60)
					.accessibilityLabel("Not controllable")
			}
		}
	}

	/// Quiet (running) card's single line: uptime, else CPU/MEM if sampled.
	@ViewBuilder private var quietLine: some View {
		if let status = container.status, !status.isEmpty {
			Text(status)
				.font(Typography.mono(compact ? 10 : 11, weight: .regular))
				.foregroundStyle(bp.ink60)
				.lineLimit(1)
		} else {
			statsRow
		}
	}

	@ViewBuilder private var statsRow: some View {
		if let stats, stats.cpuPct != nil || stats.memUsedMb != nil {
			HStack(spacing: 12) {
				if let cpu = stats.cpuPct { Text("CPU \(Format.num(cpu, unit: "%"))") }
				if let mem = stats.memUsedMb { Text("MEM \(Format.memGB(mem))") }
			}
			.font(Typography.mono(compact ? 9 : 10, weight: .regular))
			.foregroundStyle(bp.ink60)
		}
	}

	/// "qbittorrent, running. CPU 2 percent, memory 0.31 gigabytes. uptime Up 3 hours. Not controllable."
	private var accessibilityDescription: String {
		var parts: [String] = [container.name, container.isRunning ? "running" : "stopped"]

		if let stats {
			var s: [String] = []
			if let cpu = stats.cpuPct { s.append("CPU \(Format.spokenPercent(cpu, decimals: 1))") }
			if let mem = stats.memUsedMb { s.append("memory \(Format.spokenMemGB(mem))") }
			if !s.isEmpty { parts.append(s.joined(separator: ", ")) }
		}
		if let status = container.status, !status.isEmpty {
			parts.append(container.isRunning ? "uptime \(status)" : "state \(status)")
		}
		if !container.controllable { parts.append("not controllable") }

		return parts.joined(separator: ". ")
	}
}

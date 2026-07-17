import SwiftUI

/// The universal container card for auto-detected containers no rich poller
/// covers: name, running dot, uptime from the raw status string, and (in-app,
/// fetched lazily — never in the widget timeline) one CPU/mem sample.
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

	private var isDown: Bool { !container.isRunning }

	private var borderColor: Color {
		isDown ? bp.crane.opacity(0.4) : bp.creaseLine
	}

	public var body: some View {
		VStack(alignment: .leading, spacing: 6) {
			header
			if !compact { statsRow }
			if let status = container.status, !status.isEmpty {
				KVRow(key: container.isRunning ? "Uptime" : "State", value: status, valueColor: bp.ink60)
			}
		}
		.padding(compact ? 9 : 11)
		.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
		.background(bp.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
		.overlay(alignment: .topTrailing) { FoldedCorner().padding(5) }
		.overlay {
			RoundedRectangle(cornerRadius: 12, style: .continuous)
				.strokeBorder(borderColor, lineWidth: 1)
		}
		.opacity(isDown && contrast != .increased ? 0.6 : 1)
		.accessibilityElement(children: .ignore)
		.accessibilityLabel(accessibilityDescription)
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

	private var header: some View {
		HStack(spacing: 6) {
			Circle()
				.fill(container.isRunning ? bp.up : bp.crane)
				.frame(width: 7, height: 7)
			Text(container.name)
				.font(Typography.display(13, weight: .semibold))
				.foregroundStyle(bp.ink)
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

	@ViewBuilder private var statsRow: some View {
		if let stats, stats.cpuPct != nil || stats.memUsedMb != nil {
			HStack(spacing: 12) {
				if let cpu = stats.cpuPct {
					Text("CPU \(Format.num(cpu, unit: "%"))")
				}
				if let mem = stats.memUsedMb {
					Text("MEM \(Format.memGB(mem))")
				}
			}
			.font(Typography.mono(10, weight: .regular))
			.foregroundStyle(bp.ink60)
		}
	}
}

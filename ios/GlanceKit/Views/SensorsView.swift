import SwiftUI

/// Sensors section, elevated to its own panel (v1.2 spec §6): a card surface with
/// a stronger accent border and the folded-corner motif, holding NVMe + GPU
/// temperature cells (label · large temp · sparkline) and a LOAD / POWER / VRAM
/// readout. Phone: 2-up temps with the readout beneath; wide (iPad/Mac): 3-up with
/// the readout as a third divided cell.
public struct SensorsView: View {
	@Environment(\.blueprint) private var bp
	#if os(iOS)
	@Environment(\.horizontalSizeClass) private var hSize
	private var wide: Bool { hSize == .regular }
	#else
	private var wide: Bool { true }
	#endif
	let sensors: Sensors

	public init(sensors: Sensors) { self.sensors = sensors }

	public var body: some View {
		if sensors.hasReadings {
			VStack(alignment: .leading, spacing: 8) {
				SectionLabel("Sensors")
				panel
					.padding(12)
					.frame(maxWidth: .infinity, alignment: .leading)
					.background(bp.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
					.overlay(alignment: .topTrailing) { FoldedCorner(size: 10).padding(6) }
					.overlay {
						RoundedRectangle(cornerRadius: 12, style: .continuous)
							.strokeBorder(bp.crease.opacity(0.28), lineWidth: 1)
					}
			}
		}
	}

	@ViewBuilder private var panel: some View {
		if wide {
			HStack(alignment: .top, spacing: 16) {
				tempCells
				if hasReadout {
					divider
					readout(vertical: true).frame(maxWidth: .infinity, alignment: .leading)
				}
			}
			// Hug content height: the flexible-height divider would otherwise become
			// the greediest child and balloon the panel to fill the (vertically
			// centred) iPad viewport. fixedSize pins the row to the cells' height, and
			// the divider then fills that.
			.fixedSize(horizontal: false, vertical: true)
		} else {
			VStack(alignment: .leading, spacing: 14) {
				HStack(alignment: .top, spacing: 16) { tempCells }
				if hasReadout { readout(vertical: false) }
			}
		}
	}

	@ViewBuilder private var tempCells: some View {
		if let t = sensors.nvmeTemp {
			tempCell(label: "NVMe", spokenLabel: "NVMe temperature",
			         current: t, history: sensors.nvmeTempHistory, color: bp.sax)
		}
		if let t = sensors.gpuTemp {
			tempCell(label: "GPU", spokenLabel: "GPU temperature",
			         current: t, history: sensors.gpuTempHistory, color: bp.up)
		}
	}

	private var divider: some View {
		Rectangle().fill(bp.creaseLine).frame(width: 1)
	}

	private func tempCell(label: String, spokenLabel: String, current: Double,
	                      history: [Double]?, color: Color) -> some View {
		let data = history ?? []
		// The sparkline carries the spoken summary + audio graph when it has a
		// series; otherwise the label/value text stay audible to VoiceOver.
		let accessible = data.count >= 2
		return VStack(alignment: .leading, spacing: 5) {
			Text(label.uppercased())
				.font(Typography.mono(10, weight: .medium))
				.tracking(0.8)
				.foregroundStyle(bp.ink60)
				.accessibilityHidden(accessible)
			Text(Format.num(current, unit: "°", decimals: 0))
				.font(Typography.mono(18, weight: .medium))
				.foregroundStyle(bp.ink)
				.accessibilityLabel("\(spokenLabel), \(Format.spokenTemp(current))")
				.accessibilityHidden(accessible)
			SparklineView(data: data, color: color,
			              accessibilityLabel: accessible ? spokenLabel : nil,
			              accessibilityValue: accessible ? seriesSummary(current: current, data: data) : nil,
			              unitLabel: "degrees")
				.frame(height: 26)
				.frame(maxWidth: .infinity, alignment: .leading)
		}
		.frame(maxWidth: .infinity, alignment: .leading)
	}

	/// "39 degrees, range 38 to 49 over the last 30 readings, trending steady"
	private func seriesSummary(current: Double, data: [Double]) -> String {
		let lo = Int((data.min() ?? current).rounded())
		let hi = Int((data.max() ?? current).rounded())
		return "\(Format.spokenTemp(current)), range \(lo) to \(hi) "
			+ "over the last \(data.count) readings, trending \(Format.spokenTrend(data))"
	}

	private var readoutParts: [(String, String)] {
		var out: [(String, String)] = []
		if let l = sensors.gpuLoadPct { out.append(("Load", Format.num(l, unit: "%", decimals: 0))) }
		if let p = sensors.gpuPowerW { out.append(("Power", Format.num(p, unit: "W", decimals: 0))) }
		if let used = sensors.gpuVramUsedMb, let total = sensors.gpuVramTotalMb {
			out.append(("VRAM", "\(Format.num(used / 1024))/\(Format.num(total / 1024, unit: "G", decimals: 0))"))
		}
		return out
	}
	private var hasReadout: Bool { !readoutParts.isEmpty }

	@ViewBuilder private func readout(vertical: Bool) -> some View {
		let layout = vertical
			? AnyLayout(VStackLayout(alignment: .leading, spacing: 6))
			: AnyLayout(HStackLayout(spacing: 18))
		layout {
			ForEach(readoutParts, id: \.0) { part in
				HStack(spacing: 5) {
					Text(part.0.uppercased())
						.font(Typography.mono(9, weight: .medium))
						.tracking(0.5)
						.foregroundStyle(bp.ink60)
					Text(part.1)
						.font(Typography.mono(11, weight: .semibold))
						.foregroundStyle(bp.ink)
				}
			}
		}
		.accessibilityElement(children: .ignore)
		.accessibilityLabel(gpuDetailSpoken)
	}

	/// "load 66 percent, power 120 watts, VRAM 3.5 of 8 gigabytes"
	private var gpuDetailSpoken: String {
		var out: [String] = []
		if let l = sensors.gpuLoadPct { out.append("load \(Format.spokenPercent(l, decimals: 0))") }
		if let p = sensors.gpuPowerW { out.append("power \(Int(p.rounded())) watts") }
		if let used = sensors.gpuVramUsedMb, let total = sensors.gpuVramTotalMb {
			out.append("VRAM \(Format.spokenPair(used: used / 1024, total: total / 1024, unit: "gigabytes"))")
		}
		return out.joined(separator: ", ")
	}
}

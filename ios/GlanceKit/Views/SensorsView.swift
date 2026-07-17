import SwiftUI

/// Sensors section: NVMe + GPU temperature with sparklines, plus a GPU
/// load / power / VRAM detail line. Mirrors SensorsSection in glance.jsx.
public struct SensorsView: View {
	@Environment(\.blueprint) private var bp
	let sensors: Sensors

	public init(sensors: Sensors) { self.sensors = sensors }

	public var body: some View {
		if sensors.hasReadings {
			VStack(alignment: .leading, spacing: 8) {
				SectionLabel("Sensors")

				if let t = sensors.nvmeTemp {
					sensorRow(label: "NVMe", spokenLabel: "NVMe temperature",
					          current: t, history: sensors.nvmeTempHistory, color: bp.sax)
				}
				if let t = sensors.gpuTemp {
					sensorRow(label: "GPU", spokenLabel: "GPU temperature",
					          current: t, history: sensors.gpuTempHistory, color: bp.up)
				}

				gpuDetail
			}
		}
	}

	private func sensorRow(label: String, spokenLabel: String, current: Double,
	                       history: [Double]?, color: Color) -> some View {
		let data = history ?? []
		// The sparkline carries the spoken summary + audio graph when it has a
		// series; otherwise the label/value text stay audible to VoiceOver.
		let accessible = data.count >= 2
		return HStack(spacing: 10) {
			Text(label.uppercased())
				.font(Typography.text(10, weight: .medium))
				.tracking(0.4)
				.foregroundStyle(bp.ink60)
				.frame(width: 46, alignment: .leading)
				.accessibilityHidden(accessible)
			Text(Format.num(current, unit: "°", decimals: 0))
				.font(Typography.mono(13, weight: .semibold))
				.foregroundStyle(bp.ink)
				.frame(width: 40, alignment: .leading)
				.accessibilityLabel("\(spokenLabel), \(Format.spokenTemp(current))")
				.accessibilityHidden(accessible)
			SparklineView(data: data, color: color,
			              accessibilityLabel: accessible ? spokenLabel : nil,
			              accessibilityValue: accessible ? seriesSummary(current: current, data: data) : nil,
			              unitLabel: "degrees")
				.frame(height: 24)
				.frame(maxWidth: .infinity)
		}
	}

	/// "39 degrees, range 38 to 49 over the last 30 readings, trending steady"
	private func seriesSummary(current: Double, data: [Double]) -> String {
		let lo = Int((data.min() ?? current).rounded())
		let hi = Int((data.max() ?? current).rounded())
		return "\(Format.spokenTemp(current)), range \(lo) to \(hi) "
			+ "over the last \(data.count) readings, trending \(Format.spokenTrend(data))"
	}

	@ViewBuilder private var gpuDetail: some View {
		let parts: [(String, String)] = {
			var out: [(String, String)] = []
			if let l = sensors.gpuLoadPct { out.append(("Load", Format.num(l, unit: "%", decimals: 0))) }
			if let p = sensors.gpuPowerW { out.append(("Power", Format.num(p, unit: "W", decimals: 0))) }
			if let used = sensors.gpuVramUsedMb, let total = sensors.gpuVramTotalMb {
				out.append(("VRAM", "\(Format.num(used / 1024))/\(Format.num(total / 1024, unit: "G", decimals: 0))"))
			}
			return out
		}()

		if !parts.isEmpty {
			HStack(spacing: 16) {
				ForEach(parts, id: \.0) { part in
					HStack(spacing: 4) {
						Text(part.0.uppercased())
							.font(Typography.text(9, weight: .medium))
							.foregroundStyle(bp.ink60)
						Text(part.1)
							.font(Typography.mono(10, weight: .semibold))
							.foregroundStyle(bp.ink)
					}
				}
			}
			.padding(.leading, 56)
			// One VoiceOver stop for the GPU detail line, spoken via Format.
			.accessibilityElement(children: .ignore)
			.accessibilityLabel(gpuDetailSpoken)
		}
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

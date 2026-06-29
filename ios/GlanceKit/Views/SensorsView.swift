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
					sensorRow(label: "NVMe", value: Format.num(t, unit: "°", decimals: 0),
					          history: sensors.nvmeTempHistory, color: bp.sax)
				}
				if let t = sensors.gpuTemp {
					sensorRow(label: "GPU", value: Format.num(t, unit: "°", decimals: 0),
					          history: sensors.gpuTempHistory, color: bp.up)
				}

				gpuDetail
			}
		}
	}

	private func sensorRow(label: String, value: String, history: [Double]?, color: Color) -> some View {
		HStack(spacing: 10) {
			Text(label.uppercased())
				.font(Typography.text(10, weight: .medium))
				.tracking(0.4)
				.foregroundStyle(bp.ink60)
				.frame(width: 46, alignment: .leading)
			Text(value)
				.font(Typography.mono(13, weight: .semibold))
				.foregroundStyle(bp.ink)
				.frame(width: 40, alignment: .leading)
			SparklineView(data: history ?? [], color: color)
				.frame(height: 24)
				.frame(maxWidth: .infinity)
		}
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
		}
	}
}

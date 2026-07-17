import SwiftUI
import Accessibility

/// A minimal line chart normalized to its own min/max, mirroring the SVG/Canvas
/// sparklines in the web dashboards. Stretches to fill its frame.
///
/// When an `accessibilityLabel` is supplied and there are ≥2 points, the sparkline
/// becomes a single VoiceOver element with a spoken summary (`accessibilityValue`)
/// AND an audio graph (`AXChartDescriptor`) — so a VoiceOver user can *play* the
/// temperature history as sound, Apple's built-in sonification.
public struct SparklineView: View {
	let data: [Double]
	var color: Color
	var lineWidth: CGFloat
	var axLabel: String?
	var axValue: String?
	var unitLabel: String

	public init(
		data: [Double],
		color: Color,
		lineWidth: CGFloat = 1.5,
		accessibilityLabel: String? = nil,
		accessibilityValue: String? = nil,
		unitLabel: String = ""
	) {
		self.data = data
		self.color = color
		self.lineWidth = lineWidth
		self.axLabel = accessibilityLabel
		self.axValue = accessibilityValue
		self.unitLabel = unitLabel
	}

	private var hasAccessibleSeries: Bool { axLabel != nil && data.count >= 2 }

	private var chart: some View {
		GeometryReader { geo in
			if data.count >= 2 {
				let minV = data.min() ?? 0
				let maxV = data.max() ?? 1
				let range = (maxV - minV) == 0 ? 1 : (maxV - minV)
				let w = geo.size.width
				let h = geo.size.height
				Path { p in
					for (i, v) in data.enumerated() {
						let x = w * CGFloat(i) / CGFloat(data.count - 1)
						let y = h - CGFloat((v - minV) / range) * h
						let pt = CGPoint(x: x, y: y)
						if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
					}
				}
				.stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
			}
		}
	}

	public var body: some View {
		if hasAccessibleSeries, let label = axLabel {
			chart
				.accessibilityElement()
				.accessibilityLabel(label)
				.accessibilityValue(axValue ?? "")
				.accessibilityChartDescriptor(
					SparklineChartDescriptor(title: label, unit: unitLabel, data: data)
				)
		} else {
			chart
				.accessibilityHidden(true)   // a bare line conveys nothing to VoiceOver
		}
	}
}

/// Bridges a temperature series to VoiceOver's Audio Graph (`AXChartDescriptor`).
struct SparklineChartDescriptor: AXChartDescriptorRepresentable {
	let title: String
	let unit: String
	let data: [Double]

	func makeChartDescriptor() -> AXChartDescriptor {
		let lo = data.min() ?? 0
		let hi = data.max() ?? 1
		let yUpper = hi > lo ? hi : lo + 1

		let xAxis = AXNumericDataAxisDescriptor(
			title: "reading",
			range: 0...Double(max(1, data.count - 1)),
			gridlinePositions: []
		) { value in "reading \(Int(value.rounded()) + 1)" }

		let yAxis = AXNumericDataAxisDescriptor(
			title: unit.isEmpty ? "value" : unit,
			range: lo...yUpper,
			gridlinePositions: []
		) { value in unit.isEmpty ? "\(Int(value.rounded()))" : "\(Int(value.rounded())) \(unit)" }

		let points = data.enumerated().map { AXDataPoint(x: Double($0.offset), y: $0.element) }
		let series = AXDataSeriesDescriptor(name: title, isContinuous: true, dataPoints: points)

		return AXChartDescriptor(title: title, summary: nil, xAxis: xAxis, yAxis: yAxis,
		                         additionalAxes: [], series: [series])
	}

	func updateChartDescriptor(_ descriptor: AXChartDescriptor) {}
}

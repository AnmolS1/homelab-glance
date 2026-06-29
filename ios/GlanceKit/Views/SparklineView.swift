import SwiftUI

/// A minimal line chart normalized to its own min/max, mirroring the SVG/Canvas
/// sparklines in the web dashboards. Stretches to fill its frame.
public struct SparklineView: View {
	let data: [Double]
	var color: Color
	var lineWidth: CGFloat

	public init(data: [Double], color: Color, lineWidth: CGFloat = 1.5) {
		self.data = data
		self.color = color
		self.lineWidth = lineWidth
	}

	public var body: some View {
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
}

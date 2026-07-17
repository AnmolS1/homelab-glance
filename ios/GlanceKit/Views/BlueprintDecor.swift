import SwiftUI

/// Faint graph-paper grid over the graph-colored ground.
public struct GraphPaperBackground: View {
	@Environment(\.blueprint) private var bp
	var spacing: CGFloat

	public init(spacing: CGFloat = 22) { self.spacing = spacing }

	public var body: some View {
		bp.graph.overlay {
			Canvas { ctx, size in
				var path = Path()
				var x: CGFloat = 0
				while x <= size.width {
					path.move(to: CGPoint(x: x, y: 0))
					path.addLine(to: CGPoint(x: x, y: size.height))
					x += spacing
				}
				var y: CGFloat = 0
				while y <= size.height {
					path.move(to: CGPoint(x: 0, y: y))
					path.addLine(to: CGPoint(x: size.width, y: y))
					y += spacing
				}
				ctx.stroke(path, with: .color(bp.creaseLine), lineWidth: 0.5)
			}
		}
		.ignoresSafeArea()
	}
}

/// A small folded-corner tick for the top-trailing corner of a card.
public struct FoldedCorner: View {
	@Environment(\.blueprint) private var bp
	var size: CGFloat

	public init(size: CGFloat = 9) { self.size = size }

	public var body: some View {
		Path { p in
			p.move(to: CGPoint(x: size, y: 0))
			p.addLine(to: CGPoint(x: size, y: size))
			p.addLine(to: CGPoint(x: 0, y: 0))
			p.closeSubpath()
		}
		.fill(bp.creaseLine)
		.frame(width: size, height: size)
	}
}

/// The rosette mark in the header: a crease ring, crane spokes, sax center dot.
/// `animated` controls the slow rotation — turn it off in widgets (no animation).
public struct RosetteMark: View {
	@Environment(\.blueprint) private var bp
	@Environment(\.accessibilityReduceMotion) private var reduceMotion
	@State private var spin = false
	var size: CGFloat
	var animated: Bool

	/// Honor Reduce Motion: no rotation when the user has it enabled.
	private var shouldAnimate: Bool { animated && !reduceMotion }

	public init(size: CGFloat = 22, animated: Bool = true) {
		self.size = size
		self.animated = animated
	}

	public var body: some View {
		Canvas { ctx, sz in
			let c = CGPoint(x: sz.width / 2, y: sz.height / 2)
			let r = min(sz.width, sz.height) / 2 - 1

			let ring = Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r))
			ctx.stroke(ring, with: .color(bp.crease), lineWidth: 1)

			var spokes = Path()
			let n = 8
			for i in 0..<n {
				let a = Double(i) / Double(n) * 2 * .pi
				spokes.move(to: c)
				spokes.addLine(to: CGPoint(x: c.x + cos(a) * r, y: c.y + sin(a) * r))
			}
			ctx.stroke(spokes, with: .color(bp.crane), lineWidth: 0.8)

			let dot = Path(ellipseIn: CGRect(x: c.x - 1.5, y: c.y - 1.5, width: 3, height: 3))
			ctx.fill(dot, with: .color(bp.sax))
		}
		.frame(width: size, height: size)
		.rotationEffect(.degrees(shouldAnimate && spin ? 360 : 0))
		.animation(shouldAnimate ? .linear(duration: 36).repeatForever(autoreverses: false) : nil, value: spin)
		.onAppear { if shouldAnimate { spin = true } }
	}
}

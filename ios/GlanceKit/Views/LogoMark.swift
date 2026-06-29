import SwiftUI

/// The ponderance amber brand mark, rendered from the bundled `LogoAmber` asset.
/// Replaces the kaleidoscope `RosetteMark`. Static (no rotation) — suitable for
/// widgets and the app header alike.
public struct LogoMark: View {
	var size: CGFloat

	public init(size: CGFloat = 22) { self.size = size }

	public var body: some View {
		Image("LogoAmber", bundle: MockData.bundle)
			.resizable()
			.scaledToFit()
			.frame(width: size, height: size)
	}
}

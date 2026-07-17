import SwiftUI

/// UP / DOWN / STALE pill, colored by the blueprint status mapping.
public struct StatusBadge: View {
	@Environment(\.blueprint) private var bp
	let status: ServiceStatus?
	var stale: Bool?

	public init(status: ServiceStatus?, stale: Bool? = nil) {
		self.status = status
		self.stale = stale
	}

	private var label: String {
		if stale == true { return "STALE" }
		switch status {
		case .up: return "UP"
		case .down: return "DOWN"
		default: return "—"
		}
	}

	public var body: some View {
		let pill = bp.statusColor(status, stale: stale)
		Text(label)
			.font(Typography.mono(9, weight: .semibold))
			.tracking(0.5)
			.foregroundStyle(bp.statusTextColor(status, stale: stale))
			.padding(.horizontal, 6)
			.padding(.vertical, 2)
			.background(pill.opacity(0.16), in: Capsule())
			// "—"/"UP"/"DOWN"/"STALE" glyphs read poorly; speak the meaning.
			.accessibilityLabel(Format.spokenStatus(status, stale: stale))
	}
}

/// A label-over-value stat cell (uppercase label, mono value).
public struct StatPair: View {
	@Environment(\.blueprint) private var bp
	let label: String
	let value: String
	var valueColor: Color?
	var alignment: HorizontalAlignment

	public init(label: String, value: String, valueColor: Color? = nil, alignment: HorizontalAlignment = .leading) {
		self.label = label
		self.value = value
		self.valueColor = valueColor
		self.alignment = alignment
	}

	public var body: some View {
		VStack(alignment: alignment, spacing: 1) {
			Text(label.uppercased())
				.font(Typography.text(9, weight: .medium))
				.tracking(0.4)
				.foregroundStyle(bp.ink60)
				.lineLimit(1)
			Text(value)
				.font(Typography.mono(13, weight: .semibold))
				.foregroundStyle(valueColor ?? bp.ink)
				.lineLimit(1)
				.minimumScaleFactor(0.8)
		}
	}
}

/// A small uppercase section heading (groups, sensors).
public struct SectionLabel: View {
	@Environment(\.blueprint) private var bp
	let text: String

	public init(_ text: String) { self.text = text }

	public var body: some View {
		Text(text.uppercased())
			.font(Typography.text(11, weight: .semibold))
			.tracking(0.8)
			.foregroundStyle(bp.crease)
			// Let the VoiceOver rotor jump between dashboard sections.
			.accessibilityLabel(text)
			.accessibilityAddTraits(.isHeader)
	}
}

/// A key/value row (label left, value right) used inside service cards.
public struct KVRow: View {
	@Environment(\.blueprint) private var bp
	let key: String
	let value: String
	var valueColor: Color?

	public init(key: String, value: String, valueColor: Color? = nil) {
		self.key = key
		self.value = value
		self.valueColor = valueColor
	}

	public var body: some View {
		HStack(alignment: .firstTextBaseline) {
			Text(key.uppercased())
				.font(Typography.text(9, weight: .medium))
				.tracking(0.4)
				.foregroundStyle(bp.ink60)
			Spacer(minLength: 6)
			Text(value)
				.font(Typography.mono(12, weight: .semibold))
				.foregroundStyle(valueColor ?? bp.ink)
				.lineLimit(1)
				.minimumScaleFactor(0.8)
		}
	}
}

import SwiftUI

// Blueprint-styled form primitives used by Settings and the manager screens.
// Labels sit ABOVE full-width fields so long labels can never squeeze the
// input (the stock macOS `Form` lays labels beside fields and overflows).

// MARK: - Section

/// A titled card section: uppercase ink60 header, rows on a `bp.card` panel
/// with the standard 12pt corner + creaseLine border, and an optional
/// wrapping footer.
public struct BlueprintFormSection<Content: View>: View {
	@Environment(\.blueprint) private var bp
	private let title: String?
	private let footer: String?
	private let content: Content

	public init(_ title: String? = nil, footer: String? = nil, @ViewBuilder content: () -> Content) {
		self.title = title
		self.footer = footer
		self.content = content()
	}

	public var body: some View {
		VStack(alignment: .leading, spacing: 8) {
			if let title {
				Text(title.uppercased())
					.font(Typography.text(12, weight: .semibold))
					.kerning(0.8)
					.foregroundStyle(bp.ink60)
					.padding(.horizontal, 4)
			}
			VStack(alignment: .leading, spacing: 14) { content }
				.padding(14)
				.frame(maxWidth: .infinity, alignment: .leading)
				.background(bp.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
				.overlay {
					RoundedRectangle(cornerRadius: 12, style: .continuous)
						.strokeBorder(bp.creaseLine, lineWidth: 1)
				}
			if let footer {
				Text(footer)
					.font(Typography.text(12))
					.foregroundStyle(bp.ink60)
					.fixedSize(horizontal: false, vertical: true)
					.padding(.horizontal, 4)
			}
		}
	}
}

// MARK: - Field

/// Label-above-input text field. Full width, ≥44pt input, middle truncation.
/// `secure` kinds add a show/hide eye; `mono` kinds render the value in
/// IBM Plex Mono (tokens, URLs).
public struct BlueprintField: View {
	public enum Kind { case plain, secure, mono, monoSecure }

	@Environment(\.blueprint) private var bp
	private let label: String
	@Binding private var text: String
	private let kind: Kind
	private let prompt: String
	private let isURL: Bool
	@State private var revealed = false

	public init(
		_ label: String,
		text: Binding<String>,
		kind: Kind = .plain,
		prompt: String = "",
		isURL: Bool = false
	) {
		self.label = label
		self._text = text
		self.kind = kind
		self.prompt = prompt
		self.isURL = isURL
	}

	private var isSecureKind: Bool { kind == .secure || kind == .monoSecure }

	private var inputFont: Font {
		switch kind {
		case .mono, .monoSecure: Typography.mono(16, weight: .regular)
		case .plain, .secure: Typography.text(16)
		}
	}

	public var body: some View {
		VStack(alignment: .leading, spacing: 6) {
			Text(label)
				.font(Typography.text(13, weight: .semibold))
				.foregroundStyle(bp.ink)
				.fixedSize(horizontal: false, vertical: true)
			HStack(spacing: 8) {
				input
					.textFieldStyle(.plain)
					.font(inputFont)
					.foregroundStyle(bp.ink)
					.truncationMode(.middle)
					.disableAutocorrection(true)
					#if os(iOS)
					.textInputAutocapitalization(.never)
					.keyboardType(isURL ? .URL : .default)
					#endif
				if isSecureKind {
					Button {
						revealed.toggle()
					} label: {
						Image(systemName: revealed ? "eye.slash" : "eye")
							.font(.system(size: 14, weight: .semibold))
							.foregroundStyle(bp.ink60)
							.frame(width: 32, height: 32)
							.contentShape(Rectangle())
					}
					.buttonStyle(.plain)
					.accessibilityLabel(revealed ? "Hide value" : "Show value")
				}
			}
			.padding(.horizontal, 12)
			.frame(maxWidth: .infinity, minHeight: 44)
			.background(bp.graph, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
			.overlay {
				RoundedRectangle(cornerRadius: 8, style: .continuous)
					.strokeBorder(bp.creaseLine, lineWidth: 1)
			}
		}
		.frame(maxWidth: .infinity, alignment: .leading)
	}

	@ViewBuilder private var input: some View {
		if isSecureKind && !revealed {
			SecureField(prompt, text: $text)
		} else {
			TextField(prompt, text: $text)
				.textContentType(isURL ? .URL : nil)
		}
	}
}

// MARK: - Toggle row

/// A labelled toggle row tinted with the blueprint accent.
public struct BlueprintToggleRow: View {
	@Environment(\.blueprint) private var bp
	private let label: String
	@Binding private var isOn: Bool

	public init(_ label: String, isOn: Binding<Bool>) {
		self.label = label
		self._isOn = isOn
	}

	public var body: some View {
		Toggle(isOn: $isOn) {
			Text(label)
				.font(Typography.text(15))
				.foregroundStyle(bp.ink)
				.fixedSize(horizontal: false, vertical: true)
		}
		.toggleStyle(.switch)
		.tint(bp.crease)
		.frame(minHeight: 32)
	}
}

// MARK: - Action row

/// A prominent blueprint button with a busy spinner and an inline wrapping
/// result line (ink60 for success, crane for errors) — the Test-connection row.
public struct BlueprintActionRow: View {
	@Environment(\.blueprint) private var bp
	private let title: String
	private let busy: Bool
	private let result: String?
	private let isError: Bool
	private let disabled: Bool
	private let action: () -> Void

	public init(
		title: String,
		busy: Bool = false,
		result: String? = nil,
		isError: Bool = false,
		disabled: Bool = false,
		action: @escaping () -> Void
	) {
		self.title = title
		self.busy = busy
		self.result = result
		self.isError = isError
		self.disabled = disabled
		self.action = action
	}

	public var body: some View {
		VStack(alignment: .leading, spacing: 8) {
			Button(action: action) {
				HStack(spacing: 8) {
					Text(title)
						.font(Typography.text(15, weight: .semibold))
					if busy {
						ProgressView()
							.controlSize(.small)
					}
				}
				.frame(minHeight: 28)
			}
			.buttonStyle(.borderedProminent)
			.tint(bp.crease)
			.disabled(disabled || busy)
			if let result {
				Text(result)
					.font(Typography.text(13))
					.foregroundStyle(isError ? bp.crane : bp.ink60)
					.fixedSize(horizontal: false, vertical: true)
			}
		}
		.frame(maxWidth: .infinity, alignment: .leading)
	}
}

// MARK: - Nav row

/// A chevron row used as a `NavigationLink` label for manager screens.
public struct BlueprintNavRow: View {
	@Environment(\.blueprint) private var bp
	private let title: String
	private let subtitle: String?
	private let systemImage: String?

	public init(_ title: String, subtitle: String? = nil, systemImage: String? = nil) {
		self.title = title
		self.subtitle = subtitle
		self.systemImage = systemImage
	}

	public var body: some View {
		HStack(spacing: 12) {
			if let systemImage {
				Image(systemName: systemImage)
					.font(.system(size: 16, weight: .semibold))
					.foregroundStyle(bp.crease)
					.frame(width: 24)
			}
			VStack(alignment: .leading, spacing: 2) {
				Text(title)
					.font(Typography.text(15, weight: .semibold))
					.foregroundStyle(bp.ink)
				if let subtitle {
					Text(subtitle)
						.font(Typography.text(12))
						.foregroundStyle(bp.ink60)
						.fixedSize(horizontal: false, vertical: true)
				}
			}
			Spacer(minLength: 0)
			Image(systemName: "chevron.right")
				.font(.system(size: 12, weight: .semibold))
				.foregroundStyle(bp.ink60)
		}
		.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
		.contentShape(Rectangle())
	}
}

import Foundation

/// Central definition of the app's custom URL scheme so the widget (which *builds*
/// deep links) and the app (which *parses* them in `onOpenURL`) never drift apart.
///
/// Shapes:
///   `homelabglance://logs/<container>`  — open the app straight to a service's logs
///   `homelabglance://containers`        — open the app to the container list
public enum DeepLink: Equatable, Sendable {
	case logs(container: String)
	case containers

	public static let scheme = "homelabglance"

	/// Build a URL for a widget `Link`/`.widgetURL`.
	public var url: URL? {
		switch self {
		case .logs(let container):
			// Percent-encode the container name so unusual names still round-trip.
			let name = container.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? container
			return URL(string: "\(Self.scheme)://logs/\(name)")
		case .containers:
			return URL(string: "\(Self.scheme)://containers")
		}
	}

	/// Parse an incoming URL from `onOpenURL`. Returns nil for foreign/unknown URLs.
	public init?(url: URL) {
		guard url.scheme == Self.scheme else { return nil }
		// Host carries the action; for logs the container is the first path segment.
		switch url.host {
		case "logs":
			let segment = url.pathComponents.first { $0 != "/" }
			guard let container = segment?.removingPercentEncoding, !container.isEmpty else { return nil }
			self = .logs(container: container)
		case "containers":
			self = .containers
		default:
			return nil
		}
	}
}

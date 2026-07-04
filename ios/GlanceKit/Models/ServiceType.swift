import Foundation

/// Known self-hosted services the aggregator has rich pollers for. Detection
/// maps a raw container (image, then name) to a type; when the dashboard also
/// carries a matching rich `Card` the app renders it, otherwise the container
/// falls back to the generic card.
public enum ServiceType: String, CaseIterable, Sendable {
	case jellyfin
	case sonarr
	case radarr
	case prowlarr
	case qbittorrent
	case pihole
	case beszel

	/// The rich `Card.id` the aggregator's poller emits for this type.
	public var cardID: String { rawValue }

	/// Lowercased substrings that identify this service in an image ref or
	/// container name (e.g. `lscr.io/linuxserver/sonarr:latest`, `pihole/pihole`).
	private var markers: [String] {
		switch self {
		case .pihole: return ["pihole", "pi-hole"]
		default: return [rawValue]
		}
	}

	/// Detect a known service from a container's image ref and name — image
	/// first (the strong signal), then the container name.
	public static func detect(image: String?, name: String) -> ServiceType? {
		let haystacks = [image?.lowercased(), name.lowercased()].compactMap(\.self)
		for haystack in haystacks {
			for type in ServiceType.allCases where type.markers.contains(where: haystack.contains) {
				return type
			}
		}
		return nil
	}
}

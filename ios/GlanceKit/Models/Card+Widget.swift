import Foundation

public extension Card {
	/// A short metric for compact widget chips (e.g. "↓4.2", "Q2", "14%"), or nil.
	var widgetMetric: String? {
		let d = data ?? CardData()
		switch id {
		case "jellyfin": return d.streams.map { "\($0)▶" }
		case "qbittorrent": return d.dlMibps.map { "↓\(Format.num($0))" }
		case "sonarr", "radarr", "prowlarr": return d.queue.map { "Q\($0)" }
		case "pihole": return d.blockedPct.map { Format.num($0, unit: "%", decimals: 0) }
		default: return nil
		}
	}
}

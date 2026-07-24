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

	/// One glanceable metric line for the quiet (healthy) card treatment — the
	/// single thing worth reading when a service is fine. Fuller than `widgetMetric`
	/// but still one line; nil falls back to the CPU line.
	var condensedMetric: String? {
		let d = data ?? CardData()
		switch id {
		case "jellyfin":
			guard let s = d.streams else { return nil }
			return s == 0 ? "Idle" : "\(s) streaming"
		case "qbittorrent": return "↓\(Format.num(d.dlMibps)) ↑\(Format.num(d.ulMibps)) MiB/s"
		case "sonarr", "radarr": return d.queue.map { "Queue \($0)" }
		case "prowlarr": return d.grabs.map { "\($0) grabs" }
		case "pihole": return d.blockedPct.map { "\(Format.num($0, unit: "%", decimals: 0)) blocked" }
		default: return nil
		}
	}

	/// Spoken twin of `widgetMetric` — "queue 4" not "Q4"; nil when there's no metric.
	var spokenWidgetMetric: String? {
		let d = data ?? CardData()
		switch id {
		case "jellyfin": return d.streams.map { "\($0) streams" }
		case "qbittorrent": return d.dlMibps.map { "downloading \(Format.num($0)) megabytes per second" }
		case "sonarr", "radarr", "prowlarr": return d.queue.map { "queue \($0)" }
		case "pihole": return d.blockedPct.map { "blocked \(Format.spokenPercent($0, decimals: 0))" }
		default: return nil
		}
	}

	/// One-line VoiceOver summary shared by the app card and the widget mini-card:
	/// "Jellyfin, up. CPU 0 percent, memory 0.58 gigabytes. Streams, none playing."
	var spokenSummary: String {
		var parts: [String] = [title, Format.spokenStatus(status, stale: stale)]
		var stats: [String] = []
		if let cpu = cpuPct { stats.append("CPU \(Format.spokenPercent(cpu, decimals: 1))") }
		if let mem = memMb { stats.append("memory \(Format.spokenMemGB(mem))") }
		if !stats.isEmpty { parts.append(stats.joined(separator: ", ")) }
		let body = spokenBody
		if !body.isEmpty { parts.append(body) }
		return parts.joined(separator: ". ")
	}

	/// Spoken twin of the per-service card body, expanded into prose.
	private var spokenBody: String {
		let d = data ?? CardData()
		switch id {
		case "jellyfin":
			var s = (d.streams ?? 0) == 0 ? "no streams playing" : "streams \(Format.spokenInt(d.streams))"
			if let np = d.nowPlaying?.first { s += ", playing \(np.title)" }
			return s
		case "qbittorrent":
			return "\(Format.spokenRates(down: d.dlMibps, up: d.ulMibps)). "
				+ "active \(Format.spokenInt(d.active)), seeding \(Format.spokenInt(d.seeding))"
		case "sonarr":
			return "queue \(Format.spokenInt(d.queue)), wanted \(Format.spokenInt(d.wanted))"
		case "radarr":
			return "queue \(Format.spokenInt(d.queue)), missing \(Format.spokenInt(d.missing))"
		case "prowlarr":
			return "queue \(Format.spokenInt(d.queue)), grabs \(Format.spokenInt(d.grabs))"
		case "pihole":
			var s: [String] = []
			if let b = d.blockedPct { s.append("blocked \(Format.spokenPercent(b, decimals: 1))") }
			s.append("queries \(Format.spokenCompact(d.queries))")
			if let g = d.gravity { s.append("gravity \(Format.spokenCompact(Int(g)))") }
			return s.joined(separator: ", ")
		default:
			return ""
		}
	}
}

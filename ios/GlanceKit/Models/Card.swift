import Foundation

/// A single service card. Common fields are top-level; service-specific metrics
/// live in `data`. `id` selects which fields of `CardData` are meaningful and
/// which card view renders it (jellyfin, qbittorrent, sonarr, radarr, prowlarr,
/// pihole, or a plain "home" container card).
public struct Card: Codable, Sendable, Equatable, Identifiable {
	public var id: String
	public var title: String
	public var group: String?
	public var status: ServiceStatus?
	public var stale: Bool?
	public var cpuPct: Double?
	public var memMb: Double?
	public var containerRunning: Bool?
	public var data: CardData?

	public init(
		id: String, title: String, group: String? = nil,
		status: ServiceStatus? = nil, stale: Bool? = nil,
		cpuPct: Double? = nil, memMb: Double? = nil,
		containerRunning: Bool? = nil, data: CardData? = nil
	) {
		self.id = id
		self.title = title
		self.group = group
		self.status = status
		self.stale = stale
		self.cpuPct = cpuPct
		self.memMb = memMb
		self.containerRunning = containerRunning
		self.data = data
	}
}

/// Service-specific metrics. The aggregator returns a heterogeneous `data`
/// object per card type; this flat struct of optionals mirrors how glance.jsx
/// reads it (each renderer only touches the keys relevant to its `id`).
public struct CardData: Codable, Sendable, Equatable {
	// Jellyfin
	public var streams: Int?
	public var nowPlaying: [NowPlaying]?
	// qBittorrent
	public var dlMibps: Double?
	public var ulMibps: Double?
	public var active: Int?
	public var seeding: Int?
	// Sonarr / Radarr / Prowlarr
	public var queue: Int?
	public var wanted: Int?
	public var missing: Int?
	public var grabs: Int?
	// Pi-hole
	public var blockedPct: Double?
	public var queries: Int?
	public var gravity: Double?

	public init(
		streams: Int? = nil, nowPlaying: [NowPlaying]? = nil,
		dlMibps: Double? = nil, ulMibps: Double? = nil, active: Int? = nil, seeding: Int? = nil,
		queue: Int? = nil, wanted: Int? = nil, missing: Int? = nil, grabs: Int? = nil,
		blockedPct: Double? = nil, queries: Int? = nil, gravity: Double? = nil
	) {
		self.streams = streams
		self.nowPlaying = nowPlaying
		self.dlMibps = dlMibps
		self.ulMibps = ulMibps
		self.active = active
		self.seeding = seeding
		self.queue = queue
		self.wanted = wanted
		self.missing = missing
		self.grabs = grabs
		self.blockedPct = blockedPct
		self.queries = queries
		self.gravity = gravity
	}
}

/// A now-playing entry in a Jellyfin card.
public struct NowPlaying: Codable, Sendable, Equatable {
	public var title: String

	public init(title: String) { self.title = title }
}

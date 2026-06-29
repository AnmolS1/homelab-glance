import Foundation

/// The homelab host summary shown in the dashboard header.
/// All fields optional to tolerate the aggregator's empty grace envelope.
/// Named `HostSummary` (not `Host`) to avoid colliding with `Foundation.Host`.
public struct HostSummary: Codable, Sendable, Equatable {
	public var name: String?
	public var status: ServiceStatus?
	public var stale: Bool?
	public var cpuPct: Double?
	public var ramUsedGb: Double?
	public var ramTotalGb: Double?
	public var diskUsedTb: Double?
	public var diskTotalTb: Double?
	/// Uptime in seconds.
	public var uptime: Double?
	public var sensors: Sensors?

	public init(
		name: String? = nil, status: ServiceStatus? = nil, stale: Bool? = nil,
		cpuPct: Double? = nil, ramUsedGb: Double? = nil, ramTotalGb: Double? = nil,
		diskUsedTb: Double? = nil, diskTotalTb: Double? = nil, uptime: Double? = nil,
		sensors: Sensors? = nil
	) {
		self.name = name
		self.status = status
		self.stale = stale
		self.cpuPct = cpuPct
		self.ramUsedGb = ramUsedGb
		self.ramTotalGb = ramTotalGb
		self.diskUsedTb = diskUsedTb
		self.diskTotalTb = diskTotalTb
		self.uptime = uptime
		self.sensors = sensors
	}
}

/// Hardware sensor readings + short temperature histories for sparklines.
public struct Sensors: Codable, Sendable, Equatable {
	public var nvmeTemp: Double?
	public var gpuTemp: Double?
	public var nvmeTempHistory: [Double]?
	public var gpuTempHistory: [Double]?
	public var gpuLoadPct: Double?
	public var gpuPowerW: Double?
	public var gpuVramUsedMb: Double?
	public var gpuVramTotalMb: Double?

	public init(
		nvmeTemp: Double? = nil, gpuTemp: Double? = nil,
		nvmeTempHistory: [Double]? = nil, gpuTempHistory: [Double]? = nil,
		gpuLoadPct: Double? = nil, gpuPowerW: Double? = nil,
		gpuVramUsedMb: Double? = nil, gpuVramTotalMb: Double? = nil
	) {
		self.nvmeTemp = nvmeTemp
		self.gpuTemp = gpuTemp
		self.nvmeTempHistory = nvmeTempHistory
		self.gpuTempHistory = gpuTempHistory
		self.gpuLoadPct = gpuLoadPct
		self.gpuPowerW = gpuPowerW
		self.gpuVramUsedMb = gpuVramUsedMb
		self.gpuVramTotalMb = gpuVramTotalMb
	}

	/// True when at least one temperature reading is present (mirrors glance.jsx).
	public var hasReadings: Bool { nvmeTemp != nil || gpuTemp != nil }
}

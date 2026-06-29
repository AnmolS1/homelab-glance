#if os(iOS)
import ActivityKit
import Foundation

/// Live Activity for qBittorrent download progress (Lock Screen / Dynamic Island).
/// Shared so the app starts/updates it and the widget extension renders it.
public struct DownloadActivityAttributes: ActivityAttributes {
	public struct ContentState: Codable, Hashable, Sendable {
		public var downloadMibps: Double
		public var uploadMibps: Double
		public var activeCount: Int
		public var seedingCount: Int

		public init(downloadMibps: Double, uploadMibps: Double, activeCount: Int, seedingCount: Int) {
			self.downloadMibps = downloadMibps
			self.uploadMibps = uploadMibps
			self.activeCount = activeCount
			self.seedingCount = seedingCount
		}
	}

	public var host: String

	public init(host: String) { self.host = host }
}
#endif

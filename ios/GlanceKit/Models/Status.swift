import Foundation

/// Service / host health, as reported by the aggregator's `status` field.
/// Decodes leniently: any unrecognized string becomes `.unknown`.
public enum ServiceStatus: String, Codable, Sendable, Equatable {
	case up
	case down
	case unknown

	public init(from decoder: Decoder) throws {
		let raw = try decoder.singleValueContainer().decode(String.self)
		self = ServiceStatus(rawValue: raw) ?? .unknown
	}
}

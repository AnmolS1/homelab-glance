import Foundation

/// Top-level envelope returned by `GET {BASE}/api/dashboard`.
///
/// During the aggregator's first poll cycle it returns a grace envelope with
/// `generated_at: null`, `host: {}` and `cards: []` — every field here is
/// therefore optional or defaulted so the same type decodes both states.
public struct Dashboard: Codable, Sendable, Equatable {
	/// Unix epoch seconds the snapshot was generated (nil during grace cycle).
	public var generatedAt: Double?
	public var pollSeconds: Int?
	public var host: HostSummary
	public var cards: [Card]

	public init(generatedAt: Double? = nil, pollSeconds: Int? = nil, host: HostSummary = HostSummary(), cards: [Card] = []) {
		self.generatedAt = generatedAt
		self.pollSeconds = pollSeconds
		self.host = host
		self.cards = cards
	}

	enum CodingKeys: String, CodingKey {
		case generatedAt, pollSeconds, host, cards
	}

	public init(from decoder: Decoder) throws {
		let c = try decoder.container(keyedBy: CodingKeys.self)
		generatedAt = try c.decodeIfPresent(Double.self, forKey: .generatedAt)
		pollSeconds = try c.decodeIfPresent(Int.self, forKey: .pollSeconds)
		host = try c.decodeIfPresent(HostSummary.self, forKey: .host) ?? HostSummary()
		cards = try c.decodeIfPresent([Card].self, forKey: .cards) ?? []
	}

	/// Date form of `generatedAt`, if present.
	public var generatedAtDate: Date? {
		generatedAt.map { Date(timeIntervalSince1970: $0) }
	}
}

public extension JSONDecoder {
	/// Decoder configured for the aggregator's snake_case payloads.
	static var glance: JSONDecoder {
		let d = JSONDecoder()
		d.keyDecodingStrategy = .convertFromSnakeCase
		return d
	}
}

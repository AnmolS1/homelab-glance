import Foundation

public extension Dashboard {
	/// Canonical group display order.
	static let groupOrder = ["Media", "Acquisition", "Infrastructure", "Home"]

	var downServices: [Card] { cards.filter { $0.status == .down } }
	var downCount: Int { downServices.count }
	var upCount: Int { cards.filter { $0.status == .up }.count }

	/// Disk usage percent (0…100), if both used/total are known.
	var diskPercent: Double? {
		guard let used = host.diskUsedTb, let total = host.diskTotalTb, total > 0 else { return nil }
		return used / total * 100
	}

	/// Cards grouped and ordered by `groupOrder` (groups with no cards omitted).
	var groupedCards: [(group: String, cards: [Card])] {
		let grouped = Dictionary(grouping: cards, by: { $0.group ?? "Other" })
		return Dashboard.groupOrder.compactMap { g in
			guard let cs = grouped[g] else { return nil }
			return (group: g, cards: cs)
		}
	}

	/// One-line health summary, e.g. "All up · disk 26%" or "2 down · disk 78%".
	var healthLine: String {
		let head = downCount == 0 ? "All up" : "\(downCount) down"
		if let disk = diskPercent {
			return head + " · disk " + Format.num(disk, unit: "%", decimals: 0)
		}
		return head
	}
}

import Foundation
import Security

/// Minimal generic-password Keychain wrapper. When a shared `accessGroup` is
/// supplied it is used first; if the running build lacks the entitlement
/// (e.g. an unsigned simulator build) the query is retried without the group so
/// development never breaks. Properly signed builds share items with the widget.
public struct KeychainStore: Sendable {
	public let service: String
	public let accessGroup: String?

	public init(service: String = "dev.ponderance.homelabglance", accessGroup: String? = nil) {
		self.service = service
		self.accessGroup = accessGroup
	}

	private func baseQuery(_ key: String, includeGroup: Bool) -> [String: Any] {
		var q: [String: Any] = [
			kSecClass as String: kSecClassGenericPassword,
			kSecAttrService as String: service,
			kSecAttrAccount as String: key,
		]
		if includeGroup, let accessGroup { q[kSecAttrAccessGroup as String] = accessGroup }
		return q
	}

	/// Variants to try: with the access group first (if any), then without.
	private var groupVariants: [Bool] { accessGroup == nil ? [false] : [true, false] }

	public func string(for key: String) -> String? {
		for includeGroup in groupVariants {
			var q = baseQuery(key, includeGroup: includeGroup)
			q[kSecReturnData as String] = true
			q[kSecMatchLimit as String] = kSecMatchLimitOne
			var item: CFTypeRef?
			let status = SecItemCopyMatching(q as CFDictionary, &item)
			if status == errSecSuccess, let data = item as? Data {
				return String(data: data, encoding: .utf8)
			}
			if status == errSecItemNotFound { return nil }
			// other errors (e.g. missing entitlement): fall through to next variant
		}
		return nil
	}

	@discardableResult
	public func set(_ value: String, for key: String) -> Bool {
		let data = Data(value.utf8)
		for includeGroup in groupVariants {
			let q = baseQuery(key, includeGroup: includeGroup)
			SecItemDelete(q as CFDictionary)
			var add = q
			add[kSecValueData as String] = data
			add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
			let status = SecItemAdd(add as CFDictionary, nil)
			if status == errSecSuccess { return true }
		}
		return false
	}

	@discardableResult
	public func remove(for key: String) -> Bool {
		var ok = false
		for includeGroup in groupVariants {
			let status = SecItemDelete(baseQuery(key, includeGroup: includeGroup) as CFDictionary)
			if status == errSecSuccess { ok = true }
		}
		return ok
	}
}

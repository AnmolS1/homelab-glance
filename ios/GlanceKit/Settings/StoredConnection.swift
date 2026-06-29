import Foundation

/// Persisted settings keys, shared by `AppSettings` (read/write, main actor) and
/// `StoredConnection` (read-only, any actor — used by widgets/extensions).
public enum SettingsKeys {
	public static let baseURL = "baseURLString"
	public static let useMock = "useMockData"
	public static let token = "widgetToken"
	public static let controlToken = "controlToken"
}

/// A nonisolated snapshot of the connection settings, readable from a widget's
/// background timeline context (where the `@MainActor` `AppSettings` can't be used).
public struct StoredConnection: Sendable {
	public let baseURLString: String
	public let token: String
	public let controlToken: String
	public let useMock: Bool

	public static func load() -> StoredConnection {
		let store = AppSettings.defaultStore()
		let keychain = KeychainStore(accessGroup: AppSettings.keychainGroup)
		let useMock = (store.object(forKey: SettingsKeys.useMock) as? Bool) ?? true
		let base = store.string(forKey: SettingsKeys.baseURL) ?? ""
		let token = keychain.string(for: SettingsKeys.token) ?? ""
		let controlToken = keychain.string(for: SettingsKeys.controlToken) ?? ""
		return StoredConnection(baseURLString: base, token: token, controlToken: controlToken, useMock: useMock)
	}

	public func makeProvider() -> any DashboardProviding {
		if useMock { return MockDashboardClient() }
		return LiveDashboardClient(baseURLString: baseURLString, token: token) ?? MockDashboardClient()
	}

	public func makeControlProvider() -> any DockerControlProviding {
		if useMock { return MockDockerControlClient() }
		return LiveDockerControlClient(baseURLString: baseURLString, token: token, controlToken: controlToken)
			?? MockDockerControlClient()
	}
}
